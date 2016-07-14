#!/usr/bin/env Rscript

bitbucket_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_bitbucket(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  bitbucket_install(argv)
}
