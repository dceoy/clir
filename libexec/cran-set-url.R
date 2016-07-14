#!/usr/bin/env Rscript

cran_txt_file <- '../r/cran_mirror'
default_url <- 'https://cran.rstudio.com/'

cat_cran <- function(urls, file) {
  message('CRAN mirror --------------------------------------------------------------------')
  message(paste0('  - ', unique(urls), collapse = '\n'))
  message()
  cat(paste0(unique(urls), collapse = '\n'), file = file)
}

argv <- commandArgs(trailingOnly = TRUE)

if(file.exists(cran_txt_file)) {
  urls_in_txt <- scan(cran_txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
  cat_cran(c(argv, setdiff(urls_in_txt, argv)), file = cran_txt_file)
} else if(length(argv) > 0) {
  cat_cran(argv, file = cran_txt_file)
} else {
  cat_cran(default_url, file = cran_txt_file)
}
