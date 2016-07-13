#!/usr/bin/env Rscript

init_devtools <- function(repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
  if(suppressMessages(require('devtools'))) {
    withr::with_libpaths(r_lib,
                         devtools::update_packages(pkgs = 'devtools', repos = repos, dependencies = TRUE))
  } else {
    install.packages(pkgs = 'devtools', repos = repos, lib = r_lib, dependencies = TRUE)
  }
  return(devtools::has_devel())
}

init_devtools()
