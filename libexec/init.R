#!/usr/bin/env Rscript

suppressMessages({
  source('cran-set-url.R')
  source('cran-install.R')
})
set_repos()
message('R library installation ---------------------------------------------------------')
status <- sapply(c('devtools', 'drat'),
                 function(p) {
                   suppressMessages(cran_install(p, repos = getOption('repos')))
                   return(paste0(p,
                                 ': ',
                                 ifelse(suppressMessages(require(p, character.only = TRUE)),
                                        'ok',
                                        'no')))
                 })
message(paste0('  ', paste0(status, collapse = '\n  '), '\n'))
