#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

mkdir -p "${test_root}/bin" "${test_root}/src"
cp "${repo_root}/src/clir.R" "${test_root}/src/clir.R"
cp "${repo_root}/src/util.R" "${test_root}/src/util.R"
cp "${repo_root}/bin/clir" "${test_root}/bin/clir"
chmod +x "${test_root}/bin/clir"

cli="${test_root}/bin/clir"
fake_bin="${test_root}/fake-bin"
mkdir -p "${fake_bin}"
cat >"${fake_bin}/R" <<'EOF'
#!/usr/bin/env bash
printf '4.3'
EOF
cat >"${fake_bin}/Rscript" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${R_LIBS_USER-UNSET}" >"${CLIR_TEST_RECORD}"
printf '%s\n' "${R_LIBS-UNSET}" >>"${CLIR_TEST_RECORD}"
EOF
chmod +x "${fake_bin}/R" "${fake_bin}/Rscript"

launcher_record="${test_root}/launcher-env"
env -u R_LIBS_USER -u R_LIBS \
  CLIR_TEST_RECORD="${launcher_record}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"

probe_root="${test_root}/default-library-probe"
mkdir -p "${probe_root}/bin" "${probe_root}/src"
cp "${repo_root}/bin/clir" "${probe_root}/bin/clir"
# shellcheck disable=SC2016
probe_version=$(R --vanilla --slave -e 'cat(paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = "."))')
probe_library="${probe_root}/r/${probe_version}/library"
mkdir -p "${probe_library}"
probe_library=$(realpath "${probe_library}")
cat >"${probe_root}/src/clir.R" <<'EOF'
expected <- normalizePath(Sys.getenv("CLIR_EXPECTED_LIBRARY"), mustWork = FALSE)
paths <- normalizePath(.libPaths(), mustWork = FALSE)
if (!identical(Sys.getenv("R_LIBS_USER"), expected)) {
  stop(sprintf("R_LIBS_USER was %s, expected %s", Sys.getenv("R_LIBS_USER"), expected))
}
if (!(expected %in% paths)) {
  stop(sprintf("managed library %s is absent from .libPaths(): %s", expected, paste(paths, collapse = ", ")))
}
cat(paths[[1L]], "\n")
EOF
env -u R_LIBS_USER -u R_LIBS \
  CLIR_EXPECTED_LIBRARY="${probe_library}" \
  "${probe_root}/bin/clir" --version

env -u R_LIBS \
  R_LIBS_USER='NULL' \
  CLIR_TEST_RECORD="${launcher_record}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"

env R_LIBS_USER='NULL' R_LIBS='NULL' \
  CLIR_TEST_RECORD="${launcher_record}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"

explicit_user="${test_root}/explicit-user"
env -u R_LIBS \
  R_LIBS_USER="${explicit_user}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${explicit_user}" "${launcher_record}"

explicit_r_lib="${test_root}/explicit-r"
env -u R_LIBS_USER \
  R_LIBS="${explicit_r_lib}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
[[ "$(sed -n '1p' "${launcher_record}")" = 'NULL' ]]
[[ "$(sed -n '2p' "${launcher_record}")" = "${explicit_r_lib}" ]]

if [[ -n "${R_LIBS_USER:-}" ]]; then
  cli_env=("R_LIBS_USER=${R_LIBS_USER}")
elif [[ -n "${R_LIBS:-}" ]]; then
  cli_env=("R_LIBS=${R_LIBS}")
else
  runtime_r_lib=$(R --vanilla --slave -e 'cat(.libPaths()[[1]])')
  cli_env=("R_LIBS_USER=${runtime_r_lib}")
fi
run_cli() {
  env "${cli_env[@]}" "${cli}" "${@}"
}

run_cli --version | grep -Fq 'v1.2.1'
help_output=$(run_cli --help)
grep -Fq 'pak' <<<"${help_output}"
if grep -Eq 'drat|--devt|--bioc' <<<"${help_output}"; then
  echo 'removed interfaces remain in the CLI help' >&2
  exit 1
fi
run_cli config --init >"${test_root}/config.out"
grep -Fq 'repos' "${test_root}/r/clir.yml"

run_cli cran https://example.invalid/cran >/dev/null
grep -Fq 'https://example.invalid/cran' "${test_root}/r/clir.yml"

assert_parser_rejects() {
  local expected output
  expected=${1}
  shift
  if output=$(run_cli "$@" 2>&1); then
    echo "parser accepted removed interface: $*" >&2
    exit 1
  fi
  grep -Fq 'Unknown arguments:' <<<"${output}"
  grep -Fq -- "${expected}" <<<"${output}"
}

assert_parser_rejects 'drat' drat example
assert_parser_rejects '--devt' install --devt=cran example
assert_parser_rejects '--bioc' install --bioc example
assert_parser_rejects '--invalid-option' --invalid-option

echo 'All CLI tests passed.'
