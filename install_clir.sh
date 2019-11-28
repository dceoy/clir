#!/usr/bin/env bash
#
# Usage:
#   install_clir.sh [--root] [-f|--force] [--cran=<url>]
#   install_clir.sh -h|--help
#
# Description:
#   Set up `clir` command-line R package installer
#
# Options:
#   --root        Install clir into the system directory (/usr/local)
#   -f, --force   Force reinstallation
#   --cran=<url>  Set a URL for CRAN [default: https://cloud.r-project.org/]
#   -h, --help    Print usage

set -ue

SCRIPT_PATH=$(realpath "${0}")
DEBUG_FLAG=''
if [[ ${#} -ge 1 ]]; then
  for a in "${@}"; do
    [[ "${a}" = '--debug' ]] && DEBUG_FLAG='-d' && set -x && break
  done
fi

function print_usage {
  sed -ne '1,2d; /^#/!q; s/^#$/# /; s/^# //p;' "${SCRIPT_PATH}"
}

function abort {
  {
    if [[ ${#} -eq 0 ]]; then
      cat -
    else
      SCRIPT_NAME=$(basename "${SCRIPT_PATH}")
      echo "${SCRIPT_NAME}: ${*}"
    fi
  } >&2
  exit 1
}

SYSTEM_INSTALL=0
REINSTALL=0
CRAN_URL='https://cloud.r-project.org/'

while [[ ${#} -ge 1 ]]; do
  case "${1}" in
    '--debug' )
      shift 1
      ;;
    '--root' )
      SYSTEM_INSTALL=1 && shift 1
      ;;
    '-f' | '--force' )
      REINSTALL=1 && shift 1
      ;;
    '--cran' )
      CRAN_URL="${2}" && shift 2
      ;;
    --cran=* )
      CRAN_URL="${1#*\=}" && shift 1
      ;;
    '-h' | '--help' )
      print_usage && exit 0
      ;;
    * )
      abort "invalid argument \`${1}\`"
      ;;
  esac
done

if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  CLIR_ROOT="${HOME}/.clir"
  set +u
  if [[ -n "${R_LIBS_USER}" ]]; then
    export R_LIBS_USER
    LIB_DIR="${R_LIBS_USER}"
  elif [[ -n "${R_LIBS}" ]]; then
    export R_LIBS
    LIB_DIR="${R_LIBS}"
  else
    export R_LIBS_USER="${CLIR_ROOT}/r/library"
    LIB_DIR="${R_LIBS_USER}"
  fi
  set -u
else
  CLIR_ROOT='/usr/local/src/clir'
fi

echo '>>> Validate requirements'
R --version || abort 'R is not found.'
git --version || abort 'Git is not found.'
echo

echo '>>> Check out clir from GitHub'
if [[ ! -d "${CLIR_ROOT}" ]]; then
  git clone https://github.com/dceoy/clir.git "${CLIR_ROOT}"
else
  cd "${CLIR_ROOT}" || abort "cd failed: ${CLIR_ROOT}"
  if [[ ${REINSTALL} -eq 0 ]]; then
    git pull --prune origin master
  else
    git fetch --prune origin master
    git reset --hard origin/master
  fi
  cd -
fi
echo

echo '>>> Install dependencies'
if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  [[ -d "${LIB_DIR}" ]] || mkdir -p "${LIB_DIR}"
else
  ln -sf /usr/local/src/clir/src/clir.R /usr/local/bin/clir
fi
cat << EOF | R --vanilla --slave || abort 'Package installation failed.'
options(repos = c(CRAN = '${CRAN_URL}'));
sapply(c('docopt', 'yaml', 'devtools', 'drat', 'BiocManager'),
       function(p) {
         if ((${REINSTALL} != 0) || (! require(p, character.only = TRUE))) {
           install.packages(pkgs = p, lib = .libPaths()[[1]], dependencies = TRUE);
         };
         library(p, character.only = TRUE);
       });
BiocManager::install();
EOF
echo

echo '>>> Validate installed packages'
${CLIR_ROOT}/bin/clir install ${DEBUG_FLAG} --devt=cran devtools docopt drat yaml
${CLIR_ROOT}/bin/clir validate ${DEBUG_FLAG} docopt yaml devtools drat BiocManager
echo

echo '>>> Done.'
# shellcheck disable=SC2016
if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  echo '

To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add your R library path to ${R_LIBS_USER}
  $ echo "export R_LIBS_USER=${HOME}/.clir/r/library" >> ~/.bash_profile

If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

For more information, see https://github.com/dceoy/clir'
fi
