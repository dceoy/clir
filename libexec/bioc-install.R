#!/usr/bin/env Rscript
#
# Usage:  clir bioc-install <package...>
#         clir bioc-install --quiet <package...>
#
# Options:
#   --quiet             Suppress output messages

bioc_install <- function(pkgs, mirror = 'https://bioconductor.org', r_lib = .libPaths()[1]) {
  options(BioC_mirror = mirror)
  if(! 'biocLite' %in% ls()) source(paste0(mirror, '/biocLite.R'))
  biocLite(pkgs = pkgs, ask = FALSE, lib.loc = r_lib)
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--quiet') {
    stop('missing arguments')
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    bioc_install(argv)
  }
} else {
  pkgv <- setdiff(argv, '--quiet')
  if(sum(grepl('^-', pkgv)) > 0) {
    stop('unrecognized options')
  } else if('--quiet' %in% argv) {
    suppressMessages(bioc_install(pkgv))
  } else {
    bioc_install(pkgv)
  }
}
