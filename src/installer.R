#!/usr/bin/env Rscript

update_cran_pkgs <- function(config_yml, r_lib = .libPaths(), quiet = FALSE) {
  update.packages(repos = load_repos(config_yml = config_yml, quiet = quiet),
                  checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib,
                  quiet = quiet)
}

load_repos <- function(config_yml, quiet = FALSE,
                       default_cran = 'https://cran.rstudio.com/') {
  if (file.exists(config_yml)) {
    cf <- yaml::read_yaml(config_yml)
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
    new_repos <- c(CLAN = cran, repos[names(repos) != 'CRAN'])
  } else {
    repos <- getOption('repos')
    new_repos <- c(CLAN = default_cran, repos[names(repos) != 'CRAN'])
  }
  return(new_repos)
}

install_pkgs <- function(pkgs, config_yml, from, r_lib = .libPaths(),
                         upgrade = TRUE, depend = TRUE, quiet = FALSE) {
  repos <- load_repos(config_yml = config_yml, quiet = quiet)
  installed_pkgs <- installed.packages(lib.loc = r_lib)[, 1]
  old_pkgs <- intersect(pkgs, installed_pkgs)
  new_pkgs <- setdiff(pkgs, installed_pkgs)
  if (upgrade || (length(new_pkgs) > 0)) {
    if (from == 'cran') {
      if (require('devtools', quietly = TRUE)) {
        if (upgrade) {
          withr::with_libpaths(r_lib,
                               devtools::install_cran(pkgs, repos = repos,
                                                      dependencies = depend,
                                                      quiet = quiet))
        } else if (length(old_pkgs) > 0) {
          withr::with_libpaths(r_lib,
                               devtools::install_cran(old_pkgs, repos = repos,
                                                      dependencies = depend,
                                                      quiet = quiet))
        }
      } else {
        if (upgrade && (length(old_pkgs) > 0)) {
          update.packages(instPkgs = old_pkgs, repos = repos, checkBuilt = TRUE,
                          ask = FALSE, lib.loc = r_lib, quiet = quiet)
        }
        if (length(new_pkgs) > 0) {
          install.packages(pkgs = new_pkgs, repos = repos, lib = r_lib,
                           dependencies = depend, quiet = quiet)
        }
      }
    } else if (from == 'github') {
      if (upgrade) {
        withr::with_libpaths(r_lib,
                             devtools::install_github(pkgs,
                                                      dependencies = depend,
                                                      quiet = quiet))
      } else if (length(old_pkgs) > 0) {
        withr::with_libpaths(r_lib,
                             devtools::install_github(old_pkgs,
                                                      dependencies = depend,
                                                      quiet = quiet))
      }
    } else if (from == 'bitbucket') {
      if (upgrade) {
        withr::with_libpaths(r_lib,
                             devtools::install_bitbucket(pkgs,
                                                         dependencies = depend,
                                                         quiet = quiet))
      } else if (length(old_pkgs) > 0) {
        withr::with_libpaths(r_lib,
                             devtools::install_bitbucket(old_pkgs,
                                                         dependencies = depend,
                                                         quiet = quiet))
      }
    } else if (from == 'bioconductor') {
      if (upgrade) {
        withr::with_libpaths(r_lib,
                             devtools::install_bioc(pkgs, dependencies = depend,
                                                    quiet = quiet))
      } else if (length(old_pkgs) > 0) {
        withr::with_libpaths(r_lib,
                             devtools::install_bioc(old_pkgs,
                                                    dependencies = depend,
                                                    quiet = quiet))
      }
    } else {
      stop('Invalid installation type')
    }
  }
}

uninstall_pkgs <- function(pkgs, r_lib = .libPaths(), quiet = FALSE) {
  if (require('devtools', quietly = TRUE)) {
    withr::with_libpaths(r_lib, devtools::uninstall(pkg = pkgs, quiet = quiet))
  } else {
    remove.packages(pkgs = pkgs, lib = r_lib)
  }
}
