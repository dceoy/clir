#!/usr/bin/env Rscript

clir_root <- sub('/[^/]+$', '/', getwd())
drat_txt_file <- paste0(clir_root, 'drat_accounts')

help_message <-
'Usage:  clir drat-add-accounts <account>
        clir drat-add-accounts --format
        clir drat-add-accounts --help

Options:
  --format    Remove existing settings
  --help      Print this message'

drat_add <- function(accounts, file) {
  cat_drat <- function(accounts, file) {
    message('Drat repositories --------------------------------------------------------------')
    message(paste0('  ### set by ', file))
    message(paste0('  - ', accounts, collapse = '\n'))
    message()
    cat(paste0(accounts, collapse = '\n'), file = file)
  }
  if(file.exists(file)) {
    accounts_in_txt <- scan(file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_drat(sort(unique(c(accounts_in_txt, argv))), file = file)
  } else {
    cat_drat(sort(unique(argv)), file = file)
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--format' = file.remove(drat_txt_file),
         drat_add(argv, file = drat_txt_file))
} else {
  message(help_message),
}
