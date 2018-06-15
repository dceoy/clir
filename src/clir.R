#!/usr/bin/env Rscript

'R package manager for command line interface

Usage:
    clir config [--debug] [--init]
    clir cran [--debug] [--list] [<url>...]
    clir drat [--debug] <repo>...
    clir update [--debug] [--quiet]
    clir install [--debug] [--quiet] [--no-upgrade] [--devt=<type>] <pkg>...
    clir uninstall [--debug] <pkg>...
    clir validate [--debug] [--quiet] <pkg>...
    clir session [--debug] [<pkg>...]
    clir -h|--help
    clir -v|--version

Options:
    --debug             Execute a command with debug messages
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --devt=<type>       Install R packages using `devtools::install_<type>`
                        [choices: cran, github, bitbucket, bioc]
    --no-upgrade        Skip upgrade of old R packages
    --quiet             Suppress messages
    -h, --help          Print help and exit
    -v, --version       Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set URLs of CRAN mirror sites
    drat                Set Drat repositories
    update              Update R packages installed via CRAN
    install             Install or update R packages
    uninstall           Uninstall R packages
    validate            Load R packages to validate their installation
    session             Print session infomation

Arguments:
    <url>...            URLs of CRAN mirrors
    <repo>...           Drat repository names
    <pkg>...            R package names' -> doc

clir_version <- 'v1.0.2'

fetch_clir_root <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- ca[grepl('^--file=', ca)]
  if (length(fa) == 1) {
    f <- sub('--file=', '', fa)
    l <- Sys.readlink(f)
    if (l == '') {
      return(dirname(dirname(normalizePath(f))))
    } else if (startsWith(l, '/')) {
      return(dirname(dirname(normalizePath(l))))
    } else {
      return(dirname(dirname(normalizePath(paste0(dirname(f), '/', l)))))
    }
  } else {
    return(normalizePath(getwd()))
  }
}

main <- function(opts, clir_root_dir = fetch_clir_root(),
                 r_lib = .libPaths()[1]) {
  options(warn = 1, verbose = opts[['--debug']])
  loaded <- list(opts = opts,
                 pkg = sapply(c('devtools', 'drat', 'stringr', 'yaml'),
                              require, character.only = TRUE,
                              quietly = (! opts[['--debug']])),
                 src = source(file.path(clir_root_dir, 'src/util.R')))
  make_clir_dirs(clir_root_dir = clir_root_dir)
  clir_yml <- file.path(clir_root_dir, 'r/clir.yml')
  repos <- load_repos(clir_yml = clir_yml, quiet = opts[['--quiet']])
  if (opts[['--debug']]) {
    print(c(loaded, repos = repos))
  }
  if (opts[['config']]) {
    print_config(clir_yml = clir_yml, r_lib = r_lib,
                 initialize = opts[['--init']])
  } else if (opts[['cran']]) {
    if (opts[['--list']]) {
      print_cran_mirrors(https = TRUE)
    } else if (length(opts[['<url>']]) > 0) {
      add_config(new = opts[['<url>']], key = 'cran_urls', clir_yml = clir_yml)
    } else {
      message('URLs or --list must be passed for this command.')
    }
  } else if (opts[['drat']]) {
    add_config(new = opts[['<repo>']], key = 'drat_repos', clir_yml = clir_yml)
  } else if (opts[['update']]) {
    update.packages(lib.loc = r_lib, repos = repos, checkBuilt = TRUE,
                    ask = FALSE, quiet = opts[['--quiet']])
  } else if (opts[['install']]) {
    install_pkgs(pkgs = opts[['<pkg>']], repos = repos, r_lib = r_lib,
                 devt = opts[['--devt']], upgrade = (! opts[['--no-upgrade']]),
                 quiet = opts[['--quiet']])
  } else if (opts[['uninstall']]) {
    remove.packages(pkgs = opts[['<pkg>']], lib = r_lib)
  } else if (opts[['validate']]) {
    validate_loading(pkgs = opts[['<pkg>']], quiet = opts[['--quiet']])
  } else if (opts[['session']]) {
    print_sessions(pkgs = opts[['<pkg>']])
  } else {
    stop('invalid subcommand')
  }
}

if (! interactive()) {
  opts <- docopt::docopt(doc, version = clir_version)
  if (opts[['--quiet']]) {
    suppressMessages(main(opts = opts))
  } else {
    main(opts = opts)
  }
}
