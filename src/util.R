#!/usr/bin/env Rscript

initilize_config <- function(clir_yml) {
  r_dir <- stringr::str_c(dirname(clir_yml), '/')
  if (! dir.exists(r_dir)) {
    dir.create(r_dir, showWarnings = FALSE)
  }
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

print_config <- function(clir_yml, r_lib = .libPaths(), initialize = FALSE) {
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

install_pkgs <- function(pkgs, repos, devt, r_lib = .libPaths(),
                         upgrade = TRUE, depend = TRUE, quiet = FALSE) {
  installed_pkgs <- installed.packages(lib.loc = r_lib)[, 1]
  ps <- list(all = pkgs,
             old = intersect(pkgs, installed_pkgs),
             new = setdiff(pkgs, installed_pkgs))
  if (upgrade || (length(ps$new) > 0)) {
    if (is.null(devt)) {
      if (upgrade && (length(ps$old) > 0)) {
        update.packages(instPkgs = ps$old, repos = repos, checkBuilt = TRUE,
                        ask = FALSE, lib.loc = r_lib, quiet = quiet)
      }
      if (length(ps$new) > 0) {
        install.packages(pkgs = ps$new, repos = repos, lib = r_lib,
                         dependencies = depend, quiet = quiet)
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
    cat('\nLoading test ', stringr::str_c(rep('-', 67), collapse = ''), '\n')
    if (length(result$succeeded) > 0) {
      cat(' Succeeded:\n  ',
          stringr::str_c(result$succeeded, collapse = '\n   '), '\n')
    }
    if (length(result$failed) > 0) {
      cat(' Failed:\n  ',
          stringr::str_c(result$failed, collapse = '\n   '), '\n')
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
  if (require('devtools', quietly = TRUE)) {
    devtools::session_info(pkgs = pkgs, include_base = TRUE)
  } else {
    stop('This command requires devtools.')
  }
}
