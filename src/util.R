#!/usr/bin/env Rscript

make_clir_dirs <- function(clir_root_dir, exist_ok = TRUE) {
  sapply(file.path(clir_root_dir, c('r', 'r/library')),
         dir.create, showWarnings = (! exist_ok))
}

initilize_config <- function(clir_yml) {
  yaml::write_yaml(list(cran_urls = c('https://cran.rstudio.com/'),
                        drat_repos = c('eddelbuettel')),
                   file = clir_yml)
  message(stringr::str_c('Initialized: ', clir_yml))
}

load_repos <- function(clir_yml, quiet = FALSE) {
  if (! file.exists(clir_yml)) {
    initilize_config(clir_yml = clir_yml)
  }
  cf <- yaml::read_yaml(clir_yml)
  if (require('drat', quietly = TRUE) && ('drat_repos' %in% names(cf))) {
    drat:::addRepo(account = cf$drat_repos)
  }
  repos <- getOption('repos')
  if ('cran_urls' %in% names(cf)) {
    cran <- cf$cran_urls[1]
  } else {
    cran <- repos['CRAN']
  }
  return(c(CLAN = cran, repos[names(repos) != 'CRAN']))
}

print_config <- function(clir_yml, r_lib = .libPaths()[1],
                         initialize = FALSE) {
  if (initialize) {
    initilize_config(clir_yml = clir_yml)
  }
  print(list(clir = yaml::read_yaml(clir_yml), libpath = r_lib, r = version))
}

add_config <- function(new, key, clir_yml) {
  cf <- yaml::read_yaml(clir_yml)
  cf[[key]] <- c(new, setdiff(cf[[key]], new))
  yaml::write_yaml(cf, file = clir_yml)
  message(stringr::str_c('Overwrited: ', clir_yml))
}

print_cran_mirrors <- function(https = TRUE) {
  d <- data.frame(getCRANmirrors())
  if (https) {
    print(subset(d, grepl('^https://', d$URL))[, c('Name', 'URL')])
  } else {
    print(d[, c('Name', 'URL')])
  }
}

update_pkgs <- function(repos, bioc = FALSE, r_lib = .libPaths()[1],
                        quiet = FALSE) {
  if (bioc) {
    source(stringr::str_c(getOption('BioC_mirror'), '/biocLite.R')) # nolint
    biocLite(pkgs = installed.packages(lib.loc = r_lib)[, 1],   # nolint
             lib.loc = r_lib, lib = r_lib, ask = FALSE)
  } else {
    update.packages(lib.loc = r_lib, repos = repos, checkbuilt = TRUE,
                    ask = FALSE, quiet = quiet)
  }
}

install_pkgs <- function(pkgs, repos, devt, bioc = FALSE,
                         r_lib = .libPaths()[1], upgrade = TRUE, depend = TRUE,
                         quiet = FALSE) {
  installed_pkgs <- installed.packages(lib.loc = r_lib)[, 1]
  ps <- list(all = pkgs,
             old = intersect(pkgs, installed_pkgs),
             new = setdiff(pkgs, installed_pkgs))
  if (upgrade || (length(ps$new) > 0)) {
    if (is.null(devt)) {
      if (bioc) {
        source(stringr::str_c(getOption('BioC_mirror'), '/biocLite.R')) # nolint
        biocLite(pkgs = ps$all, lib.loc = r_lib, lib = r_lib,   # nolint
                 repos = repos, ask = FALSE)
      } else {
        if (upgrade && (length(ps$old) > 0)) {
          update.packages(instPkgs = ps$old, repos = repos, checkBuilt = TRUE,
                          ask = FALSE, lib.loc = r_lib, quiet = quiet)
        }
        if (length(ps$new) > 0) {
          install.packages(pkgs = ps$new, repos = repos, lib = r_lib,
                           dependencies = depend, quiet = quiet)
        }
      }
    } else if (devt %in% c('cran', 'github', 'bitbucket', 'bioc')) {
      if (! require('devtools', quietly = TRUE)) {
        install.packages(pkgs = 'devtools', repos = repos, lib = r_lib,
                         dependencies = TRUE, quiet = quiet)
      }
      if (! require('devtools', quietly = TRUE)) {
        stop('Loading of devtools failed.')
      } else {
        if (upgrade) {
          targets <- ps$all
        } else {
          targets <- ps$new
        }
        f <- switch(devt,
                    'cran' = devtools::install_cran,
                    'github' = devtools::install_github,
                    'bitbucket' = devtools::install_bitbucket,
                    'bioc' = devtools::install_bioc)
        withr::with_libpaths(r_lib,
                             f(targets, dependencies = depend, quiet = quiet))
      }
    } else {
      stop('Invalid installation type.')
    }
  } else {
    message('The packages already installed.')
  }
}

validate_loading <- function(pkgs, quiet = FALSE) {
  v <- sapply(as.vector(pkgs), require, character.only = TRUE)
  result <- list(succeeded = names(v)[v], failed = names(v)[! v])
  if (! quiet) {
    if (require('devtools', quietly = TRUE)) {
      print(devtools::session_info(pkgs = pkgs, include_base = TRUE))
    }
    cat('\nLoading test ', stringr::str_c(rep('-', 67), collapse = ''), '\n',
        sep = '')
    if (length(result$succeeded) > 0) {
      cat(' Succeeded:\n  - ',
          stringr::str_c(result$succeeded, collapse = '\n  - '), '\n',
          sep = '')
    }
    if (length(result$failed) > 0) {
      cat(' Failed:\n  - ',
          stringr::str_c(result$failed, collapse = '\n  - '), '\n',
          sep = '')
    }
    cat('\n')
    if (length(result$failed) == 0) {
      message('Loading succeeded.')
    }
  }
  if (length(result$failed) > 0) {
    stop('Loading failed.')
  }
}

print_sessions <- function(pkgs) {
  if (! require('devtools', quietly = TRUE)) {
    stop('This command requires devtools.')
  } else if (length(pkgs) > 0) {
    devtools::session_info(pkgs = pkgs, include_base = TRUE)
  } else {
    devtools::session_info(include_base = TRUE)
  }
}
