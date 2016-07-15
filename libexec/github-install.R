#!/usr/bin/env Rscript
#
# Usage:  github-install <username/repo...>
#         github-install --quiet <username/repo...>
#
# Options:
#   --quiet           Suppress output messages

github_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_github(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--quiet') {
    stop('missing arguments')
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    github_install(argv)
  }
} else {
  pkgv <- setdiff(argv, '--quiet')
  if(sum(grepl('^-', pkgv)) > 0) {
    stop('unrecognized options')
  } else if('--quiet' %in% argv) {
    suppressMessages(github_install(pkgv))
  } else {
    github_install(pkgv)
  }
}
