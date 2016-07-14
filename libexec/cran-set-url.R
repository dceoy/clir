#!/usr/bin/env Rscript

clir_root <- sub('/[^/]+$', '/', getwd())
cran_txt_file <- paste0(clir_root, 'cran_mirror')
default_mirror <- 'https://cran.rstudio.com/'

help_message <-
'Usage:  clir cran-set-url <url>
        clir cran-set-url --default
        clir cran-set-url --format
        clir cran-set-url --list
        clir cran-set-url --help

Options:
  --default   Set https://cran.rstudio.com/ as the mirror
  --format    Remove existing settings
  --list      List available CRAN mirrors (https)
  --help      Print this message'

list_mirror <- function(https = TRUE) {
  df <- data.frame(getCRANmirrors())
  if(https) {
    print(subset(df, grepl('^https://', df$URL))[, c('Name', 'URL')])
  } else {
    print(df[, c('Name', 'URL')])
  }
}

cran_set <- function(urls, file) {
  cat_cran <- function(urls, file) {
    message('CRAN mirror --------------------------------------------------------------------')
    message(paste0('  ### set by ', file))
    message(paste0('  - ', unique(urls), collapse = '\n'))
    message()
    cat(paste0(unique(urls), collapse = '\n'), file = file)
  }
  if(file.exists(file)) {
    urls_in_txt <- scan(file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_cran(c(urls, setdiff(urls_in_txt, urls)), file = file)
  } else {
    cat_cran(urls, file = file)
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--list' = list_mirror(https = TRUE),
         '--format' = file.remove(cran_txt_file),
         '--default' = cran_set(default_mirror, file = cran_txt_file),
         cran_set(argv, file = cran_txt_file))
} else {
  message(help_message)
}
