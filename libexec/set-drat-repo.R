#!/usr/bin/env Rscript
#
# Usage:  set-drat-repo <account...>
#         set-drat-repo --format
#
# Options:
#   --format          Remove existing settings

drat_txt_abs_path <- paste0(sub('/[^/]+$', '/', getwd()), 'drat_account')

drat_add <- function(accounts, abs_path = drat_txt_abs_path, quiet = FALSE) {
  cat_drat <- function(accounts) {
    if(! quiet) {
      message('Drat repositories --------------------------------------------------------------')
      message(paste0('  ### set by ', abs_path))
      message(paste0('  - ', accounts, collapse = '\n'))
      message()
    }
    cat(paste0(accounts, collapse = '\n'), file = abs_path)
  }
  if(file.exists(abs_path)) {
    accounts_in_txt <- scan(abs_path, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_drat(sort(unique(c(accounts_in_txt, argv))))
  } else {
    cat_drat(sort(unique(argv)))
  }
}


if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--format') {
    file.remove(drat_txt_abs_path)
  } else if(grepl('^-', argv)) {
    stop('unrecognized options')
  } else {
    drat_add(argv)
  }
} else {
  if(argv[1] == '--format') {
    stop('invailid arguments')
  } else if(sum(grepl('^-', argv)) > 0) {
    stop('unrecognized options')
  } else {
    drat_add(argv)
  }
}
