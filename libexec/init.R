#!/usr/bin/env Rscript
#
# Usage:  init.R --default
#         init.R --cran-url <url>
#
# Options:
#   --default         Install required libraries
#   --cran-url        Install required libraries with a selected CRAN repository

init <- function(url = NA) {
  suppressMessages({
    source('set-cran-url.R')  # set_cran_url()
    source('cran-install.R')  # cran_install(), load_repos()
  })
  if(! is.na(url)) {
    set_cran_url(url, quiet = TRUE)
  } else if(! file.exists(cran_txt_abs_path)) {
    set_cran_url(quiet = TRUE)
  }
  load_repos()
  message('R library installation ---------------------------------------------------------')
  lapply(c('devtools', 'drat'),
         function(p) {
           suppressMessages(cran_install(p, repos = getOption('repos')))
           message(paste0('  ', p, ': ',
                          ifelse(suppressMessages(require(p, character.only = TRUE)),
                                 'ok',
                                 'no')))
         })
  message()
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) < 1) {
  message('Nothig to do.')
} else if(length(argv) == 1) {
  if(grepl('^-', argv)) {
    switch(argv,
           '--default' = init(),
           '--cran-url' = stop('missing arguments'),
           stop('unrecognized options'))
  } else {
    stop('invalid arguments')
  }
} else {
  if(argv[1] != '--cran-url') {
    stop('invalid arguments'),
  } else if(sum(grepl('^-', argv[-1])) > 0) {
    stop('unrecognized options')
  } else {
    init(argv[-1])
  }
}
