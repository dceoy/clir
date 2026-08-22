#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

mkdir -p "${test_root}/bin" "${test_root}/src"
cp "${repo_root}/src/clir.R" "${test_root}/src/clir.R"
cp "${repo_root}/src/util.R" "${test_root}/src/util.R"
ln -s ../src/clir.R "${test_root}/bin/clir"

cli="${test_root}/bin/clir"
Rscript "${cli}" --version | grep -Fq 'v1.2.1'
Rscript "${cli}" --help | grep -Fq 'pak'
Rscript "${cli}" config --init >"${test_root}/config.out"
grep -Fq 'repos' "${test_root}/r/clir.yml"

Rscript "${cli}" cran https://example.invalid/cran >/dev/null
grep -Fq 'https://example.invalid/cran' "${test_root}/r/clir.yml"

if Rscript "${cli}" drat example >/dev/null 2>&1; then
  echo 'removed drat command was accepted' >&2
  exit 1
fi
if Rscript "${cli}" install --devt=cran example >/dev/null 2>&1; then
  echo 'removed --devt option was accepted' >&2
  exit 1
fi
if Rscript "${cli}" install --bioc example >/dev/null 2>&1; then
  echo 'removed --bioc option was accepted' >&2
  exit 1
fi

if Rscript "${cli}" --invalid-option >/dev/null 2>&1; then
  echo 'invalid option was accepted' >&2
  exit 1
fi

echo 'All CLI tests passed.'
