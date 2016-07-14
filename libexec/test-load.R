#!/usr/bin/env Rscript

help_message <-
'Usage:  clir test-load <package>
        clir test-load --help

Options:
  --help      Print this message'

test_load <- function(pkgs) {
  v_status <- suppressMessages(sapply(as.vector(pkgs), require, character.only = TRUE))
  if(suppressMessages(require('devtools'))) {
    print(devtools::session_info())
  }
  cat('\nLoading test -------------------------------------------------------------------\n')
  if(length(v_succeeded <- names(v_status)[v_status]) > 0) {
    cat(' Suceeded:\n   - ', paste(v_succeeded, collapse = '\n   - '), '\n', sep = '')
  }
  if(length(v_failed <- names(v_status)[! v_status]) > 0) {
    cat(' Failed:\n   - ', paste(v_failed, collapse = '\n   - '), '\n', sep = '')
  }
  cat('\n')
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         test_load(argv))
} else {
  message(help_message)
}
