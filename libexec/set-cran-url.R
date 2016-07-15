#!/usr/bin/env Rscript
#
# Usage:  set-cran-url <url>
#         set-cran-url --default
#         set-cran-url --format
#         set-cran-url --list
#
# Options:
#   --default         Set https://cran.rstudio.com/ as the repository
#   --format          Remove existing settings
#   --list            List available CRAN mirrors (https)

cran_txt_abs_path <- paste0(sub('/[^/]+$', '/', getwd()), 'cran_url')

set_cran_url <- function(urls = 'https://cran.rstudio.com/', abs_path = cran_txt_abs_path, quiet = FALSE) {
  cat_mirror <- function(urls) {
    if(! quiet) {
      message('CRAN mirror --------------------------------------------------------------------')
      message(paste0('  ### set by ', abs_path))
      message(paste0('  - ', unique(urls), collapse = '\n'))
      message()
    }
    cat(paste0(unique(urls), collapse = '\n'), file = abs_path)
  }
  if(file.exists(abs_path)) {
    urls_in_txt <- scan(abs_path, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_mirror(c(urls, setdiff(urls_in_txt, urls)))
  } else {
    cat_mirror(urls)
  }
}

print_cran_mirrors <- function(https = TRUE) {
  df <- data.frame(getCRANmirrors())
  if(https) {
    print(subset(df, grepl('^https://', df$URL))[, c('Name', 'URL')])
  } else {
    print(df[, c('Name', 'URL')])
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(grepl('^-', argv)) {
    switch(argv,
           '--list' = print_cran_mirrors(https = TRUE),
           '--format' = file.remove(cran_txt_abs_path),
           '--default' = set_cran_url(),
           stop('unrecognized options'))
  } else {
    set_cran_url(argv)
  }
} else {
  if(argv[1] %in% c('--list', '--format', '--default')) {
    stop('invalid arguments'),
  } else if(sum(grepl('^-', argv)) > 0) {
    stop('unrecognized options')
  } else {
    set_cran_url(argv)
  }
}
