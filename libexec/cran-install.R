#!/usr/bin/env Rscript
#
# Usage:  clir cran-install <package...>
#         clir cran-install --quiet <package...>
#         clir cran-install --update-all
#
# Options:
#   --quiet             Suppress output messages
#   --update-all        Update all of installed packages

clir_root <- Sys.getenv('CLIR_ROOT')
cran_txt_path <- paste0(clir_root, '/cran_url')
drat_txt_path <- paste0(clir_root, '/drat_account')

cran_install <- function(pkgs = NULL, repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
  if(is.null(pkgs)) {
    update.packages(repos = repos, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
  } else if(require('devtools')) {
    withr::with_libpaths(r_lib, devtools::update_packages(pkgs = pkgs, repos = repos, dependencies = TRUE))
  } else {
    if(length(pkgs_old <- intersect(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
      update.packages(instPkgs = pkgs_old, repos = repos, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
    }
    if(length(pkgs_new <- setdiff(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
      install.packages(pkgs = pkgs_new, repos = repos, lib = r_lib, dependencies = TRUE)
    }
  }
}

load_repos <- function(cran_txt_file = cran_txt_path, drat_txt_file = drat_txt_path, quiet = FALSE) {
  suppressMessages(sapply(c('drat', 'devtools'), require, character.only = TRUE))
  if(file.exists(cran_txt_file)) {
    urls <- scan(cran_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    options(repos = c(CRAN = urls[1]))
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

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--update-all') {
    cran_install(repos = load_repos(quiet = TRUE))
  } else if(argv == '--quiet') {
    stop('missing arguments')
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    cran_install(argv, repos = load_repos(quiet = TRUE))
  }
} else {
  pkgv <- setdiff(argv, c('--quiet', '--update-all'))
  if(sum(grepl('^-', pkgv)) > 0) {
    stop('unrecognized options')
  } else if('--update-all' %in% argv) {
    stop('invalid arguments')
  } else if('--quiet' %in% argv) {
    suppressMessages(cran_install(pkgv, repos = load_repos(quiet = TRUE)))
  } else {
    cran_install(pkgv, repos = load_repos(quiet = TRUE))
  }
}
