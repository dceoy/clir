#!/usr/bin/env bash
#
# Usage:  install.sh [ --root ] [ --cran-url <mirror> ]
#         install.sh [ -h | --help ]
#
# Description:
#   Set up `clir`, command-line R package installer
#
# Options:
#   --root        Install clir with root
#   -h, --help    Print usage

set -e

# shellcheck disable=SC2086
SCRIPT_PATH="$(dirname ${0})/$(basename ${0})"

[[ "${1}" = '--debug' ]] && set -x && shift 1

function print_usage {
  sed -ne '1,2d; /^#/!q; s/^#$/# /; s/^# //p;' "${SCRIPT_PATH}"
}

function abort {
  {
    if [[ ${#} -eq 0 ]]; then
      cat -
    else
      # shellcheck disable=SC2086
      echo "$(basename ${SCRIPT_PATH}): ${*}"
    fi
  } >&2
  exit 1
}

SYSTEM_INSTALL=0
CLIR_ROOT="${HOME}/.clir"
R_LIB="${CLIR_ROOT}/r/library"
CRAN_URL='https://cloud.r-project.org/'

while [[ -n "${1}" ]]; do
  case "${1}" in
    '--root' )
      SYSTEM_INSTALL=1
      CLIR_ROOT='/usr/local/src/clir'
      R_LIB=''
      shift 1
      ;;
    '--cran-url' )
      CRAN_URL="${2}"
      shift 2
      ;;
    '-h' | '--help' )
      print_usage && exit 0
      ;;
    * )
      abort "invalid argument \`${1}\`"
      ;;
  esac
done

set -u

echo '>>> Validate requirements'
R --version || abort 'R is not found.'
git --version || abort 'Git is not found.'
echo

echo '>>> Check out clir from GitHub'
if [[ -d "${CLIR_ROOT}" ]]; then
  cd "${CLIR_ROOT}" && git pull && cd -
else
  git clone https://github.com/dceoy/clir.git "${CLIR_ROOT}"
fi
echo

echo '>>> Install dependencies'
if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  [[ -d "${R_LIB}" ]] || mkdir -p "${R_LIB}"
  PREPROC_R="\
    options(repos = c(CRAN = '${CRAN_URL}')); \
    deps <- c('docopt', 'yaml', 'devtools', 'drat'); \
    if (! require('devtools')) install.packages(pkgs = 'devtools', lib = '${R_LIB}', dependencies = TRUE); \
    withr::with_libpaths('${R_LIB}', devtools::install_cran(deps, dependencies = TRUE)); \
    sapply(deps, library, character.only = TRUE);"
else
  ln -sf /usr/local/src/clir/src/clir.R /usr/local/bin/clir
  PREPROC_R="\
    options(repos = c(CRAN = '${CRAN_URL}')); \
    deps <- c('docopt', 'yaml', 'devtools', 'drat'); \
    if (! require('devtools')) install.packages(pkgs = 'devtools', dependencies = TRUE); \
    devtools::install_cran(deps, dependencies = TRUE); \
    sapply(deps, library, character.only = TRUE);"
fi
echo "${PREPROC_R}" | R --vanilla --slave || abort 'Package installation failed.'
echo

echo '>>> Validate installed packages'
${CLIR_ROOT}/bin/clir validate devtools docopt drat yaml
echo

echo '>>> Done.'
# shellcheck disable=SC2016
[[ ${SYSTEM_INSTALL} -eq 0 ]] || echo '

To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add clir/r/library to ${R_LIBS_USER}
  $ echo "export R_LIBS_USER=${HOME}/.clir/r/library" >> ~/.bash_profile

If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

For more information, see https://github.com/dceoy/clir'
