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
set -euo pipefail
args=" $* "
printf 'R\n' >>"${CLIR_TEST_PROBE_COUNT:-/dev/null}"
startup_r_libs="${R_LIBS-}"
startup_r_libs_user="${R_LIBS_USER-}"
startup_library_assignment=0
r_libs_set=0
r_libs_user_set=0
[[ ${R_LIBS+x} = x ]] && r_libs_set=1
[[ ${R_LIBS_USER+x} = x ]] && r_libs_user_set=1
if [[ -n "${CLIR_TEST_VANILLA_USER:-}" ]]; then
  startup_r_libs_user="${CLIR_TEST_VANILLA_USER}"
  r_libs_user_set=1
fi
apply_renviron_value() {
  local variable="${1}"
  local value="${2}"
  if [[ "${variable}" = 'R_LIBS' ]]; then
    if [[ "${value}" = '${R_LIBS-default}' ]]; then
      [[ ${r_libs_set} -eq 1 ]] || startup_r_libs='conditional-r-default'
    elif [[ "${value}" = '${R_LIBS:-default}' ]]; then
      [[ -n "${startup_r_libs}" ]] || startup_r_libs='conditional-r-default'
    else
      startup_r_libs="${value}"
    fi
    r_libs_set=1
  else
    if [[ "${value}" = '${R_LIBS_USER-default}' ]]; then
      [[ ${r_libs_user_set} -eq 1 ]] || startup_r_libs_user='conditional-user-default'
    elif [[ "${value}" = '${R_LIBS_USER:-default}' ]]; then
      [[ -n "${startup_r_libs_user}" ]] || startup_r_libs_user='conditional-user-default'
    else
      startup_r_libs_user="${value}"
    fi
    r_libs_user_set=1
  fi
}
if [[ "${args}" != *'--no-environ'* &&
  "${args}" != *'--vanilla'* &&
  "${R_ENVIRON_USER:-}" != '/dev/null' &&
  -f "${HOME}/.Renviron" ]]; then
  renviron_r_libs=$(sed -ne 's/^R_LIBS=//p' "${HOME}/.Renviron")
  renviron_r_libs_user=$(sed -ne 's/^R_LIBS_USER=//p' "${HOME}/.Renviron")
  [[ -z "${renviron_r_libs}" && -z "${renviron_r_libs_user}" ]] || startup_library_assignment=1
  [[ -z "${renviron_r_libs}" ]] || apply_renviron_value R_LIBS "${renviron_r_libs}"
  [[ -z "${renviron_r_libs_user}" ]] || apply_renviron_value R_LIBS_USER "${renviron_r_libs_user}"
fi
if [[ "${args}" = *'--vanilla'* && -n "${CLIR_TEST_VANILLA_USER:-}" ]]; then
  startup_r_libs_user="${CLIR_TEST_VANILLA_USER}"
fi
if [[ "${args}" = *' -e '* ]]; then
  printf '%s\034%s\0344.3\034%s' "${startup_r_libs}" "${startup_r_libs_user}" "${startup_library_assignment}"
else
  printf 'R version 4.3.0\n'
fi
EOF
cat >"${fake_bin}/Rscript" <<'EOF'
#!/usr/bin/env bash
printf 'Rscript\n' >>"${CLIR_TEST_PROBE_COUNT:-/dev/null}"
printf '%s\n' "${R_LIBS_USER-UNSET}" >"${CLIR_TEST_RECORD}"
printf '%s\n' "${R_LIBS-UNSET}" >>"${CLIR_TEST_RECORD}"
EOF
chmod +x "${fake_bin}/R" "${fake_bin}/Rscript"

launcher_record="${test_root}/launcher-env"
launcher_probe_count="${test_root}/launcher-probes"
: >"${launcher_probe_count}"
env -u R_LIBS_USER -u R_LIBS \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 2 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

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

: >"${launcher_probe_count}"
env -u R_LIBS \
  R_LIBS_USER='NULL' \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 2 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

: >"${launcher_probe_count}"
env R_LIBS_USER='NULL' R_LIBS='NULL' \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${test_root}/r/4.3/library" "${launcher_record}"
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 2 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

explicit_user="${test_root}/explicit-user"
: >"${launcher_probe_count}"
env -u R_LIBS \
  R_LIBS_USER="${explicit_user}" \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${explicit_user}" "${launcher_record}"
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 0 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

explicit_r_lib="${test_root}/explicit-r"
: >"${launcher_probe_count}"
env -u R_LIBS_USER \
  R_LIBS="${explicit_r_lib}" \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
