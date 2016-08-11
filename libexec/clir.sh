#!/usr/bin/env bash
#
# Usage:  clir COMMAND [arg...]
#         clir [ -h | --help | -v | --version ]
#
# Options:
#   -h, --help          Print usage
#   -v, --version       Print version information and quit
#
# Commands:
#   bioc-install        Install or update R packages via Bioconductor
#   bitbucket-install   Install or update R packages via Bitbucket
#   cran-install        Install or update R packages via CRAN
#   github-install      Install or update R packages via GitHub
#   install             Install or update R packages via CRAN (shortcut of `cran-install`)
#   print-libpath       Print the path where R packages are installed
#   set-cran            Set URLs of CRAN mirror sites
#   set-drat            Set Drat repositories
#   test-load           Test loading of installed R packages
#
# Run 'clir COMMAND --help' for more information on a command.

set -e

CLIR_VERSION='0.1.1'
export CLIR_ROOT="$(dirname $(dirname ${0}))"

if [[ "${1}" = '-d' ]] || [[ "${1}" = '--debug' ]]; then
  set -x
  export CLIR_DEBUG=1
  shift 1
fi

R_VERSION_INFO="$(R --version | head -1)"
R_PATH="$(which R)"
[[ -n "${CLIR_DEBUG}" ]] \
  && R_CMD="${R_PATH} --verbose --vanilla" \
  || R_CMD="${R_PATH} --vanilla --slave"

[[ -n "${R_LIBS}" ]] || export R_LIBS="${CLIR_ROOT}/r/library"
[[ -d "${R_LIBS}" ]] || mkdir -p ${R_LIBS}

function print_version {
  echo "clir version ${CLIR_VERSION}"
  echo "${R_VERSION_INFO} (${R_PATH})"
}

function print_usage {
  [[ ${#} -eq 0 ]] \
    && cmd_abs_path="${CLIR_ROOT}/libexec/clir.sh" \
    || cmd_abs_path="${1}"
  sed -ne '
    1,2d
    /^#/!q
    s/^#$/# /
    s/^# //p
  ' ${cmd_abs_path}
}

function abort {
  {
    if [[ ${#} -eq 0 ]]; then
      cat -
    else
      echo "clir: ${*}"
    fi
  } >&2
  exit 1
}

function print_cmd_path {
  [[ "${1}" =~ '^-' ]] && abort "no such option \`${1}\`"
  cmd_abs_path="${CLIR_ROOT}/libexec/${1}.R"
  [[ -f "${cmd_abs_path}" ]] || abort "no such command \`${1}\`"
  echo "${cmd_abs_path}"
}

case "${1}" in
  '' )
    {
      print_version && echo && print_usage
    } | abort
    ;;
  '-v' | '--version' )
    print_version
    exit 0
    ;;
  '-h' | '--help' )
    print_usage
    exit 0
    ;;
  'help' )
    if [[ ${#} -eq 1 ]] || [[ "${2}" = 'help' ]]; then
      print_usage
    else
      print_usage "$(print_cmd_path ${2})"
    fi
    exit 0
    ;;
  * )
    subcmd="${1}"
    ;;
esac

subcmd_path="$(print_cmd_path ${subcmd})"
if [[ ${#} -eq 1 ]]; then
  print_usage "${subcmd_path}" | abort
elif [[ "${2}" = '-h' ]] || [[ "${2}" = '--help' ]]; then
  print_usage "${subcmd_path}"
else
  shift 1
  bash -c "${R_CMD} --file=${subcmd_path} --args ${*}"
fi
