#!/usr/bin/env Rscript

test_load <- function(pkgs) {
  v_status <- suppressMessages(sapply(as.vector(pkgs), require, character.only = TRUE))
  if(suppressMessages(require('devtools'))) {
    print(devtools::session_info())
  }
  message('\nLoading test -------------------------------------------------------------------')
  if(length(v_succeeded <- names(v_status)[v_status]) > 0) {
    message(' Suceeded:')
    message(paste0(paste0('  ', v_succeeded), collapse = '\n'))
  }
  if(length(v_failed <- names(v_status)[! v_status]) > 0) {
    message(' Failed:')
    message(paste0(paste0('  ', v_failed), collapse = '\n'))
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  test_load(argv)
}
