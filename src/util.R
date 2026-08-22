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

r_default_user_library <- function(r_version = getRversion()) {
  system_info <- Sys.info()
  home <- normalizePath("~", mustWork = FALSE)
  if (
    identical(.Platform$OS.type, "windows") &&
      identical(system_info[["machine"]], "x86-64")
  ) {
    file.path(
      Sys.getenv("LOCALAPPDATA"),
      "R",
      "win-library",
      r_major_minor(r_version)
    )
  } else if (identical(.Platform$OS.type, "windows")) {
    file.path(
      Sys.getenv("LOCALAPPDATA"),
      "R",
      paste0(system_info[["machine"]], "-library"),
      r_major_minor(r_version)
    )
  } else if (identical(system_info[["sysname"]], "Darwin")) {
    file.path(
      home,
      "Library",
      "R",
      system_info[["machine"]],
      r_major_minor(r_version),
      "library"
    )
  } else {
    file.path(
      home,
      "R",
      paste0(R.version$platform, "-library"),
      r_major_minor(r_version)
    )
  }
}

r_default_site_library <- function() {
  file.path(R.home(), "site-library")
}

expand_r_library_tokens <- function(path, r_version = getRversion()) {
  if (length(path) != 1L || is.na(path)) {
    stop("path must be one non-missing value.")
  }
  version <- as.character(r_version)
  expand <- function(value, spec, expansion) {
    replacement <- sprintf(
      "\\1\\2%s",
      gsub("([\\])", "\\\\\\1", expansion)
    )
    gsub(paste0("(^|[^%])(%%)*%", spec), replacement, value)
  }
  path <- expand(path, "V", version)
  path <- expand(path, "v", r_major_minor(r_version))
  path <- expand(path, "p", R.version$platform)
  path <- expand(path, "a", R.version$arch)
  path <- expand(path, "o", R.version$os)
  path <- expand(path, "U", r_default_user_library(r_version))
  path <- expand(path, "S", r_default_site_library())
  gsub("%%", "%", path, fixed = TRUE)
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

  env_names <- names(env)
  env <- as.character(env)
  if (is.null(env_names)) {
    env_names <- c("R_LIBS", "R_LIBS_USER")[seq_along(env)]
  }
  names(env) <- env_names
  overrides <- env[c("R_LIBS", "R_LIBS_USER")]
  overrides <- overrides[
    !is.na(overrides) & nzchar(overrides) & overrides != "NULL"
  ]
  if (length(overrides) > 0L) {
    # R accepts a path list in these variables. The first entry is the
    # library used by clir, matching .libPaths()[[1]].
    override_name <- names(overrides)[[1L]]
    path <- strsplit(overrides[[1L]], .Platform$path.sep, fixed = TRUE)[[1L]][1L]
    if (identical(override_name, "R_LIBS_USER")) {
      path <- expand_r_library_tokens(path, r_version = r_version)
    }
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

  status <- unlink_fn(
    target,
    recursive = TRUE,
    force = TRUE,
    expand = FALSE
  )
  if (!isTRUE(status == 0L)) {
    stop("Failed to reset the clir library.")
  }
  invisible(TRUE)
}

repo_fallback_names <- function(n, existing = character()) {
  if (n == 0L) {
    return(character())
  }
  existing <- as.character(existing)
  existing <- existing[!is.na(existing) & nzchar(existing)]
  used <- tolower(existing)
  result <- character(n)
  for (index in seq_len(n)) {
    if (index == 1L && !"cran" %in% used) {
      candidate <- "CRAN"
    } else {
      candidate <- "repository1"
      while (tolower(candidate) %in% used) {
        candidate <- paste0(
          "repository",
          as.integer(sub("^repository", "", candidate)) + 1L
        )
      }
    }
    result[[index]] <- candidate
    used <- c(used, tolower(candidate))
  }
  result
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

  if (is.null(repo_names) || length(repo_names) != length(repos)) {
    repo_names <- rep("", length(repos))
  }
  missing_names <- is.na(repo_names) | !nzchar(repo_names)
  if (any(missing_names)) {
    repo_names[missing_names] <- repo_fallback_names(
      sum(missing_names),
      existing = repo_names[!missing_names]
    )
  }
  repo_names[tolower(repo_names) == "cran"] <- "CRAN"
  if (!any(repo_names == "CRAN")) {
    repos <- c(default_config$repos, repos)
    repo_names <- names(repos)
  }
  names(repos) <- repo_names
  repos[!duplicated(tolower(names(repos)))]
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
    existing_names <- names(config$repos)
    existing_names <- existing_names[tolower(existing_names) != "cran"]
    if (is.null(new_names) || length(new_names) != length(new)) {
      new_names <- repo_fallback_names(
        length(new),
        existing = existing_names
      )
    } else {
      missing_names <- is.na(new_names) | !nzchar(new_names)
      if (any(missing_names)) {
        new_names[missing_names] <- repo_fallback_names(
          sum(missing_names),
          existing = c(existing_names, new_names[!missing_names])
        )
      }
      new_names[tolower(new_names) == "cran"] <- "CRAN"
    }
    names(new) <- new_names
    new <- new[!duplicated(tolower(names(new)))]
    repos <- c(new, config$repos)
    config <- list(repos = repos[!duplicated(tolower(names(repos)))])
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

package_ref_name <- function(ref) {
  ref <- as.character(ref)
  ref <- sub("^[^:]+::", "", ref)
  ref <- sub("@[^/@]+$", "", ref)
  ref <- sub("[?#].*$", "", ref)
  ref <- sub("/+$", "", ref)
  ref <- basename(ref)
  sub("\\.git$", "", ref)
}

is_plain_package_ref <- function(ref) {
  grepl("^[A-Za-z][A-Za-z0-9.]*$", ref)
}

standard_installed_refs <- function(status) {
  if (is.null(status) || !is.data.frame(status) || nrow(status) == 0L) {
    return(character())
  }
  packages <- status[["package"]]
  if (is.null(packages)) {
    return(character())
  }
  packages <- as.character(packages)
  remote_refs <- status[["remotepkgref"]]
  use_remote <- if (is.null(remote_refs)) {
    rep(FALSE, length(packages))
  } else {
    remote_refs <- as.character(remote_refs)
    !is.na(remote_refs) & nzchar(remote_refs)
  }
  repotypes <- status[["repotype"]]
  if (is.null(repotypes)) {
    repotypes <- rep(NA_character_, length(packages))
  }
  repotypes <- tolower(as.character(repotypes))
  repositories <- status[["repository"]]
  if (is.null(repositories)) {
    repositories <- rep(NA_character_, length(packages))
  }
  repositories <- as.character(repositories)
  standard <- !use_remote & (
    repotypes %in% c("cran", "standard", "bioc") |
      (!is.na(repositories) & nzchar(repositories))
  )
  if (!any(standard)) {
    return(character())
  }
  refs <- paste0("standard::", packages[standard])
  cran <- standard & repotypes %in% c("cran", "standard") & (
    is.na(repositories) |
      !nzchar(repositories) |
      tolower(repositories) %in% c("cran", "@cran@")
  )
  unique(c(refs, paste0("cran::", packages[cran])))
}

canonical_ref <- function(ref) {
  if (length(ref) != 1L || is.na(ref) || !nzchar(ref)) {
    return(ref)
  }
  if (grepl("^[A-Za-z][A-Za-z0-9.]*=", ref)) {
    return(canonical_ref(sub("^[A-Za-z][A-Za-z0-9.]*=", "", ref)))
  }
  if (grepl("^github::", ref, ignore.case = TRUE)) {
    ref <- sub("^github::", "", ref, ignore.case = TRUE)
    ref <- sub("/+$", "", ref)
    return(paste0("github::", ref))
  }
  if (grepl("^https?://github\\.com/", ref, ignore.case = TRUE)) {
    ref <- sub("^https?://github\\.com/", "", ref, ignore.case = TRUE)
    ref <- sub("/+$", "", ref)
    ref <- sub("/releases/tag/", "@", ref, fixed = TRUE)
    ref <- sub("/(tree|commit)/", "@", ref)
    ref <- sub("/pull/", "#", ref)
    ref <- sub("\\.git$", "", ref)
    ref <- sub("/+$", "", ref)
    return(paste0("github::", ref))
  }
  if (grepl("^git@github\\.com:", ref, ignore.case = TRUE)) {
    ref <- sub("^git@github\\.com:", "", ref, ignore.case = TRUE)
    ref <- sub("\\.git$", "", ref)
    return(paste0("github::", ref))
  }
  if (grepl(
    "^[^/:[:space:]]+/[^/:[:space:]]+(/[^/:[:space:]]+)*(?:[@#].*)?$",
    ref,
    perl = TRUE
  )) {
    return(paste0("github::", ref))
  }
  ref
}

filter_installed_pkgs <- function(pkgs, r_lib, installed_fn,
                                  status_fn = NULL) {
  if (!is.function(installed_fn)) {
    stop("installed_fn must be a function.")
  }
  installed_names <- rownames(installed_fn(lib.loc = r_lib))
  if (length(installed_names) == 0L) {
    return(pkgs)
  }

  installed_refs <- installed_names
  if (!is.null(status_fn)) {
    if (!is.function(status_fn)) {
      stop("status_fn must be a function.")
    }
    status <- status_fn(pkg = installed_names, lib = r_lib)
    installed_refs <- c(
      installed_refs,
      standard_installed_refs(status),
      installed_package_refs(status, fallback = installed_names)
    )
  }
  requested_names <- package_ref_name(pkgs)
  plain_refs <- is_plain_package_ref(pkgs)
  requested_refs <- vapply(pkgs, canonical_ref, character(1))
  installed_refs <- vapply(installed_refs, canonical_ref, character(1))
  keep <- !(
    (plain_refs & requested_names %in% installed_names) |
      requested_refs %in% installed_refs
  )
  pkgs[keep]
}

install_pkgs <- function(pkgs, repos, r_lib = .libPaths()[1L],
                         upgrade = TRUE, depend = NA, quiet = FALSE,
                         pkg_install = NULL, installed_fn = installed.packages,
                         status_fn = NULL) {
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

  if (!upgrade) {
    if (is.null(status_fn) && requireNamespace("pak", quietly = TRUE)) {
      status_fn <- pak::pkg_status
    }
    pkgs <- filter_installed_pkgs(
      pkgs = pkgs,
      r_lib = r_lib,
      installed_fn = installed_fn,
      status_fn = status_fn
    )
    if (length(pkgs) == 0L) {
      message("All requested packages are already installed.")
      return(invisible(NULL))
    }
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

status_package_refs <- function(status) {
  if (is.null(status) || !is.data.frame(status) || nrow(status) == 0L) {
    return(character())
  }
  packages <- status[["package"]]
  if (is.null(packages)) {
    return(character())
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
  if (is.null(repotypes)) {
    repotypes <- rep(NA_character_, length(refs))
  }
  repotypes <- tolower(as.character(repotypes))
  repositories <- status[["repository"]]
  if (is.null(repositories)) {
    repositories <- rep(NA_character_, length(refs))
  }
  repositories <- as.character(repositories)
  cran <- !use_remote &
    (
      repotypes %in% c("cran", "standard") |
        (!is.na(repositories) &
          tolower(repositories) %in% c("cran", "@cran@"))
    ) &
    (
      is.na(repositories) |
        !nzchar(repositories) |
        tolower(repositories) %in% c("cran", "@cran@")
    )
  refs[cran] <- paste0("cran::", packages[cran])
  bioc <- !is.na(repotypes) & repotypes == "bioc"
  refs[bioc & !use_remote] <- paste0(
    "bioc::",
    packages[bioc & !use_remote]
  )
  refs
}

installed_package_refs <- function(status, fallback = character()) {
  refs <- status_package_refs(status)
  refs <- refs[!is.na(refs) & nzchar(refs)]
  if (length(refs) == 0L) fallback else refs
}

repository_identity <- function(value) {
  value <- trimws(as.character(value))
  sub("/+$", "", value)
}

merge_update_repos <- function(repos, status) {
  if (is.null(status) || !is.data.frame(status) || nrow(status) == 0L) {
    return(repos)
  }
  repositories <- status[["repository"]]
  if (is.null(repositories)) {
    return(repos)
  }
  repositories <- as.character(repositories)
  packages <- status[["package"]]
  if (is.null(packages)) {
    return(repos)
  }
  remote_refs <- status[["remotepkgref"]]
  use_remote <- if (is.null(remote_refs)) {
    rep(FALSE, length(repositories))
  } else {
    remote_refs <- as.character(remote_refs)
    !is.na(remote_refs) & nzchar(remote_refs)
  }
  repotypes <- status[["repotype"]]
  if (is.null(repotypes)) {
    repotypes <- rep(NA_character_, length(repositories))
  }
  repotypes <- tolower(as.character(repotypes))
  standard <- !use_remote & (
    repotypes %in% c("cran", "standard") | is.na(repotypes)
  )
  sources <- repositories[
    standard & !is.na(repositories) & nzchar(repositories) &
      !tolower(repositories) %in% c("cran", "@cran@")
  ]
  sources <- unique(sources)
  if (length(sources) == 0L) {
    return(repos)
  }

  repo_names <- names(repos)
  repos <- as.character(repos)
  if (is.null(repo_names) || length(repo_names) != length(repos)) {
    repo_names <- repo_fallback_names(length(repos))
  }
  for (source in sources) {
    source_key <- repository_identity(source)
    source_is_url <- grepl(
      "^(?:[[:alnum:]][[:alnum:].+-]*://|git@)",
      source,
      perl = TRUE
    )
    name_matches <- if (source_is_url) {
      !is.na(repo_names) & repository_identity(repo_names) == source_key
    } else {
      !is.na(repo_names) &
        tolower(trimws(repo_names)) == tolower(trimws(source))
    }
    value_matches <- !is.na(repos) &
      repository_identity(repos) == source_key
    matches <- which(
      name_matches | value_matches
    )
    if (length(matches) == 0L) {
      next
    }
    order <- c(matches, setdiff(seq_along(repos), matches))
    repos <- repos[order]
    repo_names <- repo_names[order]
  }
  names(repos) <- repo_names
  repos
}

status_repo_groups <- function(status, refs) {
  valid <- !is.na(refs) & nzchar(refs)
  indices <- which(valid)
  if (length(indices) == 0L) {
    return(list())
  }
  repositories <- status[["repository"]]
  if (is.null(repositories)) {
    return(list(indices))
  }
  repositories <- as.character(repositories)
  remote_refs <- status[["remotepkgref"]]
  use_remote <- if (is.null(remote_refs)) {
    rep(FALSE, length(refs))
  } else {
    remote_refs <- as.character(remote_refs)
    !is.na(remote_refs) & nzchar(remote_refs)
  }
  repotypes <- status[["repotype"]]
  if (is.null(repotypes)) {
    repotypes <- rep(NA_character_, length(refs))
  }
  repotypes <- tolower(as.character(repotypes))
  standard <- !use_remote & (
    repotypes %in% c("cran", "standard") | is.na(repotypes)
  )
  custom <- standard & !is.na(repositories) & nzchar(repositories) &
    !tolower(repositories) %in% c("cran", "@cran@")
  keys <- rep("", length(refs))
  keys[custom] <- repository_identity(repositories[custom])
  split(indices, keys[indices], drop = TRUE)
}

update_pkgs <- function(repos, r_lib = .libPaths()[1L],
                        depend = NA, quiet = FALSE,
                        pkg_install = NULL, installed_pkgs = NULL,
                        status_fn = NULL, installed_fn = installed.packages) {
  status <- NULL
  status_refs <- NULL
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
      status <- status_fn(pkg = installed_names, lib = r_lib)
      status_refs <- status_package_refs(status)
      installed_pkgs <- installed_package_refs(
        status,
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
  if (!is.null(status) && !is.null(status_refs)) {
    valid <- !is.na(status_refs) & nzchar(status_refs)
    if (identical(status_refs[valid], installed_pkgs)) {
      groups <- status_repo_groups(status, status_refs)
      if (length(groups) > 0L) {
        results <- lapply(groups, function(indices) {
          install_pkgs(
            pkgs = status_refs[indices],
            repos = merge_update_repos(
              repos,
              status[indices, , drop = FALSE]
            ),
            r_lib = r_lib,
            upgrade = TRUE,
            depend = depend,
            quiet = quiet,
            pkg_install = pkg_install
          )
        })
        return(invisible(results))
      }
    }
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
