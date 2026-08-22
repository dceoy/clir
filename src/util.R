#!/usr/bin/env Rscript

default_config <- list(
  repos = c(CRAN = "https://cran.rstudio.com/")
)

r_major_minor <- function(r_version = getRversion()) {
  parts <- strsplit(as.character(r_version), ".", fixed = TRUE)[[1L]]
  if (length(parts) < 2L) {
    stop("An R version with a major and minor component is required.")
  }
  paste(parts[seq_len(2L)], collapse = ".")
}

default_r_library <- function(clir_root_dir, r_version = getRversion()) {
  root <- normalizePath(path.expand(clir_root_dir), mustWork = FALSE)
  file.path(root, "r", r_major_minor(r_version), "library")
}

expand_r_library_tokens <- function(path, r_version = getRversion()) {
  version <- as.character(r_version)
  gsub(
    "%V", version,
    gsub("%v", r_major_minor(r_version), path, fixed = TRUE),
    fixed = TRUE
  )
}

resolve_r_library <- function(clir_root_dir, r_version = getRversion(),
                              r_lib = NULL,
                              env = Sys.getenv(c("R_LIBS", "R_LIBS_USER"))) {
  if (!is.null(r_lib)) {
    if (length(r_lib) != 1L || !nzchar(r_lib)) {
      stop("r_lib must be one non-empty path.")
    }
    return(normalizePath(path.expand(r_lib), mustWork = FALSE))
  }

  env <- as.character(env)
  if (is.null(names(env))) {
    names(env) <- c("R_LIBS", "R_LIBS_USER")[seq_along(env)]
  }
  overrides <- env[c("R_LIBS", "R_LIBS_USER")]
  overrides <- overrides[
    !is.na(overrides) & nzchar(overrides) & overrides != "NULL"
  ]
  if (length(overrides) > 0L) {
    # R accepts a path list in these variables. The first entry is the
    # library used by clir, matching .libPaths()[[1]].
    path <- strsplit(overrides[[1L]], .Platform$path.sep, fixed = TRUE)[[1L]][1L]
    path <- expand_r_library_tokens(path, r_version = r_version)
    return(normalizePath(path.expand(path), mustWork = FALSE))
  }

  default_r_library(clir_root_dir = clir_root_dir, r_version = r_version)
}

make_clir_dirs <- function(clir_root_dir, r_lib = NULL,
                           r_version = getRversion(), exist_ok = TRUE) {
  root <- normalizePath(path.expand(clir_root_dir), mustWork = FALSE)
  if (is.null(r_lib)) {
    r_lib <- default_r_library(root, r_version = r_version)
  }
  paths <- unique(c(file.path(root, "r"), normalizePath(
    path.expand(r_lib), mustWork = FALSE
  )))
  for (path in paths) {
    dir.create(
      path,
      recursive = TRUE,
      showWarnings = !exist_ok
    )
  }
  invisible(paths)
}

path_is_within <- function(path, root) {
  path <- normalizePath(path, mustWork = FALSE)
  root <- normalizePath(root, mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, .Platform$file.sep))
}

is_symlink_path <- function(path) {
  link <- Sys.readlink(path)
  length(link) == 1L && !is.na(link) && nzchar(link)
}

path_components <- function(path) {
  path <- path.expand(path)
  if (!grepl("^/", path)) {
    path <- file.path(getwd(), path)
  }
  parts <- strsplit(path, .Platform$file.sep, fixed = TRUE)[[1L]]
  current <- if (startsWith(path, .Platform$file.sep)) {
    .Platform$file.sep
  } else {
    ""
  }
  components <- character()
  for (part in parts) {
    if (!nzchar(part) || identical(part, ".")) {
      next
    }
    current <- if (identical(current, .Platform$file.sep)) {
      paste0(current, part)
    } else if (nzchar(current)) {
      file.path(current, part)
    } else {
      part
    }
    components <- c(components, current)
  }
  components
}

