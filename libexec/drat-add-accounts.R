#!/usr/bin/env Rscript

drat_txt_file <- '../r/drat_accounts'

cat_drat <- function(accounts, file) {
  message('Drat repositories --------------------------------------------------------------')
  message(paste0('  - ', accounts, collapse = '\n'))
  message()
  cat(paste0(accounts, collapse = '\n'), file = file)
}

argv <- commandArgs(trailingOnly = TRUE)

if(file.exists(drat_txt_file)) {
  accounts_in_txt <- scan(drat_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
  cat_drat(sort(unique(c(accounts_in_txt, argv))), file = drat_txt_file)
} else if(length(argv) > 0) {
  cat_drat(sort(unique(argv)), file = drat_txt_file)
}
