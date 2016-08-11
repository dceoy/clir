#!/usr/bin/env Rscript
#
# Usage:  clir print-libpath

if(length(argv <- commandArgs(trailingOnly = TRUE)) == 0) {
  message(.libPaths()[1])
} else {
  stop('invalid arguments')
}
