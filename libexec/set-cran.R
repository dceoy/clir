#!/usr/bin/env Rscript
#
# Usage:  clir set-cran <url>
#         clir set-cran --default
#         clir set-cran --format
#         clir set-cran --list
#
# Options:
#   --default           Set https://cran.rstudio.com/ as the repository
#   --format            Remove existing settings
#   --list              List available CRAN mirrors (https)

cran_txt_path <- paste0(Sys.getenv('CLIR_ROOT'), '/cran_url')

set_cran_url <- function(url = NULL, txt_file = cran_txt_path, quiet = FALSE) {
  url_new <- ifelse(is.null(url), 'https://cran.rstudio.com/', url)
  cat_mirror <- function(url) {
    if(! quiet) {
      message('CRAN mirror --------------------------------------------------------------------')
      message(paste0('  ### set at ', txt_file))
      message(paste0('  - ', unique(url), collapse = '\n'))
      message()
    }
    cat(paste0(unique(url), collapse = '\n'), file = txt_file)
  }
  if(file.exists(txt_file)) {
    urls_in_txt <- scan(txt_file, what = character(), sep = '\n', quiet = TRUE, blank.lines.skip = FALSE)
    cat_mirror(c(url_new, setdiff(urls_in_txt, url_new)))
  } else {
    cat_mirror(url_new)
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

remove_file <- function(txt_file) {
  if(file.exists(txt_file)) {
    file.remove(txt_file)
    message(paste('Removed:', txt_file))
  }
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(grepl('^-', argv)) {
    switch(argv,
           '--list' = print_cran_mirrors(https = TRUE),
           '--format' = remove_file(cran_txt_path),
           '--default' = set_cran_url(),
           stop('unrecognized options'))
  } else {
    set_cran_url(argv)
  }
} else {
  if(argv[1] %in% c('--list', '--format', '--default')) {
    stop('invalid arguments')
  } else if(sum(grepl('^-', argv)) > 0) {
    stop('unrecognized options')
  } else {
    set_cran_url(argv)
  }
}
