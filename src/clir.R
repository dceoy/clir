#!/usr/bin/env Rscript

doc <- "\
R Package Installer for Command Line Interface

Usage:
    clir config [-v] [--quiet] [--init]
    clir cran [-v] [--quiet] [--list] [<url>...]
    clir drat [-v] [--quiet] <repo>...
    clir update [-v] [--quiet] [--bioc] [--cpus=<int>]
    clir install [-v] [--quiet] [--devt=<type>|--bioc] [--no-upgrade] [--cpus=<int>] <pkg>...
    clir download [-v] [--quiet] [--dest-dir=<path>] <pkg>...
    clir uninstall [-v] [--quiet] <pkg>...
    clir validate [-v] [--quiet] <pkg>...
    clir session [-v] [--quiet] [<pkg>...]
    clir -h|--help
    clir --version

Options:
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --devt=<type>       Use `devtools::install_<type>`
                        [choices: cran, github, bitbucket, bioc]
    --bioc              Use BiocManager::install
    --no-upgrade        Skip upgrade of old R packages
    --cpus=<int>        Specify Ncpus
    --dest-dir=<path>   Set a destination directory [default: .]
    --quiet             Suppress messages
    -v                  Execute a command with verbose messages
    -h, --help          Print help and exit
    --version           Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set URLs of CRAN mirror sites
    drat                Set Drat repositories
    update              Update installed R packages via CRAN or Bioconductor
    install             Install or update R packages
    download            Download R packages from CRAN
    uninstall           Uninstall R packages
    validate            Load R packages to validate their installation
    session             Print session infomation

Arguments:
    <url>...            URLs of CRAN mirrors
    <repo>...           Drat repository names
    <pkg>...            R package names"

clir_version <- "v1.2.0"

fetch_clir_root <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- ca[grepl("^--file=", ca)]
  if (length(fa) == 1) {
    f <- sub("--file=", "", fa)
    l <- Sys.readlink(f)
    if (is.na(l)) {
      cmd_path <- normalizePath(f)
    } else if (startsWith(l, "/")) {
      cmd_path <- normalizePath(l)
    } else {
      cmd_path <- normalizePath(file.path(dirname(f), l))
    }
    return(dirname(dirname(cmd_path)))
  } else {
    return(getwd())
  }
}

main <- function(args, clir_root_dir = fetch_clir_root(),
                 r_lib = .libPaths()[1]) {
  ncpus <- ifelse(is.null(args[["--cpus"]]),
    parallel::detectCores(), as.integer(args[["--cpus"]])
  )
  options(warn = 1, Ncpus = ncpus, verbose = args[["-v"]])
  if (args[["-v"]]) {
    print(list(warn = 1, Ncpus = ncpus, verbose = args[["-v"]]))
  }
  loaded <- list(
    args = args,
    pkg = sapply(c("devtools", "drat", "stringr", "yaml"),
      require,
      character.only = TRUE,
      quietly = (!args[["-v"]])
    ),
    src = source(file.path(clir_root_dir, "src/util.R"))
  )
  make_clir_dirs(clir_root_dir = clir_root_dir)
  clir_yml <- file.path(clir_root_dir, "r/clir.yml")
  repos <- load_repos(clir_yml = clir_yml, quiet = args[["--quiet"]])
  options(repos = repos)
  if (args[["-v"]]) {
    print(c(loaded, sapply(c("repos"), getOption)))
  }
  if (args[["config"]]) {
    print_config(clir_yml = clir_yml, r_lib = r_lib, init = args[["--init"]])
  } else if (args[["cran"]]) {
    if (args[["--list"]]) {
      print_cran_mirrors(https = TRUE)
    } else if (length(args[["<url>"]]) > 0) {
      add_config(new = args[["<url>"]], key = "cran_urls", clir_yml = clir_yml)
    } else {
      stop("URLs or --list must be passed for this command.")
    }
  } else if (args[["drat"]]) {
    add_config(new = args[["<repo>"]], key = "drat_repos", clir_yml = clir_yml)
  } else if (args[["update"]]) {
    update_pkgs(
      repos = repos, r_lib = r_lib, bioc = args[["--bioc"]],
      quiet = args[["--quiet"]]
    )
  } else if (args[["install"]]) {
    install_pkgs(
      pkgs = args[["<pkg>"]], repos = repos,
      bioc = args[["--bioc"]], devt = args[["--devt"]],
      r_lib = r_lib, upgrade = (!args[["--no-upgrade"]]),
      quiet = args[["--quiet"]]
    )
  } else if (args[["download"]]) {
    download.packages(
      pkgs = args[["<pkg>"]], destdir = args[["--dest-dir"]],
      repos = repos, type = "source"
    )
  } else if (args[["uninstall"]]) {
    remove.packages(pkgs = args[["<pkg>"]], lib = r_lib)
  } else if (args[["validate"]]) {
    validate_loading(pkgs = args[["<pkg>"]], quiet = args[["--quiet"]])
  } else if (args[["session"]]) {
    print_sessions(pkgs = args[["<pkg>"]])
  } else {
    stop("invalid subcommand")
  }
}

if (!interactive()) {
  args <- docopt::docopt(doc, version = clir_version)
  if (args[["--quiet"]]) {
    suppressMessages(main(args = args))
  } else {
    main(args = args)
  }
}
