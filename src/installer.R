#!/usr/bin/env Rscript

update_cran_pkgs <- function(clir_yml, r_lib = .libPaths(), quiet = FALSE) {
  update.packages(repos = load_repos(clir_yml = clir_yml, quiet = quiet),
                  checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib,
                  quiet = quiet)
}

load_repos <- function(clir_yml, quiet = FALSE) {
  cf <- yaml::read_yaml(clir_yml)
  if (require('drat', quietly = TRUE) && ('drat_repos' %in% names(cf))) {
    drat:::addRepo(account = cf$drat_repos)
  }
  repos <- getOption('repos')
  if ('cran_urls' %in% names(cf)) {
    cran <- cf$cran_urls[1]
  } else if (repos['CRAN'] != '@CRAN@') {
    cran <- default_cran
  } else {
    cran <- repos['CRAN']
  }
  return(c(CLAN = cran, repos[names(repos) != 'CRAN']))
}

install_pkgs <- function(pkgs, clir_yml, devt, r_lib = .libPaths(),
                         upgrade = TRUE, depend = TRUE, quiet = FALSE) {
  repos <- load_repos(clir_yml = clir_yml, quiet = quiet)
  installed_pkgs <- installed.packages(lib.loc = r_lib)[, 1]
  old_pkgs <- intersect(pkgs, installed_pkgs)
  new_pkgs <- setdiff(pkgs, installed_pkgs)
  if (upgrade || (length(new_pkgs) > 0)) {
    if (is.null(devt)) {
      if (upgrade && (length(old_pkgs) > 0)) {
        update.packages(instPkgs = old_pkgs, repos = repos, checkBuilt = TRUE,
                        ask = FALSE, lib.loc = r_lib, quiet = quiet)
      }
      if (length(new_pkgs) > 0) {
        install.packages(pkgs = new_pkgs, repos = repos, lib = r_lib,
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
          targets <- pkgs
        } else {
          targets <- new_pkgs
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
