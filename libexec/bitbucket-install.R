#!/usr/bin/env Rscript
#
# Usage:  clir bitbucket-install <username/repo...>
#         clir bitbucket-install --quiet <username/repo...>
#
# Options:
#   --quiet             Suppress output messages

bitbucket_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_bitbucket(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--quiet') {
    stop('missing arguments')
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    bitbucket_install(argv)
  }
} else {
  pkgv <- setdiff(argv, '--quiet')
  if(sum(grepl('^-', pkgv)) > 0) {
    stop('unrecognized options')
  } else if('--quiet' %in% argv) {
    suppressMessages(bitbucket_install(pkgv))
  } else {
    bitbucket_install(pkgv)
  }
}