reset_clir_library <- function(target, clir_root_dir,
                               r_version = getRversion(),
                               unlink_fn = unlink) {
  if (!is.function(unlink_fn)) {
    stop("unlink_fn must be a function.")
  }
  root <- normalizePath(path.expand(clir_root_dir), mustWork = FALSE)
  target_input <- path.expand(target)
  expected_input <- default_r_library(root, r_version = r_version)
  raw_components <- unique(c(
    path_components(expected_input),
    path_components(target_input)
  ))
  if (any(vapply(raw_components, is_symlink_path, logical(1)))) {
    stop("Refusing to reset a symlinked clir library path.")
  }

  target <- normalizePath(target_input, mustWork = FALSE)
  expected <- normalizePath(expected_input, mustWork = FALSE)
  managed_root <- normalizePath(file.path(root, "r"), mustWork = FALSE)

  if (!identical(target, expected)) {
    stop("Refusing to reset a library outside the current clir library path.")
  }
  if (!path_is_within(target, managed_root) || identical(target, managed_root)) {
    stop("Refusing to reset a path outside the clir-managed library root.")
  }

  if (file.exists(target) && !dir.exists(target)) {
    stop("Refusing to reset a non-directory clir library path.")
  }

  status <- unlink_fn(target, recursive = TRUE, force = TRUE)
  if (!isTRUE(status == 0L)) {
    stop("Failed to reset the clir library.")
  }
  invisible(TRUE)
}

normalize_repos <- function(config) {
  if (is.null(config) || !is.list(config)) {
    config <- list()
  }
  repos <- config[["repos"]]
  if (is.null(repos)) {
    # Read the pre-pak configuration format so an upgrade does not silently
    # discard a user's CRAN mirror.
    repos <- config[["cran_urls"]]
  }
  if (is.null(repos)) {
    repos <- default_config$repos
  }
  if (is.list(repos)) {
    repos <- unlist(repos, use.names = TRUE)
  }
  repo_names <- names(repos)
  repos <- as.character(repos)
  valid <- !is.na(repos) & nzchar(repos)
  repos <- repos[valid]
  if (!is.null(repo_names)) {
    repo_names <- repo_names[valid]
  }
  if (length(repos) == 0L) {
    repos <- default_config$repos
    repo_names <- names(repos)
  }

  if (is.null(repo_names)) {
    repo_names <- rep("", length(repos))
  }
  missing_names <- is.na(repo_names) | !nzchar(repo_names)
  if (any(missing_names)) {
    replacements <- c("CRAN", paste0("repository", seq_len(max(0L, length(repos) - 1L))))
    repo_names[missing_names] <- replacements[seq_len(sum(missing_names))]
  }
  repo_names[tolower(repo_names) == "cran"] <- "CRAN"
  if (!any(repo_names == "CRAN")) {
    repos <- c(default_config$repos, repos)
    repo_names <- names(repos)
  }
  names(repos) <- repo_names
  repos[!duplicated(names(repos))]
}

normalize_config <- function(config) {
  list(repos = as.list(normalize_repos(config)))
}

read_config <- function(clir_yml) {
  if (file.exists(clir_yml)) {
    yaml::read_yaml(clir_yml)
  } else {
    default_config
  }
}

