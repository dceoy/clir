#!/usr/bin/env Rscript

initilize_config <- function(config_yml) {
  yaml::write_yaml(list(cran_urls = c('https://cran.rstudio.com/'),
                        drat_repos = c('eddelbuettel')),
                   file = config_yml)
  message(stringr::str_c('Initialized: ', config_yml))
}

print_config <- function(config_yml, r_lib = .libPaths()) {
  print(list(clir = yaml::read_yaml(config_yml),
             libpath = r_lib,
             r = version))
}

add_config <- function(new, key, config_yml) {
  if (file.exists(config_yml)) {
    cf <- yaml::read_yaml(config_yml)
    cf[[key]] <- c(new, setdiff(cf[[key]], new))
    yaml::write_yaml(cf, file = config_yml)
    message(stringr::str_c('Overwrited: ', config_yml))
  } else {
    cf <- list()
    cf[[key]] <- new
    yaml::write_yaml(cf, file = config_yml)
    message(stringr::str_c('Created: ', config_yml))
  }
}

print_cran_mirrors <- function(https = TRUE) {
  d <- data.frame(getCRANmirrors())
  if (https) {
    print(subset(d, grepl('^https://', d$URL))[, c('Name', 'URL')])
  } else {
    print(d[, c('Name', 'URL')])
  }
}

validate_loading <- function(pkgs, quiet = FALSE) {
  v <- suppressMessages(sapply(as.vector(pkgs), require, character.only = TRUE))
  result <- list(succeeded = names(v)[v], failed = names(v)[! v])
  if (quiet) {
    if (suppressMessages(require('devtools'))) {
      print(devtools::session_info(pkgs = pkgs, include_base = TRUE))
    }
    cat('\nLoading test ', '-' * 67, '\n')
    if (length(result$succeeded) > 0) {
      cat(' Succeeded:\n   ',
          stringr::str_c(result$succeeded, collapse = '\n   '), '\n')
    }
    if (length(result$failed) > 0) {
      cat(' Failed:\n   ',
          stringr::str_c(result$failed, collapse = '\n   '), '\n')
    }
    cat('\n')
    if (length(result$failed) == 0) message('Loading succeeded.')
  }
  if (length(result$failed) > 0) stop('Loading failed.')
}
