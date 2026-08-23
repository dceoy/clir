#!/usr/bin/env Rscript

doc <- "\
R Package Installer for Command Line Interface

Usage:
    clir config [-v] [--quiet] [--init]
    clir cran [-v] [--quiet] [--list] [<url>...]
    clir update [-v] [--quiet] [--cpus=<int>]
    clir install [-v] [--quiet] [--no-upgrade] [--cpus=<int>] <pkg>...
    clir download [-v] [--quiet] [--dest-dir=<path>] <pkg>...
    clir uninstall [-v] [--quiet] <pkg>...
    clir validate [-v] [--quiet] <pkg>...
    clir session [-v] [--quiet] [<pkg>...]
    clir -h|--help
    clir --version

Options:
    --init              Initialize configurations for clir
    --list              List URLs of CRAN mirrors
    --no-upgrade        Skip upgrade of already installed packages
    --cpus=<int>        Specify the number of package build CPUs
    --dest-dir=<path>   Set a destination directory [default: .]
    --quiet             Suppress messages
    -v                  Execute a command with verbose messages
    -h, --help          Print help and exit
    --version           Print version and exit

Commands:
    config              Print configurations for clir
    cran                Set the CRAN repository URL
    update              Update installed R packages via pak
    install             Install or update R package references via pak
    download            Download R packages from CRAN
    uninstall           Uninstall R packages
    validate            Load R packages to validate their installation
    session             Print session information

Arguments:
    <url>...            A CRAN repository URL
    <pkg>...            R package names or pak package references"

clir_version <- "v2.0.0"

fetch_clir_root <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  fa <- ca[grepl("^--file=", ca)]
  if (length(fa) == 1L) {
    f <- sub("--file=", "", fa)
    l <- Sys.readlink(f)
    if (is.na(l) || !nzchar(l)) {
      cmd_path <- normalizePath(f)
    } else if (startsWith(l, "/")) {
      cmd_path <- normalizePath(l)
    } else {
      cmd_path <- normalizePath(file.path(dirname(f), l))
    }
    dirname(dirname(cmd_path))
  } else {
    getwd()
  }
}

initialize_clir <- function(clir_root_dir = fetch_clir_root(), r_lib = NULL) {
  clir_root_dir <- normalizePath(path.expand(clir_root_dir), mustWork = FALSE)
  util <- source(file.path(clir_root_dir, "src/util.R"))
  startup_env <- Sys.getenv(c("CLIR_R_LIBS", "CLIR_R_LIBS_USER"))
  names(startup_env) <- c("R_LIBS", "R_LIBS_USER")
  if (is.null(r_lib)) {
    if (any(nzchar(startup_env))) {
      r_lib <- resolve_r_library(
        clir_root_dir = clir_root_dir,
        env = startup_env
      )
    } else {
      r_lib <- normalizePath(.libPaths()[[1L]], mustWork = FALSE)
    }
  } else {
    r_lib <- resolve_r_library(clir_root_dir = clir_root_dir, r_lib = r_lib)
  }
  make_clir_dirs(clir_root_dir = clir_root_dir, r_lib = r_lib)
  .libPaths(unique(c(r_lib, .libPaths())))
  list(
    clir_root_dir = clir_root_dir,
    r_lib = r_lib,
    util = util$value
  )
}

main <- function(args, clir_root_dir = fetch_clir_root(), r_lib = NULL,
                 initialized = NULL) {
  if (is.null(initialized)) {
    initialized <- initialize_clir(
      clir_root_dir = clir_root_dir,
      r_lib = r_lib
    )
  }
  clir_root_dir <- initialized$clir_root_dir
  r_lib <- initialized$r_lib
  util <- initialized$util
  ncpus <- ifelse(
    is.null(args[["--cpus"]]),
    parallel::detectCores(),
    as.integer(args[["--cpus"]])
  )
  options(warn = 1, Ncpus = ncpus, verbose = args[["-v"]])
  if (args[["-v"]]) {
    print(list(warn = 1, Ncpus = ncpus, verbose = args[["-v"]]))
  }
  loaded <- list(
    args = args,
    pkg = sapply(
      c("pak", "yaml"),
      require,
      character.only = TRUE,
      quietly = (!args[["-v"]])
    ),
    src = util
  )
  clir_yml <- file.path(clir_root_dir, "r/clir.yml")
  repos <- load_repos(clir_yml = clir_yml, quiet = args[["--quiet"]])
  options(repos = repos)
  if (args[["-v"]]) {
    print(c(loaded, list(repos = repos)))
  }
  if (args[["config"]]) {
    print_config(clir_yml = clir_yml, r_lib = r_lib, init = args[["--init"]])
  } else if (args[["cran"]]) {
    if (args[["--list"]]) {
      print_cran_mirrors(https = TRUE)
    } else if (length(args[["<url>"]]) > 0L) {
      add_config(new = args[["<url>"]], key = "repos", clir_yml = clir_yml)
    } else {
      stop("A URL or --list must be passed for this command.")
    }
  } else if (args[["update"]]) {
    update_pkgs(
      repos = repos,
      r_lib = r_lib,
      quiet = args[["--quiet"]]
    )
  } else if (args[["install"]]) {
    install_pkgs(
      pkgs = args[["<pkg>"]],
      repos = repos,
      r_lib = r_lib,
      upgrade = (!args[["--no-upgrade"]]),
      quiet = args[["--quiet"]]
    )
  } else if (args[["download"]]) {
    download.packages(
      pkgs = args[["<pkg>"]],
      destdir = args[["--dest-dir"]],
      repos = repos,
      type = "source"
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
  initialized <- initialize_clir()
  args <- docopt::docopt(doc, version = clir_version)
  if (args[["--quiet"]]) {
    suppressMessages(main(args = args, initialized = initialized))
  } else {
    main(args = args, initialized = initialized)
  }
}