write_config <- function(config, clir_yml) {
  dir.create(dirname(clir_yml), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(normalize_config(config), file = clir_yml)
}

load_repos <- function(clir_yml, quiet = FALSE) {
  normalize_repos(read_config(clir_yml))
}

print_config <- function(clir_yml, r_lib = NULL, init = FALSE) {
  if (init) {
    config <- normalize_config(default_config)
    write_config(config, clir_yml)
    message(paste("Initialized:", clir_yml))
  } else {
    config <- normalize_config(read_config(clir_yml))
  }
  if (is.null(r_lib)) {
    r_lib <- .libPaths()[1L]
  }
  print(list(clir = config, libpath = r_lib, r = version))
}

add_config <- function(new, key, clir_yml) {
  new_names <- names(new)
  new <- as.character(new)
  valid <- !is.na(new) & nzchar(new)
  new <- new[valid]
  if (!is.null(new_names)) {
    new_names <- new_names[valid]
  }
  if (length(new) == 0L) {
    stop("At least one configuration value must be passed.")
  }

  config <- normalize_config(read_config(clir_yml))
  if (key %in% c("repos", "cran_urls")) {
    if (is.null(new_names)) {
      new_names <- rep("CRAN", length(new))
    } else {
      new_names[is.na(new_names) | !nzchar(new_names)] <- "CRAN"
      new_names[tolower(new_names) == "cran"] <- "CRAN"
    }
    names(new) <- new_names
    new <- new[!duplicated(names(new))]
    repos <- c(new, config$repos)
    config <- list(repos = repos[!duplicated(names(repos))])
  } else {
    old <- read_config(clir_yml)[[key]]
    config[[key]] <- unique(c(new, as.character(old)))
  }
  write_config(config, clir_yml)
  message(paste("Updated:", clir_yml))
  invisible(config)
}

print_cran_mirrors <- function(https = TRUE) {
  d <- data.frame(getCRANmirrors())
  if (https) {
    print(subset(d, grepl("^https://", d$URL))[, c("Name", "URL")])
  } else {
    print(d[, c("Name", "URL")])
  }
}

install_pkgs <- function(pkgs, repos, r_lib = .libPaths()[1L],
                         upgrade = TRUE, depend = NA, quiet = FALSE,
                         pkg_install = NULL) {
  if (length(pkgs) == 0L) {
    stop("At least one package reference must be passed.")
  }
  if (is.null(pkg_install)) {
    if (!requireNamespace("pak", quietly = TRUE)) {
      stop("The pak package is required for installation.")
    }
    pkg_install <- pak::pkg_install
  }
  if (!is.function(pkg_install)) {
    stop("pkg_install must be a function.")
  }

  options(repos = repos)
  install <- function() {
    pkg_install(
      pkg = pkgs,
      lib = r_lib,
      upgrade = upgrade,
      ask = FALSE,
      dependencies = depend
    )
  }
  result <- if (quiet) suppressMessages(install()) else install()
  invisible(result)
}

installed_package_refs <- function(status, fallback = character()) {
  if (is.null(status) || !is.data.frame(status) || nrow(status) == 0L) {
    return(fallback)
  }
  packages <- status[["package"]]
  if (is.null(packages)) {
    return(fallback)
  }
  packages <- as.character(packages)
  refs <- packages
  remote_refs <- status[["remotepkgref"]]
  if (!is.null(remote_refs)) {
    remote_refs <- as.character(remote_refs)
    use_remote <- !is.na(remote_refs) & nzchar(remote_refs)
    refs[use_remote] <- remote_refs[use_remote]
  } else {
    use_remote <- rep(FALSE, length(refs))
  }
  repotypes <- status[["repotype"]]
  if (!is.null(repotypes)) {
    bioc <- !is.na(repotypes) & tolower(as.character(repotypes)) == "bioc"
    refs[bioc & !use_remote] <- paste0("bioc::", packages[bioc & !use_remote])
  }
  refs <- refs[!is.na(refs) & nzchar(refs)]
  if (length(refs) == 0L) fallback else refs
}

update_pkgs <- function(repos, r_lib = .libPaths()[1L],
                        depend = NA, quiet = FALSE,
                        pkg_install = NULL, installed_pkgs = NULL,
                        status_fn = NULL, installed_fn = installed.packages) {
  if (is.null(installed_pkgs)) {
    if (!is.function(installed_fn)) {
      stop("installed_fn must be a function.")
    }
    installed_names <- rownames(installed_fn(lib.loc = r_lib))
    if (length(installed_names) > 0L) {
      if (is.null(status_fn)) {
        if (!requireNamespace("pak", quietly = TRUE)) {
          stop("The pak package is required for package status.")
        }
        status_fn <- pak::pkg_status
      }
      if (!is.function(status_fn)) {
        stop("status_fn must be a function.")
      }
      installed_pkgs <- installed_package_refs(
        status_fn(pkg = installed_names, lib = r_lib),
        fallback = installed_names
      )
    } else {
      installed_pkgs <- installed_names
    }
  }
  if (length(installed_pkgs) == 0L) {
    message("No packages are installed in the clir library.")
    return(invisible(NULL))
  }
  install_pkgs(
    pkgs = installed_pkgs,
    repos = repos,
    r_lib = r_lib,
    upgrade = TRUE,
    depend = depend,
    quiet = quiet,
    pkg_install = pkg_install
  )
}

validate_loading <- function(pkgs, quiet = FALSE) {
  result <- vapply(
    as.character(pkgs),
    require,
    logical(1),
    character.only = TRUE,
    quietly = quiet
  )
  names(result) <- as.character(pkgs)
  result <- list(succeeded = names(result)[result], failed = names(result)[!result])
  if (!quiet) {
    cat("\n- Loading test ", paste(rep("-", 63L), collapse = ""), "\n", sep = "")
    if (length(result$succeeded) > 0L) {
      cat(" Succeeded:\n  - ", paste(result$succeeded, collapse = "\n  - "), "\n", sep = "")
    }
    if (length(result$failed) > 0L) {
      cat(" Failed:\n  - ", paste(result$failed, collapse = "\n  - "), "\n", sep = "")
    }
    cat("\n")
    if (length(result$failed) == 0L) {
      message("Loading succeeded.")
    }
  }
  if (length(result$failed) > 0L) {
    stop("Loading failed.")
  }
  invisible(result)
}

print_sessions <- function(pkgs) {
  pkgs <- as.character(pkgs)
  if (length(pkgs) > 0L) {
    loaded <- vapply(
      pkgs,
      require,
      logical(1),
      character.only = TRUE,
      quietly = FALSE
    )
    if (any(!loaded)) {
      stop("Loading failed.")
    }
  }
  print(utils::sessionInfo())
}
