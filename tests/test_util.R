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
  fake_pkg_install <- function(...) {
    captured <<- list(...)
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
      "alpha",
      "github::owner/beta",
      "git::https://example.invalid/gamma.git",
      "bioc::delta"
    )
  ))
  stopifnot(identical(captured$upgrade, TRUE))

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
