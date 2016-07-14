#!/usr/bin/env Rscript

help_message <-
'Usage:  clir github-install <username>/<repo>
        clir github-install --quiet <username>/<repo>
        clir github-install --help

Options:
  --quiet   Suppress output messages
  --help    Print this message'

github_install <- function(pkgs, r_lib = .libPaths()[1]) {
  withr::with_libpaths(r_lib, devtools::install_github(pkgs))
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--quiet' = suppressMessages(github_install(argv[-1])),
         github_install(argv))
} else {
  message(help_message)
}
