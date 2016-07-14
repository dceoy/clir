#!/usr/bin/env Rscript

help_message <-
'Usage:  clir cran-install <package>
        clir cran-install --quiet <package>
        clir cran-install --help

Options:
  --quiet     Suppress output messages
  --help      Print this message'

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

set_repos <- function(cran_txt_file = '../cran_mirror', drat_txt_file = '../drat_accounts', quiet = TRUE) {
  suppressMessages(sapply(c('drat', 'devtools'), require, character.only = TRUE))
  if(file.exists(cran_txt_file)) {
    mirror <- scan(cran_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    options(repos = c(CRAN = mirror[1]))
  }
  if(require('drat') && file.exists(drat_txt_file)) {
    accounts <- scan(drat_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
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

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--quiet' = suppressMessages(cran_install(argv[-1], repos = set_repos())),
         cran_install(argv, repos = set_repos()))
} else {
  message(help_message)
}
