#!/usr/bin/env Rscript

help_message <-
'Usage:  clir bioc-install <package>
        clir bioc-install --quiet <package>
        clir bioc-install --help

Options:
  --quiet   Suppress output messages
  --help    Print this message'

bioc_install <- function(pkgs, mirror = 'https://bioconductor.org', r_lib = .libPaths()[1]) {
  options(BioC_mirror = mirror)
  if(! 'biocLite' %in% ls()) source(paste0(mirror, '/biocLite.R'))
  biocLite(pkgs = pkgs, ask = FALSE, lib.loc = r_lib)
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--quiet' = suppressMessages(bioc_install(argv[-1])),
         bioc_install(argv))
} else {
  message(help_message)
}
