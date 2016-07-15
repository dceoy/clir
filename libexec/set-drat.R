#!/usr/bin/env Rscript
#
# Usage:  clir set-drat <account...>
#         clir set-drat --format
#
# Options:
#   --format            Remove existing settings

drat_txt_path <- paste0(Sys.getenv('CLIR_ROOT'), '/drat_account')

drat_add <- function(accounts, txt_file = drat_txt_path, quiet = FALSE) {
  cat_drat <- function(accounts) {
    if(! quiet) {
      message('Drat repositories --------------------------------------------------------------')
      message(paste0('  ### set at ', txt_file))
      message(paste0('  - ', accounts, collapse = '\n'))
      message()
    }
    cat(paste0(accounts, collapse = '\n'), file = txt_file)
  }
  if(file.exists(txt_file)) {
    accounts_in_txt <- scan(txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_drat(sort(unique(c(accounts_in_txt, argv))))
  } else {
    cat_drat(sort(unique(argv)))
  }
}

remove_file <- function(txt_file) {
  if(file.exists(txt_file)) {
    file.remove(txt_file)
    message(paste('Removed:', txt_file))
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(argv == '--format') {
    remove_file(drat_txt_path)
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
