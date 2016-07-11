#!/usr/bin/env Rscript

bioc_install <- function(pkgs, mirror = 'https://bioconductor.org', r_lib = .libPaths()[1]) {
  options(BioC_mirror = mirror)
  if(! 'biocLite' %in% ls()) source(paste0(mirror, '/biocLite.R'))
  biocLite(pkgs = pkgs, ask = FALSE, lib.loc = r_lib)
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  bioc_install(argv)
}
