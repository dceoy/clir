#!/usr/bin/env Rscript

'Install R packages from command line

Usage:
    clir config [--debug] [--init]
    clir cran [--debug] [--list] <url>...
    clir drat [--debug] <repo>...
    clir update [--debug] [--quiet]
    clir install [--debug] [--quiet] [--from=<type>] [--cpu=<int>] <pkg>...
    clir uninstall [--debug] <pkg>...
    clir validate [--debug] [--quiet] <pkg>...
    clir session [--debug] [<pkg>...]
    clir -h|--help
    clir -v|--version

Options:
    --debug             Execute a command with debug messages
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --from=<type>       Select an installation type
                        { cran, github, bitbucket, bioconductor }
                        [default: cran]
    --cpu=<int>         Limit a number of CPUs
    --quiet             Suppress messages
    -h, --help          Print help and exit
    -v, --version       Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set URLs of CRAN mirror sites
    drat                Set Drat repositories
    update              Update R packages from CRAN
    install             Install or update R packages
    uninstall           Uninstall R packages
    validate            Load installed R packages to validate them
    session             Print session infomation

Arguments:
    <url>...            URLs of CRAN mirrors
    <repo>...           Drat repository names
    <pkg>...            R package names' -> doc

clir_version <- '1.0.0-dev'

fetch_clir_root <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- ca[grepl('^--file=', ca)]
  return(paste0(dirname(normalizePath(ifelse(length(fa) == 1,
                                             dirname(sub('--file=', '', fa)),
                                             getwd()))),
                '/'))
}

main <- function(opts, root_dir = fetch_clir_root(), r_lib = .libPaths()[1]) {
  options(warn = 1, verbose = opts[['--debug']],
          Ncpus = ifelse(is.null(opts[['--cpu']]),
                         parallel::detectCores(), as.integer(opts[['--cpu']])))
  clir_yml <- paste0(root_dir, 'r/clir.yml')
  loaded <- list(opts = opts,
                 pkg = sapply(c('devtools', 'drat', 'stringr', 'yaml'),
                              require, character.only = TRUE, quietly = TRUE),
                 src = sapply(paste0(root_dir, 'src/',
                                     c('utility.R', 'installer.R')),
                              source))
  if (opts[['--debug']]) print(loaded)
  if (! file.exists(clir_yml)) initilize_config(clir_yml = clir_yml)
  if (opts[['config']]) {
    if (opts[['--init']]) initilize_config(clir_yml = clir_yml)
    print_config(clir_yml = clir_yml, r_lib = r_lib)
  } else if (opts[['cran']]) {
    if (opts[['--list']]) {
      print_cran_mirrors(https = TRUE)
    } else {
      add_config(new = opts[['<url>']], key = 'cran_urls', clir_yml = clir_yml)
    }
  } else if (opts[['drat']]) {
    add_config(new = opts[['<repo>']], key = 'drat_repos', clir_yml = clir_yml)
  } else if (opts[['update']]) {
    update_cran_pkgs(clir_yml = clir_yml, r_lib = r_lib,
                     quiet = opts[['--quiet']])
  } else if (opts[['install']]) {
    install_pkgs(pkgs = opts[['<pkg>']], clir_yml = clir_yml, r_lib = r_lib,
                 from = opts[['--from']], quiet = opts[['--quiet']])
  } else if (opts[['uninstall']]) {
    remove.packages(pkgs = opts[['<pkg>']], lib = r_lib)
  } else if (opts[['validate']]) {
    validate_loading(pkgs = opts[['<pkg>']], quiet = opts[['--quiet']])
  } else if (opts[['session']]) {
    devtools::session_info(pkgs = opts[['<pkg>']], include_base = TRUE)
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
