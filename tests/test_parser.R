#!/usr/bin/env Rscript

# Exercise argument parsing without running package installations.
args <- commandArgs(trailingOnly = FALSE)
path <- sub("^--file=", "", args[grepl("^--file=", args)][[1L]])
repo_root <- normalizePath(file.path(dirname(path), ".."))
source(file.path(repo_root, "src", "clir.R"))

parse <- function(...) parse_clir_args(c(...))$args

result <- parse(
  "install", "dplyr", "--quiet", "bioc::GenomicRanges",
  "--no-upgrade", "-v", "--cpus=2"
)
stopifnot(
  isTRUE(result$install),
  isTRUE(result[["--quiet"]]),
  isTRUE(result[["--no-upgrade"]]),
  isTRUE(result[["-v"]]),
  identical(result[["--cpus"]], 2L),
  identical(result[["<pkg>"]], c("dplyr", "bioc::GenomicRanges"))
)

result <- parse("download", "dplyr", "--dest-dir", "/tmp/packages", "yaml")
stopifnot(
  isTRUE(result$download),
  identical(result[["--dest-dir"]], "/tmp/packages"),
  identical(result[["<pkg>"]], c("dplyr", "yaml"))
)

result <- parse("cran", "https://example.invalid/cran", "--quiet")
stopifnot(
  isTRUE(result$cran),
  identical(result[["<url>"]], "https://example.invalid/cran")
)

result <- parse("session")
stopifnot(isTRUE(result$session), length(result[["<pkg>"]]) == 0L)

result <- parse("install", "--", "--special-package")
stopifnot(identical(result[["<pkg>"]], "--special-package"))

stopifnot(
  identical(parse_clir_args(c("--help"))$action, "help"),
  identical(parse_clir_args(c("install", "--help"))$action, "help"),
  identical(parse_clir_args(c("--version"))$action, "version")
)

reject <- function(argv) {
  failed <- inherits(
    tryCatch(parse_clir_args(argv), error = identity), "error"
  )
  if (!failed) stop("Unexpectedly accepted: ", paste(argv, collapse = " "))
}
reject(character())
reject(c("drat", "example"))
reject(c("install"))
reject(c("download"))
reject(c("config", "extra"))
reject(c("update", "extra"))
reject(c("install", "--bad", "dplyr"))
reject(c("install", "--cpus=abc", "dplyr"))
reject(c("install", "--cpus=0", "dplyr"))
reject(c("install", "--cpus=-1", "dplyr"))
reject(c("install", "--devt=cran", "dplyr"))
reject(c("install", "--bioc", "dplyr"))
reject(c("config", "--no-upgrade"))
cat("CLI parser tests passed.\n")