[[ "$(sed -n '1p' "${launcher_record}")" != 'NULL' ]]
[[ "$(sed -n '2p' "${launcher_record}")" = "${explicit_r_lib}" ]]
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 0 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

conditional_system_user="${test_root}/system-user-default"
conditional_cases=(
  "user-dash|R_LIBS_USER|\${R_LIBS_USER-default}|${conditional_system_user}|UNSET"
  "user-colon-dash|R_LIBS_USER|\${R_LIBS_USER:-default}|${conditional_system_user}|UNSET"
  "r-dash|R_LIBS|\${R_LIBS-default}|UNSET|conditional-r-default"
  "r-colon-dash|R_LIBS|\${R_LIBS:-default}|UNSET|conditional-r-default"
)
for conditional_case in "${conditional_cases[@]}"; do
  IFS='|' read -r case_id variable expression expected_user expected_r <<<"${conditional_case}"
  # shellcheck disable=SC2016
  printf '%s=%s\n' "${variable}" "${expression}" >"${test_root}/.Renviron"
  : >"${launcher_probe_count}"
  env -u R_LIBS_USER -u R_LIBS \
    HOME="${test_root}" \
    CLIR_TEST_RECORD="${launcher_record}" \
    CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
    CLIR_TEST_VANILLA_USER="${conditional_system_user}" \
    PATH="${fake_bin}:${PATH}" \
    "${cli}" --version
  [[ "$(sed -n '1p' "${launcher_record}")" = "${expected_user}" ]] || {
    echo "conditional startup case failed: ${case_id}" >&2
    exit 1
  }
  [[ "$(sed -n '2p' "${launcher_record}")" = "${expected_r}" ]] || {
    echo "conditional startup case failed: ${case_id}" >&2
    exit 1
  }
  [[ "$(grep -c '^R$' "${launcher_probe_count}")" = 2 ]]
  [[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]
done

same_default_user=$(env -u R_LIBS_USER -u R_LIBS -u R_ENVIRON_USER -u R_PROFILE_USER \
  HOME="${test_root}" \
  R --vanilla --slave -e 'cat(normalizePath(Sys.getenv("R_LIBS_USER"), mustWork = FALSE))')
printf 'R_LIBS_USER=%s\n' "${same_default_user}" >"${test_root}/.Renviron"
: >"${launcher_probe_count}"
env -u R_LIBS_USER -u R_LIBS \
  -u R_ENVIRON_USER -u R_PROFILE_USER \
  HOME="${test_root}" \
  CLIR_TEST_RECORD="${launcher_record}" \
  CLIR_TEST_PROBE_COUNT="${launcher_probe_count}" \
  CLIR_TEST_VANILLA_USER="${same_default_user}" \
  PATH="${fake_bin}:${PATH}" \
  "${cli}" --version
grep -Fxq "${same_default_user}" "${launcher_record}"
[[ "$(grep -c '^R$' "${launcher_probe_count}")" = 2 ]]
[[ "$(grep -c '^Rscript$' "${launcher_probe_count}")" = 1 ]]

installer_root="${test_root}/installer-source"
installer_fake_bin="${test_root}/installer-fake-bin"
installer_env_library="${test_root}/renviron-library"
installer_managed_library="${installer_root}/r/4.3/library"
installer_default_library="${test_root}/default-user-library"
installer_marker="${test_root}/installed-marker"
installer_bootstrap_marker="${test_root}/bootstrap-marker"
installer_link_marker="${test_root}/link-marker"
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
startup_r_libs="${R_LIBS-}"
startup_r_libs_user="${R_LIBS_USER-}"
startup_library_assignment=0
if [[ "${args}" != *'--no-environ'* &&
  "${args}" != *'--vanilla'* &&
  "${R_ENVIRON_USER:-}" != '/dev/null' &&
  -f "${HOME}/.Renviron" ]]; then
  renviron_r_libs=$(sed -ne 's/^R_LIBS=//p' "${HOME}/.Renviron")
  renviron_r_libs_user=$(sed -ne 's/^R_LIBS_USER=//p' "${HOME}/.Renviron")
  [[ -z "${renviron_r_libs}" && -z "${renviron_r_libs_user}" ]] || startup_library_assignment=1
  [[ -z "${renviron_r_libs}" ]] || startup_r_libs="${renviron_r_libs}"
  [[ -z "${renviron_r_libs_user}" ]] || startup_r_libs_user="${renviron_r_libs_user}"
fi
if [[ -n "${startup_r_libs}" && "${startup_r_libs}" != 'NULL' &&
  "${startup_r_libs}" != '__clir_r_libs_probe_'* ]]; then
  resolved_library="${startup_r_libs}"
elif [[ -n "${startup_r_libs_user}" && "${startup_r_libs_user}" != 'NULL' &&
  "${startup_r_libs_user}" != '__clir_r_libs_user_probe_'* ]]; then
  resolved_library="${startup_r_libs_user}"
else
  resolved_library="${CLIR_TEST_DEFAULT_LIBRARY}"
fi
if [[ "${args}" != *'--no-init-file'* &&
  "${args}" != *'--vanilla'* &&
  "${R_PROFILE_USER:-}" != '/dev/null' &&
  -f "${HOME}/.Rprofile" ]] &&
  grep -Fq 'CLIR_TEST_PROFILE=enabled' "${HOME}/.Rprofile"; then
  printf 'profile-noise'
  touch "${CLIR_TEST_PROBE_MARKER}"
fi
if [[ "${args}" = *' -e '* ]]; then
  if [[ "${args}" = *'collapse'* && "${args}" = *'R.version'* ]]; then
    printf '%s\034%s\0344.3\034%s' "${startup_r_libs}" "${startup_r_libs_user}" "${startup_library_assignment}"
  elif [[ "${args}" = *'paths <-'* || "${args}" = *'resolve_r_library'* ]]; then
    printf '%s' "${resolved_library}"
  elif [[ "${args}" = *'R.version'* ]]; then
    printf '4.3'
  elif [[ "${args}" = *'--vanilla'* ]]; then
    printf '%s' "${CLIR_TEST_MANAGED_LIBRARY}"
  else
    printf '%s' "${CLIR_TEST_ENV_LIBRARY}"
  fi
elif [[ "${args}" = *'--vanilla'* ]]; then
  touch "${CLIR_TEST_MANAGED_MARKER}"
elif [[ "${args}" = *'--no-environ'* ]]; then
  touch "${CLIR_TEST_BOOTSTRAP_MARKER}"
else
  touch "${CLIR_TEST_ENV_MARKER}"
fi
EOF
cat >"${installer_fake_bin}/Rscript" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args=" $* "
expected_library="${CLIR_TEST_EXPECTED_LIBRARY:-${CLIR_TEST_ENV_LIBRARY}}"
[[ "${args}" != *' -d '* ]]
selected_library="${R_LIBS_USER:-}"
if [[ -z "${selected_library}" || "${selected_library}" = 'NULL' ]]; then
  selected_library="${R_LIBS-}"
fi
[[ "${CLIR_R_LIBS_USER:-}" = "${R_LIBS_USER-}" ]]
[[ "${CLIR_R_LIBS:-}" = "${R_LIBS-}" ]]
if [[ "${args}" != *'--no-init-file'* &&
  "${args}" != *'--vanilla'* &&
  "${R_PROFILE_USER:-}" != '/dev/null' &&
  -f "${HOME}/.Rprofile" ]] &&
  grep -Fq 'CLIR_TEST_PROFILE=enabled' "${HOME}/.Rprofile"; then
  touch "${CLIR_TEST_PROFILE_MARKER}"
fi
[[ "${selected_library}" = "${expected_library}" ]]
expected_marker="${CLIR_TEST_EXPECTED_MARKER:-${CLIR_TEST_ENV_MARKER}}"
[[ -f "${expected_marker}" ]]
EOF
chmod +x "${installer_fake_bin}/R" "${installer_fake_bin}/Rscript"
cat >"${installer_fake_bin}/ln" <<'EOF'
#!/usr/bin/env bash
touch "${CLIR_TEST_LINK_MARKER}"
EOF
chmod +x "${installer_fake_bin}/ln"
env -u R_LIBS_USER -u R_LIBS \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_env_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_default_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_BOOTSTRAP_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_EXPECTED_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --debug
[[ -f "${installer_bootstrap_marker}" ]]
[[ ! -e "${test_root}/managed-marker" ]]
[[ ! -e "${test_root}/probe-profile-marker" ]]
[[ -f "${test_root}/runtime-profile-marker" ]]

printf 'R_LIBS_USER=%s\n' "${installer_default_library}" >"${test_root}/.Renviron"
env -u R_LIBS_USER -u R_LIBS \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_default_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_default_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_BOOTSTRAP_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_EXPECTED_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --debug

shell_user_library="${test_root}/shell-user-library"
printf 'R_LIBS_USER=%s\n' "${installer_env_library}" >"${test_root}/.Renviron"
rm -f "${installer_bootstrap_marker}" "${test_root}/runtime-profile-marker"
env -u R_LIBS \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_env_library}" \
CLIR_TEST_EXPECTED_LIBRARY="${shell_user_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_default_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_BOOTSTRAP_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_EXPECTED_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
R_LIBS_USER="${shell_user_library}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --debug

shell_r_library="${test_root}/shell-r-library"
rm -f "${installer_bootstrap_marker}" "${test_root}/runtime-profile-marker"
env -u R_LIBS_USER \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_env_library}" \
CLIR_TEST_EXPECTED_LIBRARY="${shell_r_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_default_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_BOOTSTRAP_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_EXPECTED_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
R_LIBS="${shell_r_library}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --debug

rm -f "${installer_marker}" "${installer_bootstrap_marker}" \
  "${installer_link_marker}" "${test_root}/managed-marker" \
  "${test_root}/probe-profile-marker" "${test_root}/runtime-profile-marker"
printf 'R_LIBS_USER=%s\n' "${installer_env_library}" >"${test_root}/.Renviron"
printf 'CLIR_TEST_PROFILE=enabled\n' >"${test_root}/.Rprofile"
env -u R_LIBS_USER -u R_LIBS \
CLIR_SOURCE_DIR="${installer_root}" \
CLIR_TEST_ENV_LIBRARY="${installer_env_library}" \
CLIR_TEST_EXPECTED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_MANAGED_LIBRARY="${installer_managed_library}" \
CLIR_TEST_DEFAULT_LIBRARY="${installer_managed_library}" \
CLIR_TEST_ENV_MARKER="${installer_marker}" \
CLIR_TEST_BOOTSTRAP_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_EXPECTED_MARKER="${installer_bootstrap_marker}" \
CLIR_TEST_LINK_MARKER="${installer_link_marker}" \
CLIR_TEST_MANAGED_MARKER="${test_root}/managed-marker" \
CLIR_TEST_PROBE_MARKER="${test_root}/probe-profile-marker" \
CLIR_TEST_PROFILE_MARKER="${test_root}/runtime-profile-marker" \
HOME="${test_root}" \
PATH="${installer_fake_bin}:${PATH}" \
  "${installer_root}/install_clir.sh" --root --debug
[[ -f "${installer_link_marker}" ]]
[[ -f "${installer_bootstrap_marker}" ]]
[[ ! -e "${installer_marker}" ]]
[[ ! -e "${test_root}/managed-marker" ]]
[[ ! -e "${test_root}/probe-profile-marker" ]]
[[ ! -e "${test_root}/runtime-profile-marker" ]]

if [[ -n "${R_LIBS_USER:-}" ]]; then
  cli_env=("R_LIBS_USER=${R_LIBS_USER}")
elif [[ -n "${R_LIBS:-}" ]]; then
  cli_env=("R_LIBS=${R_LIBS}")
else
  runtime_r_lib=$(R --vanilla --slave -e 'cat(.libPaths()[[1]])')
  cli_env=("R_LIBS_USER=${runtime_r_lib}")
fi
cli_home="${test_root}/cli-home"
mkdir -p "${cli_home}"
run_cli() {
  env -u R_ENVIRON_USER -u R_PROFILE_USER -u R_PROFILE \
    HOME="${cli_home}" "${cli_env[@]}" "${cli}" "${@}"
}

[[ "$(run_cli --version)" = 'v2.0.0' ]]

profile_home="${test_root}/profile-home"
profile_file="${test_root}/drop-selected-library.R"
mkdir -p "${profile_home}"
cat >"${profile_file}" <<'EOF'
selected <- normalizePath(Sys.getenv("CLIR_TEST_SELECTED_LIBRARY"), mustWork = FALSE)
.libPaths(setdiff(.libPaths(), selected))
if (requireNamespace("docopt", quietly = TRUE)) {
  stop("docopt is available outside the selected library")
}
EOF
selected_library="${cli_env[0]#*=}"
selected_library="${selected_library%%:*}"
profile_version=$(env -u R_ENVIRON_USER -u R_PROFILE \
  R_PROFILE_USER="${profile_file}" \
  HOME="${profile_home}" \
  CLIR_TEST_SELECTED_LIBRARY="${selected_library}" \
  "${cli_env[@]}" "${cli}" --version)
[[ "${profile_version}" = 'v2.0.0' ]]

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
