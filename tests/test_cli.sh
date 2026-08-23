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

installer_root="${test_root}/installer-source"
installer_fake_bin="${test_root}/installer-fake-bin"
installer_env_library="${test_root}/renviron-library"
installer_managed_library="${installer_root}/r/4.3/library"
installer_default_library="${test_root}/default-user-library"
installer_marker="${test_root}/installed-marker"
mkdir -p "${installer_root}/bin" "${installer_root}/src" "${installer_fake_bin}"
cp "${repo_root}/install_clir.sh" "${installer_root}/install_clir.sh"
cp "${repo_root}/bin/clir" "${installer_root}/bin/clir"
cp "${repo_root}/src/clir.R" "${installer_root}/src/clir.R"
cp "${repo_root}/src/util.R" "${installer_root}/src/util.R"
chmod +x "${installer_root}/install_clir.sh" "${installer_root}/bin/clir"
printf 'R_LIBS_USER=%s\n' "${installer_env_library}" >"${test_root}/.Renviron"
printf '# CLIR_TEST_PROFILE=enabled\n' >"${test_root}/.Rprofile"
cat >"${installer_fake_bin}/R" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" = '--version' ]]; then
  printf 'R version 4.3.0\n'
  exit 0
fi
args=" $* "
startup_env_library="${CLIR_TEST_DEFAULT_LIBRARY}"
if [[ "${args}" != *'--no-environ'* &&
  "${args}" != *'--vanilla'* &&
  -f "${HOME}/.Renviron" ]]; then
  renviron_library=$(sed -ne 's/^R_LIBS_USER=//p' "${HOME}/.Renviron")
  if [[ -n "${renviron_library}" ]]; then
    startup_env_library="${renviron_library}"
  fi
fi
if [[ "${args}" != *'--no-init-file'* &&
  "${args}" != *'--vanilla'* &&
  -f "${HOME}/.Rprofile" ]] &&
  grep -Fq 'CLIR_TEST_PROFILE=enabled' "${HOME}/.Rprofile"; then
  printf 'profile-noise'
  touch "${CLIR_TEST_PROBE_MARKER}"
fi
if [[ "${args}" = *' -e '* ]]; then
  if [[ "${args}" = *'R.version'* ]]; then
    printf '4.3'
  elif [[ "${args}" = *'collapse'* ]]; then
    if [[ "${args}" = *'--vanilla'* ]]; then
      printf '\034%s' "${CLIR_TEST_DEFAULT_LIBRARY}"
    else
      printf '\034%s' "${startup_env_library}"
    fi
  elif [[ "${args}" = *'paths <-'* && "${args}" = *'--vanilla'* ]]; then
    printf '%s' "${CLIR_TEST_MANAGED_LIBRARY}"
  elif [[ "${args}" = *'paths <-'* ]]; then
    printf '%s' "${startup_env_library}"
  elif [[ "${args}" = *'--vanilla'* ]]; then
    printf '%s' "${CLIR_TEST_MANAGED_LIBRARY}"
  else
    printf '%s' "${CLIR_TEST_ENV_LIBRARY}"
  fi
elif [[ "${args}" = *'--vanilla'* ]]; then
  touch "${CLIR_TEST_MANAGED_MARKER}"
else
  touch "${CLIR_TEST_ENV_MARKER}"
fi
EOF
cat >"${installer_fake_bin}/Rscript" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args=" $* "
[[ "${args}" != *' -d '* ]]
[[ "${CLIR_R_LIBS_USER:-}" = "${CLIR_TEST_ENV_LIBRARY}" ]]
if [[ "${args}" != *'--no-init-file'* &&
  "${args}" != *'--vanilla'* &&
  -f "${HOME}/.Rprofile" ]] &&
  grep -Fq 'CLIR_TEST_PROFILE=enabled' "${HOME}/.Rprofile"; then
  touch "${CLIR_TEST_PROFILE_MARKER}"
fi
[[ "${R_LIBS_USER:-}" = "${CLIR_TEST_ENV_LIBRARY}" ]]
[[ -f "${CLIR_TEST_ENV_MARKER}" ]]
EOF
chmod +x "${installer_fake_bin}/R" "${installer_fake_bin}/Rscript"
env -u R_LIBS_USER -u R_LIBS \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_env_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_default_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --debug
[[ -f "${installer_marker}" ]]
[[ ! -e "${test_root}/managed-marker" ]]
[[ ! -e "${test_root}/probe-profile-marker" ]]
[[ -f "${test_root}/runtime-profile-marker" ]]

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

run_cli --version | grep -Fq 'v2.0.0'
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
  local output
  if output=$(run_cli "$@" 2>&1); then
    echo "parser accepted removed interface: $*" >&2
    exit 1
  fi
  [[ -n "${output}" ]]
}

assert_parser_rejects drat example
assert_parser_rejects install --devt=cran example
assert_parser_rejects install --bioc example
assert_parser_rejects --invalid-option

echo 'All CLI tests passed.'
