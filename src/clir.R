#!/usr/bin/env Rscript

'Command Line Interface for R package installation

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
  return(paste0(dirname(normalizePath(ifelse(length(fa) == 1,
                                             dirname(sub('--file=', '', fa)),
                                             getwd()))),
                '/'))
}

main <- function(opts, root_dir = fetch_clir_root(), r_lib = .libPaths()[1]) {
  options(warn = 1, verbose = opts[['--debug']])
  loaded <- list(opts = opts,
                 pkg = sapply(c('devtools', 'drat', 'stringr', 'yaml'),
                              require, character.only = TRUE,
                              quietly = (! opts[['--debug']])),
                 src = source(paste0(root_dir, 'src/util.R')))
  clir_yml <- paste0(root_dir, 'r/clir.yml')
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
    } else {
      add_config(new = opts[['<url>']], key = 'cran_urls', clir_yml = clir_yml)
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
