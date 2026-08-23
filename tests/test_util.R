#!/usr/bin/env Rscript

local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  script_dir <- if (length(file_arg) == 1L) {
    dirname(normalizePath(sub("^--file=", "", file_arg)))
  } else {
    getwd()
  }
  repo_root <- normalizePath(file.path(script_dir, ".."))
  source(file.path(repo_root, "src", "util.R"))

  expect_error <- function(expr) {
    raised <- FALSE
    tryCatch(
      force(expr),
      error = function(error) raised <<- TRUE
    )
    if (!raised) {
      stop("Expected an error.")
    }
  }

  root <- tempfile("clir-util-tests-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  versioned <- default_r_library(root, r_version = "4.3.2")
  stopifnot(grepl("r/4.3/library$", versioned))
  make_clir_dirs(root, r_version = "4.3.2")
  stopifnot(dir.exists(versioned))
  stopifnot(!dir.exists(file.path(root, "r", "library")))

  explicit <- file.path(root, "explicit-library")
  stopifnot(identical(
    resolve_r_library(
      root,
      r_version = "4.3.2",
      env = c(R_LIBS_USER = explicit, R_LIBS = "")
    ),
    normalizePath(explicit, mustWork = FALSE)
  ))
  token_cases <- list(
    version = list(
      path = file.path(root, "library-%v-%V"),
      expected = file.path(root, "library-4.3-4.3.2")
    ),
    runtime = list(
      path = file.path(root, "library-%p-%o-%a-%%"),
      expected = file.path(
        root,
        paste(
          "library",
          R.version$platform,
          R.version$os,
          R.version$arch,
          "%",
          sep = "-"
        )
      )
    )
  )
  for (case_name in names(token_cases)) {
    token_case <- token_cases[[case_name]]
    stopifnot(identical(
      resolve_r_library(
        root,
        r_version = "4.3.2",
        env = c(R_LIBS_USER = token_case$path, R_LIBS = "")
      ),
      normalizePath(token_case$expected, mustWork = FALSE)
    ))
  }
  stopifnot(identical(
    expand_r_library_tokens("%U|%S", r_version = "4.3.2"),
    paste(
      r_default_user_library("4.3.2"),
      r_default_site_library(),
      sep = "|"
    )
  ))
  r_lib_token <- file.path(root, "r-library-%v")
  stopifnot(identical(
    resolve_r_library(
      root,
      r_version = "4.3.2",
      env = c(R_LIBS_USER = "NULL", R_LIBS = r_lib_token)
    ),
    normalizePath(r_lib_token, mustWork = FALSE)
  ))
  explicit_r_lib <- file.path(root, "explicit-r-library")
  stopifnot(identical(
    resolve_r_library(
      root,
      r_version = "4.3.2",
      env = c(R_LIBS_USER = "NULL", R_LIBS = explicit_r_lib)
    ),
    normalizePath(explicit_r_lib, mustWork = FALSE)
  ))
  dual_r_lib <- file.path(root, "dual-r-library")
  dual_user_lib <- file.path(root, "dual-user-library")
  stopifnot(identical(
    resolve_r_library(
      root,
      r_version = "4.3.2",
      env = c(
        R_LIBS_USER = dual_user_lib,
        R_LIBS = paste(
          dual_r_lib,
          file.path(root, "secondary-r-library"),
          sep = .Platform$path.sep
        )
      )
    ),
    normalizePath(dual_r_lib, mustWork = FALSE)
  ))

  first_config <- file.path(root, "first.yml")
  requested_repo <- "https://example.invalid/cran"
  add_config(requested_repo, key = "cran_urls", clir_yml = first_config)
  stopifnot(identical(load_repos(first_config)[["CRAN"]], requested_repo))
  first_yaml <- yaml::read_yaml(first_config)
  stopifnot(identical(first_yaml[["repos"]][["CRAN"]], requested_repo))
  named_config <- file.path(root, "named.yml")
  add_config(
    c(CRAN = requested_repo, INTERNAL = "https://example.invalid/internal"),
    key = "repos",
    clir_yml = named_config
  )
  stopifnot(identical(
    load_repos(named_config)[["INTERNAL"]],
    "https://example.invalid/internal"
  ))
  multiple_config <- file.path(root, "multiple.yml")
  multiple_repos <- c(
    "https://example.invalid/first",
    "https://example.invalid/second"
  )
  add_config(multiple_repos, key = "repos", clir_yml = multiple_config)
  stopifnot(identical(
    load_repos(multiple_config),
    c(CRAN = multiple_repos[[1L]], repository1 = multiple_repos[[2L]])
  ))
  mixed_repos <- c(
    CRAN = requested_repo,
    "https://example.invalid/mixed"
  )
  stopifnot(identical(
    normalize_repos(list(repos = mixed_repos)),
    c(
      CRAN = requested_repo,
      repository1 = "https://example.invalid/mixed"
    )
  ))
  lowercase_mixed_repos <- c(
    cran = requested_repo,
    "https://example.invalid/lowercase-mixed"
  )
  stopifnot(identical(
    normalize_repos(list(repos = lowercase_mixed_repos)),
    c(
      CRAN = requested_repo,
      repository1 = "https://example.invalid/lowercase-mixed"
    )
  ))
  mixed_config <- file.path(root, "mixed.yml")
  add_config(mixed_repos, key = "repos", clir_yml = mixed_config)
  stopifnot(identical(
    load_repos(mixed_config),
    c(
      CRAN = requested_repo,
      repository1 = "https://example.invalid/mixed"
    )
  ))
  collision_config <- file.path(root, "collision.yml")
  yaml::write_yaml(
    list(repos = list(
      CRAN = requested_repo,
      repository1 = "https://example.invalid/existing"
    )),
    collision_config
  )
  add_config(
    c(
      "https://example.invalid/new-cran",
      "https://example.invalid/new-internal"
    ),
    key = "repos",
    clir_yml = collision_config
  )
  stopifnot(identical(
    load_repos(collision_config),
    c(
      CRAN = "https://example.invalid/new-cran",
      repository2 = "https://example.invalid/new-internal",
      repository1 = "https://example.invalid/existing"
    )
  ))

  generic_config <- file.path(root, "generic.yml")
  yaml::write_yaml(
    list(repos = list(
      CRAN = "https://example.invalid/cran",
      INTERNAL = "https://example.invalid/internal"
    )),
    generic_config
  )
  generic_repos <- load_repos(generic_config)
  stopifnot(identical(generic_repos[["CRAN"]], "https://example.invalid/cran"))
  stopifnot(identical(generic_repos[["INTERNAL"]], "https://example.invalid/internal"))

  legacy_config <- file.path(root, "legacy.yml")
  yaml::write_yaml(list(cran_urls = "https://example.invalid/legacy"), legacy_config)
  stopifnot(identical(load_repos(legacy_config)[["CRAN"]], "https://example.invalid/legacy"))

  captured <- NULL
  captured_calls <- list()
  fake_pkg_install <- function(...) {
    captured <<- c(list(repos = getOption("repos")), list(...))
    captured_calls <<- c(captured_calls, list(captured))
    invisible(NULL)
  }
  refs <- c(
    "cran::alpha",
    "owner/repository",
    "git::https://example.invalid/repository.git",
    "bioc::beta"
  )
  install_pkgs(
    refs,
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    upgrade = FALSE,
    pkg_install = fake_pkg_install
  )
  stopifnot(identical(captured$pkg, refs))
  stopifnot(identical(captured$lib, explicit))
  stopifnot(identical(captured$upgrade, FALSE))
  stopifnot(identical(captured$dependencies, NA))
  stopifnot(identical(captured$ask, FALSE))

  no_upgrade_inventory <- function(...) {
    structure(
      matrix(nrow = 2L, ncol = 0L),
      dimnames = list(c("alpha", "beta"), NULL)
    )
  }
  install_pkgs(
    c("alpha", "gamma"),
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    upgrade = FALSE,
    pkg_install = fake_pkg_install,
    installed_fn = no_upgrade_inventory,
    status_fn = function(...) NULL
  )
  stopifnot(identical(captured$pkg, "gamma"))
  stopifnot(identical(captured$upgrade, FALSE))

  reference_cases <- list(
    qualified = "cran::alpha",
    versioned = "alpha@1.0",
    remote = "owner/alpha@main",
    reinstall = "alpha=?reinstall",
    archive = "url::https://example.invalid/alpha.tar.gz"
  )
  for (case_name in names(reference_cases)) {
    reference <- reference_cases[[case_name]]
    install_pkgs(
      reference,
      repos = c(CRAN = requested_repo),
      r_lib = explicit,
      upgrade = FALSE,
      pkg_install = fake_pkg_install,
      installed_fn = no_upgrade_inventory,
      status_fn = function(...) {
        data.frame(
          package = "alpha",
          remotepkgref = "github::owner/alpha",
          repotype = "github",
          stringsAsFactors = FALSE
        )
      }
    )
    stopifnot(identical(captured$pkg, reference))
    stopifnot(identical(captured$upgrade, FALSE))
  }

  standard_reference_cases <- list(
    cran = list(reference = "cran::alpha", expected = character()),
    standard = list(reference = "standard::alpha", expected = character()),
    versioned = list(
      reference = "cran::alpha@1.0",
      expected = "cran::alpha@1.0"
    ),
    reinstall = list(
      reference = "standard::alpha=?reinstall",
      expected = "standard::alpha=?reinstall"
    )
  )
  ordinary_cran_status <- function(...) {
    data.frame(
      package = "alpha",
      remotepkgref = NA_character_,
      repotype = "cran",
      repository = "CRAN",
      stringsAsFactors = FALSE
    )
  }
  for (case_name in names(standard_reference_cases)) {
    reference_case <- standard_reference_cases[[case_name]]
    filtered <- filter_installed_pkgs(
      pkgs = reference_case$reference,
      r_lib = explicit,
      installed_fn = no_upgrade_inventory,
      status_fn = ordinary_cran_status
    )
    stopifnot(identical(unname(filtered), reference_case$expected))
  }
  standard_source_cases <- list(
    custom = list(
      reference = "standard::alpha",
      expected = character(),
      status = data.frame(
        package = "alpha",
        remotepkgref = NA_character_,
        repotype = NA_character_,
        repository = "https://example.invalid/internal",
        stringsAsFactors = FALSE
      )
    ),
    bioc = list(
      reference = "standard::alpha",
      expected = character(),
      status = data.frame(
        package = "alpha",
        remotepkgref = NA_character_,
        repotype = "bioc",
        repository = "Bioconductor",
        stringsAsFactors = FALSE
      )
    )
  )
  for (case_name in names(standard_source_cases)) {
    reference_case <- standard_source_cases[[case_name]]
    filtered <- filter_installed_pkgs(
      pkgs = reference_case$reference,
      r_lib = explicit,
      installed_fn = no_upgrade_inventory,
      status_fn = function(...) reference_case$status
    )
    stopifnot(identical(unname(filtered), reference_case$expected))
  }

  github_reference_cases <- list(
    shorthand = list(
      reference = "owner/alpha",
      installed = "github::owner/alpha",
      expected = character()
    ),
    url = list(
      reference = "https://github.com/owner/alpha",
      installed = "github::owner/alpha",
      expected = character()
    ),
    prefixed_url = list(
      reference = "https://github.com/owner/alpha",
      installed = "github::https://github.com/owner/alpha",
      expected = character()
    ),
    trailing_url = list(
      reference = "https://github.com/owner/alpha/",
      installed = "github::owner/alpha",
      expected = character()
    ),
    release_url = list(
      reference = "https://github.com/owner/alpha/releases/tag/v1.0",
      installed = "github::owner/alpha@v1.0",
      expected = character()
    ),
    versioned = list(
      reference = "owner/alpha@main",
      installed = "github::owner/alpha@main",
      expected = character()
    ),
    git = list(
      reference = "git::https://github.com/owner/alpha",
      installed = "github::owner/alpha",
      expected = "git::https://github.com/owner/alpha"
    ),
    named = list(
      reference = "mypkg=github::owner/alpha",
      installed = "github::owner/alpha",
      expected = character()
    ),
    named_git = list(
      reference = "mypkg=git::https://example.invalid/alpha.git",
      installed = "git::https://example.invalid/alpha.git",
      expected = character()
    ),
    named_reinstall = list(
      reference = "mypkg=github::owner/alpha?reinstall",
      installed = "github::owner/alpha",
      expected = "mypkg=github::owner/alpha?reinstall"
    )
  )
  for (case_name in names(github_reference_cases)) {
    reference_case <- github_reference_cases[[case_name]]
    filtered <- filter_installed_pkgs(
      pkgs = reference_case$reference,
      r_lib = explicit,
      installed_fn = no_upgrade_inventory,
      status_fn = function(...) {
        data.frame(
          package = "alpha",
          remotepkgref = reference_case$installed,
          repotype = "github",
          stringsAsFactors = FALSE
        )
      }
    )
    stopifnot(identical(unname(filtered), reference_case$expected))
  }

  update_pkgs(
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    installed_pkgs = c("alpha", "beta")
  )
  stopifnot(identical(captured$pkg, c("alpha", "beta")))
  stopifnot(identical(captured$upgrade, TRUE))

  fake_installed <- function(...) {
    structure(
      matrix(nrow = 4L, ncol = 0L),
      dimnames = list(c("alpha", "beta", "gamma", "delta"), NULL)
    )
  }
  custom_repo <- "https://example.invalid/internal"
  fake_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = c(
        NA,
        "github::owner/beta",
        "git::https://example.invalid/gamma.git",
        NA
      ),
      repotype = c("cran", NA, NA, "bioc"),
      repository = c("CRAN", NA, NA, NA),
      stringsAsFactors = FALSE
    )
  }
  update_pkgs(
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = fake_status,
    installed_fn = fake_installed
  )
  stopifnot(identical(
    captured$pkg,
    c(
      "cran::alpha",
      "github::owner/beta",
      "git::https://example.invalid/gamma.git",
      "bioc::delta"
    )
  ))
  stopifnot(identical(
    captured$repos,
    c(CRAN = requested_repo)
  ))
  stopifnot(!identical(
    repository_identity("https://example.invalid/Stable/"),
    repository_identity("https://example.invalid/stable")
  ))
  stopifnot(identical(captured$upgrade, TRUE))

  custom_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = rep(NA_character_, length(pkg)),
      repotype = rep(NA_character_, length(pkg)),
      repository = rep(custom_repo, length(pkg)),
      stringsAsFactors = FALSE
    )
  }
  custom_installed <- function(...) {
    structure(
      matrix(nrow = 1L, ncol = 0L),
      dimnames = list("alpha", NULL)
    )
  }
  standard_remote_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = pkg,
      remotetype = rep("standard", length(pkg)),
      repotype = rep("cran", length(pkg)),
      repository = rep("CRAN", length(pkg)),
      remoterepos = rep(custom_repo, length(pkg)),
      stringsAsFactors = FALSE
    )
  }
  filtered <- filter_installed_pkgs(
    pkgs = c("cran::alpha", "standard::alpha"),
    r_lib = explicit,
    installed_fn = custom_installed,
    status_fn = standard_remote_status
  )
  stopifnot(identical(unname(filtered), character()))
  captured_calls <- list()
  update_pkgs(
    repos = c(CRAN = requested_repo, INTERNAL = custom_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = standard_remote_status,
    installed_fn = custom_installed
  )
  stopifnot(identical(captured$pkg, "alpha"))
  stopifnot(identical(
    captured$repos,
    c(INTERNAL = custom_repo, CRAN = requested_repo)
  ))

  captured_calls <- list()
  update_pkgs(
    repos = c(CRAN = requested_repo, INTERNAL = custom_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = custom_status,
    installed_fn = custom_installed
  )
  stopifnot(identical(
    captured$repos,
    c(INTERNAL = custom_repo, CRAN = requested_repo)
  ))

  captured_calls <- list()
  update_pkgs(
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = custom_status,
    installed_fn = custom_installed
  )
  stopifnot(identical(captured$repos, c(CRAN = requested_repo)))

  custom_metadata_cases <- data.frame(
    metadata = c("remoterepos", "RemoteRepos", "remoterepos", "RemoteRepos"),
    repository = c(NA_character_, NA_character_, "CRAN", "@CRAN@"),
    stringsAsFactors = FALSE
  )
  for (case_index in seq_len(nrow(custom_metadata_cases))) {
    metadata_name <- custom_metadata_cases$metadata[[case_index]]
    repository_name <- custom_metadata_cases$repository[[case_index]]
    custom_metadata_status <- function(pkg, lib) {
      result <- data.frame(
        package = pkg,
        remotepkgref = rep(NA_character_, length(pkg)),
        repotype = rep(NA_character_, length(pkg)),
        repository = rep(repository_name, length(pkg)),
        stringsAsFactors = FALSE
      )
      result[[metadata_name]] <- rep(custom_repo, length(pkg))
      result
    }
    captured_calls <- list()
    update_pkgs(
      repos = c(CRAN = requested_repo, INTERNAL = custom_repo),
      r_lib = explicit,
      pkg_install = fake_pkg_install,
      status_fn = custom_metadata_status,
      installed_fn = custom_installed
    )
    stopifnot(identical(
      captured$repos,
      c(INTERNAL = custom_repo, CRAN = requested_repo)
    ))
    stopifnot(identical(captured$pkg, "alpha"))
  }

  unsafe_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = rep(NA_character_, length(pkg)),
      repotype = rep(NA_character_, length(pkg)),
      repository = rep("file:///tmp/untrusted", length(pkg)),
      stringsAsFactors = FALSE
    )
  }
  update_pkgs(
    repos = c(CRAN = requested_repo),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = unsafe_status,
    installed_fn = fake_installed
  )
  stopifnot(identical(captured$repos, c(CRAN = requested_repo)))

  repo_a <- "https://example.invalid/a"
  repo_b <- "https://example.invalid/b"
  two_repo_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = rep(NA_character_, length(pkg)),
      repotype = rep(NA_character_, length(pkg)),
      repository = c(repo_a, repo_b),
      stringsAsFactors = FALSE
    )
  }
  two_repo_installed <- function(...) {
    structure(
      matrix(nrow = 2L, ncol = 0L),
      dimnames = list(c("alpha", "beta"), NULL)
    )
  }
  captured_calls <- list()
  update_pkgs(
    repos = c(CRAN = requested_repo, A = repo_a, B = repo_b),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = two_repo_status,
    installed_fn = two_repo_installed
  )
  stopifnot(length(captured_calls) == 2L)
  calls_by_pkg <- setNames(captured_calls, vapply(
    captured_calls,
    function(call) call$pkg,
    character(1)
  ))
  stopifnot(identical(
    unname(calls_by_pkg[["alpha"]]$repos)[[1L]],
    repo_a
  ))
  stopifnot(identical(
    unname(calls_by_pkg[["beta"]]$repos)[[1L]],
    repo_b
  ))

  mixed_group_status <- function(pkg, lib) {
    data.frame(
      package = pkg,
      remotepkgref = rep(NA_character_, length(pkg)),
      repotype = c(NA, NA),
      repository = c(repo_a, "CRAN"),
      stringsAsFactors = FALSE
    )
  }
  captured_calls <- list()
  update_pkgs(
    repos = c(CRAN = requested_repo, A = repo_a),
    r_lib = explicit,
    pkg_install = fake_pkg_install,
    status_fn = mixed_group_status,
    installed_fn = two_repo_installed
  )
  calls_by_pkg <- setNames(captured_calls, vapply(
    captured_calls,
    function(call) call$pkg,
    character(1)
  ))
  stopifnot(identical(
    unname(calls_by_pkg[["alpha"]]$repos)[[1L]],
    repo_a
  ))
  stopifnot(identical(
    unname(calls_by_pkg[["cran::beta"]]$repos)[[1L]],
    requested_repo
  ))

  managed_file <- file.path(versioned, "package-file")
  writeLines("package", managed_file)
  stopifnot(file.exists(managed_file))
  reset_clir_library(versioned, root, r_version = "4.3.2")
  stopifnot(!dir.exists(versioned))

  dir.create(versioned, recursive = TRUE)
  expect_error(reset_clir_library(
    versioned,
    root,
    r_version = "4.3.2",
    unlink_fn = function(...) 1L
  ))
  stopifnot(dir.exists(versioned))
  reset_clir_library(versioned, root, r_version = "4.3.2")
  stopifnot(!dir.exists(versioned))

  wild_root <- file.path(root, "clir*")
  wild_sibling_root <- file.path(root, "clir-sibling")
  dir.create(wild_root, recursive = TRUE)
  dir.create(wild_sibling_root, recursive = TRUE)
  wild_library <- default_r_library(wild_root, r_version = "4.3.2")
  wild_sibling_library <- default_r_library(
    wild_sibling_root,
    r_version = "4.3.2"
  )
  dir.create(wild_library, recursive = TRUE)
  dir.create(wild_sibling_library, recursive = TRUE)
  writeLines("keep", file.path(wild_sibling_library, "keep.txt"))
  reset_clir_library(wild_library, wild_root, r_version = "4.3.2")
  stopifnot(!dir.exists(wild_library))
  stopifnot(file.exists(file.path(wild_sibling_library, "keep.txt")))

  outside <- tempfile("clir-outside-")
  dir.create(outside, recursive = TRUE)
  expect_error(reset_clir_library(outside, root, r_version = "4.3.2"))

  symlink_target <- file.path(root, "r", "4.3", "library")
  dir.create(dirname(symlink_target), recursive = TRUE, showWarnings = FALSE)
  file.symlink(outside, symlink_target)
  expect_error(reset_clir_library(symlink_target, root, r_version = "4.3.2"))
  unlink(symlink_target, force = TRUE)

  message("All util tests passed.")
})
