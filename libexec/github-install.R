#!/usr/bin/env Rscript

github_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_github(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  github_install(argv)
}
