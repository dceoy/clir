#!/usr/bin/env Rscript
#
# Usage:  clir init --default
#         clir init --cran-url <url>
#
# Options:
#   --default           Install required libraries
#   --cran-url          Install required libraries with a selected CRAN repository

clir_root <- Sys.getenv('CLIR_ROOT')
suppressMessages({
  source(paste0(clir_root, '/libexec/set-cran.R'))      # set_cran_url()
  source(paste0(clir_root, '/libexec/cran-install.R'))  # cran_install(), load_repos()
})

init <- function(urls = NULL) {
  if(! file.exists(cran_txt_abs_path)) {
    set_cran_url(urls, quiet = TRUE)
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
    stop('invalid arguments')
  } else if(sum(grepl('^-', argv[-1])) > 0) {
    stop('unrecognized options')
  } else {
    init(argv[-1])
  }
}
