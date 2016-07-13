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
  cran_install(argv)
}
