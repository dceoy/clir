#!/usr/bin/env Rscript

help_message <-
'Usage:  clir init --default
        clir init --cran-url <url>
        clir init --help

Options:
  --default   Install required libraries
  --cran-url  Install required libraries with a selected CRAN mirror
  --help      Print this message'

abort <- function(msg, help) {
  stop(paste0(msg, '\n\n', help, '\n'))
}

clir_init <- function(url = NA) {
  suppressMessages({
    source('cran-set-url.R')  # cran_txt_file, default_mirror, cran_set()
    source('cran-install.R')  # cran_install(), set_repos()
    if(! is.na(url)) {
      cran_set(url, file = cran_txt_file)
    } else if(! file.exists(cran_txt_file)) {
      cran_set(default_mirror, file = cran_txt_file)
    }
  })
  set_repos(quiet = FALSE)
  message('R library installation ---------------------------------------------------------')
  lapply(c('devtools', 'drat'),
         function(p) {
           suppressMessages(cran_install(p, repos = getOption('repos')))
           message(paste0('  ', p, ': ',
                          ifelse(suppressMessages(require(p, character.only = TRUE)), 'ok', 'no')))
         })
  message()
}

if(length(argv <- commandArgs(trailingOnly = TRUE)) > 0) {
  switch(argv[1],
         '--help' = message(help_message),
         '--cran-url' = clir_init(argv[-1]),
         '--default' = clir_init(),
         abort('Invalid arguments', help = help_message))
} else {
  message(help_message)
}
