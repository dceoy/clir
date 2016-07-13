#!/usr/bin/env Rscript

cran_install <- function(pkgs, repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
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

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  sapply(c('drat', 'devtools'), require, character.only = TRUE)
  if(file.exists(cran_txt <- '../r/cran_mirror')) {
    mirror <- scan(cran_txt, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    options(repos = c(CRAN = mirror))
  }
  if(require('drat') && file.exists(drat_txt <- '../r/drat_accounts')) {
    accounts <- scan(drat_txt, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    drat:::addRepo(account = accounts)
  }
  repos <- getOption('repos')
  message('\nRepository ---------------------------------------------------------------------')
  lapply(names(repos),
         function(n) {
           message(paste0('  ', n, ':'))
           message(paste0('    - ', repos[n]))
         })
  message('--------------------------------------------------------------------------------\n')
  cran_install(argv)
}
