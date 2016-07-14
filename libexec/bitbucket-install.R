#!/usr/bin/env Rscript

help_message <-
'Usage:  clir bitbucket-install <username>/<repo>
        clir bitbucket-install --quiet <username>/<repo>
        clir bitbucket-install --help

Options:
  --quiet   Suppress output messages
  --help    Print this message'

bitbucket_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_bitbucket(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--quiet' = suppressMessages(bitbucket_install(argv[-1])),
         bitbucket_install(argv))
} else {
  message(help_message)
}
