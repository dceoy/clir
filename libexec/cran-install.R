#!/usr/bin/env Rscript
#
# Usage:  cran-install <package...>
#         cran-install --quiet <package...>
#
# Options:
#   --quiet           Suppress output messages

cran_install <- function(pkgs = NULL, repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
  if(require('devtools')) {
    withr::with_libpaths(r_lib,
                         devtools::update_packages(pkgs = pkgs, repos = repos, dependencies = TRUE))
  } else {
    if(pkgs == NULL) {
      update.packages(repos = repos, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
    } else {
      if(length(pkgs_old <- intersect(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
        update.packages(instPkgs = pkgs_old, repos = repos, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
      }
      if(length(pkgs_new <- setdiff(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
        install.packages(pkgs = pkgs_new, repos = repos, lib = r_lib, dependencies = TRUE)
      }
    }
  }
}

load_repos <- function(cran_file = '../cran_url', drat_file = '../drat_account', quiet = FALSE) {
  suppressMessages(sapply(c('drat', 'devtools'), require, character.only = TRUE))
  if(file.exists(cran_file)) {
    urls <- scan(cran_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    options(repos = c(CRAN = urls[1]))
  }
  if(require('drat') && file.exists(drat_file)) {
    accounts <- scan(drat_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    drat:::addRepo(account = accounts)
  }
  repos <- getOption('repos')
  if(! quiet) {
    message('Repository ---------------------------------------------------------------------')
    lapply(names(repos),
           function(n) message(paste0('  ', n, ':\n    - ', repos[n])))
    message()
  }
  return(invisible(repos))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--quiet') {
    stop('missing arguments')
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    cran_install(argv, repos = load_repos(quiet = TRUE))
  }
} else {
  pkgv <- setdiff(argv, '--quiet')
  if(sum(grepl('^-', pkgv)) > 0) {
    stop('unrecognized options')
  } else if('--quiet' %in% argv) {
    suppressMessages(cran_install(pkgv, repos = load_repos(quiet = TRUE)))
  } else {
    cran_install(pkgv, repos = load_repos(quiet = TRUE))
  }
}
