#!/usr/bin/env Rscript

drat_install <- function(pkgs, account, repos = c(CRAN = 'https://cran.rstudio.com/'), r_lib = .libPaths()[1]) {
  options(repos = repos)
  if(! 'drat' %in% installed.packages(lib.loc = r_lib)[,1]) {
    install.packages(pkgs = 'drat', repos = repos, lib = r_lib, dependencies = TRUE)
  }
  drat:::addRepo(account = account)
  print(getOption('repos'))
  if(length(pp <- intersect(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
    update.packages(instPkgs = pp, checkBuilt = TRUE, ask = FALSE, lib.loc = r_lib)
  }
  if(length(pd <- setdiff(pkgs, installed.packages(lib.loc = r_lib)[, 1])) > 0) {
    install.packages(pkgs = pd, lib = r_lib, dependencies = TRUE)
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 1) {
  drat_install(argv[-1], account = argv[1])
}
