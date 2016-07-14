#!/usr/bin/env Rscript

cran_install <- function(pkgs = NULL, repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
  if(require('devtools')) {
    withr::with_libpaths(r_lib,
                         devtools::update_packages(pkgs = pkgs, repos = repos, dependencies = TRUE))
  } else {
    if(length(pp <- intersect(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
      update.packages(instPkgs = pp, repos = repos, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
    }
    if(length(pd <- setdiff(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
      install.packages(pkgs = pd, repos = repos, lib = r_lib, dependencies = TRUE)
    }
  }
}

set_repos <- function(cran_txt_file = '../r/cran_mirror', drat_txt_file = '../r/drat_accounts') {
  suppressMessages(sapply(c('drat', 'devtools'), require, character.only = TRUE))
  if(file.exists(cran_txt_file)) {
    mirror <- scan(cran_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    options(repos = c(CRAN = mirror))
  }
  if(require('drat') && file.exists(drat_txt_file)) {
    accounts <- scan(drat_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    drat:::addRepo(account = accounts)
  }
  repos <- getOption('repos')
  message('Repository ---------------------------------------------------------------------')
  lapply(names(repos),
         function(n) message(paste0('  ', n, ':\n    - ', repos[n])))
  message()
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  suppressMessages(set_repos())
  cran_install(argv, repos = getOption('repos'))
}
