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

clir_version <- "v2.1.0"

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


# Keep the docopt-shaped argument contract used by main(), while optparse
# handles option validation and conversion for each supported subcommand.
parse_clir_args <- function(argv = commandArgs(trailingOnly = TRUE)) {
  commands <- c(
    "config", "cran", "update", "install", "download",
    "uninstall", "validate", "session"
  )
  control_tokens <- argv
  if ("--" %in% argv) {
    control_tokens <- head(argv, match("--", argv) - 1L)
  }
  if (any(control_tokens %in% c("-h", "--help"))) {
    return(list(action = "help"))
  }
  if ("--version" %in% control_tokens) {
    return(list(action = "version"))
  }
  if (length(argv) == 0L || !(argv[[1L]] %in% commands)) {
    stop("Invalid or missing subcommand. Run clir --help.", call. = FALSE)
  }

  command <- argv[[1L]]
  option_list <- list(
    optparse::make_option(
      c("-v", "--verbose"), action = "store_true",
      dest = "-v", default = FALSE
    ),
    optparse::make_option(
      "--quiet", action = "store_true", dest = "--quiet", default = FALSE
    )
  )
  if (command == "config") {
    option_list <- c(option_list, list(
      optparse::make_option(
        "--init", action = "store_true", default = FALSE
      )
    ))
  }
  if (command == "cran") {
    option_list <- c(option_list, list(
      optparse::make_option(
        "--list", action = "store_true", default = FALSE
      )
    ))
  }
  if (command %in% c("update", "install")) {
    option_list <- c(option_list, list(
      optparse::make_option("--cpus", type = "integer")
    ))
  }
  if (command == "install") {
    option_list <- c(option_list, list(
      optparse::make_option(
        "--no-upgrade", action = "store_true", default = FALSE
      )
    ))
  }
  if (command == "download") {
    option_list <- c(option_list, list(
      optparse::make_option("--dest-dir", default = ".")
    ))
  }

  # optparse expects options before operands. Preserve docopt's acceptance
  # of options interspersed with package names by moving option tokens first.
  # An explicit "--" keeps every subsequent token as a literal operand.
  tokens <- argv[-1L]
  option_tokens <- character()
  operands <- character()
  after_separator <- FALSE
  i <- 1L
  while (i <= length(tokens)) {
    token <- tokens[[i]]
    is_option <- !after_separator && startsWith(token, "-") && token != "-"
    if (!after_separator && identical(token, "--")) {
      after_separator <- TRUE
    } else if (is_option) {
      option_tokens <- c(option_tokens, token)
      flag <- sub("=.*$", "", token)
      requires_value <- flag %in% c("--cpus", "--dest-dir")
      has_inline_value <- grepl("=", token, fixed = TRUE)
      if (requires_value && !has_inline_value) {
        if (i == length(tokens)) {
          stop(paste("Missing value for", flag), call. = FALSE)
        }
        i <- i + 1L
        option_tokens <- c(option_tokens, tokens[[i]])
      }
    } else {
      operands <- c(operands, token)
    }
    i <- i + 1L
  }

  parser <- optparse::OptionParser(
    usage = paste("clir", command, "[options] [arguments]"),
    option_list = option_list,
    add_help_option = FALSE
  )
  parsed <- withCallingHandlers(
    optparse::parse_args(
      parser,
      args = c(option_tokens, "--", operands),
      positional_arguments = TRUE,
      print_help_and_exit = FALSE
    ),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  )
  limits <- switch(
    command,
    config = c(0, 0),
    cran = c(0, Inf),
    update = c(0, 0),
    install = c(1, Inf),
    download = c(1, Inf),
    uninstall = c(1, Inf),
    validate = c(1, Inf),
    session = c(0, Inf)
  )
  n_args <- length(parsed$args)
  if (n_args < limits[[1L]] || n_args > limits[[2L]]) {
    stop(paste("Invalid number of arguments for", command), call. = FALSE)
  }
  cpus <- parsed$options[["cpus"]]
  supplied_cpus <- any(grepl("^--cpus($|=)", option_tokens))
  if (supplied_cpus && is.null(cpus)) {
    stop("--cpus must be a positive integer.", call. = FALSE)
  }
  if (!is.null(cpus) && (is.na(cpus) || cpus < 1L)) {
    stop("--cpus must be a positive integer.", call. = FALSE)
  }

  args <- as.list(stats::setNames(rep(FALSE, length(commands)), commands))
  args[[command]] <- TRUE
  args[["-v"]] <- isTRUE(parsed$options[["-v"]])
  args[["--quiet"]] <- isTRUE(parsed$options[["--quiet"]])
  args[["--init"]] <- isTRUE(parsed$options[["init"]])
  args[["--list"]] <- isTRUE(parsed$options[["list"]])
  args[["--no-upgrade"]] <- isTRUE(parsed$options[["no-upgrade"]])
  args[["--cpus"]] <- cpus
  args[["--dest-dir"]] <- if (is.null(parsed$options[["dest-dir"]])) {
    "."
  } else {
    parsed$options[["dest-dir"]]
  }
  args[["<url>"]] <- if (command == "cran") parsed$args else character()
  args[["<pkg>"]] <- if (command %in% c(
    "install", "download", "uninstall", "validate", "session"
  )) parsed$args else character()
  list(action = "run", args = args)
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

if (!interactive() && sys.nframe() == 0L) {
  initialized <- initialize_clir()
  parsed <- parse_clir_args()
  if (parsed$action == "help") {
    cat(doc, "\n")
  } else if (parsed$action == "version") {
    cat(clir_version, "\n")
  } else if (parsed$args[["--quiet"]]) {
    suppressMessages(main(args = parsed$args, initialized = initialized))
  } else {
    main(args = parsed$args, initialized = initialized)
  }
}
