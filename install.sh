#!/usr/bin/env bash
#
# Usage:  install.sh [ --root ] [ --force ] [ --cran <url> ]
#         install.sh [ -h | --help ]
#
# Description:
#   Set up `clir`, command-line R package installer
#
# Options:
#   --root        Install clir with root
#   -f            Force reinstallation
#   --cran <url>  Set a URL for CRAN [default: https://cloud.r-project.org/]
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

while [[ -n "${1}" ]]; do
  case "${1}" in
    '--root' )
      SYSTEM_INSTALL=1
      shift 1
      ;;
    '--force' )
      REINSTALL=1
      shift 1
      ;;
    '--cran' )
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

[[ -n "${SYSTEM_INSTALL}" ]] || SYSTEM_INSTALL=0
[[ -n "${REINSTALL}" ]] || REINSTALL=0
[[ -n "${CRAN_URL}" ]] || CRAN_URL='https://cloud.r-project.org/'

if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  CLIR_ROOT="${HOME}/.clir"
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
else
  CLIR_ROOT='/usr/local/src/clir'
fi

set -u

echo '>>> Validate requirements'
R --version || abort 'R is not found.'
git --version || abort 'Git is not found.'
echo

echo '>>> Check out clir from GitHub'
if [[ ! -d "${CLIR_ROOT}" ]]; then
  git clone https://github.com/dceoy/clir.git "${CLIR_ROOT}"
elif [[ ${REINSTALL} -eq 0 ]]; then
  git --git-dir="${CLIR_ROOT}/.git" pull origin master
else
  git --git-dir="${CLIR_ROOT}/.git" fetch
  git --git-dir="${CLIR_ROOT}/.git" reset --hard origin/master
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
sapply(c('docopt', 'yaml', 'devtools', 'drat'),
       function(p) {
         if ((${REINSTALL} != 0) || (! require(p, character.only = TRUE))) {
           if (${SYSTEM_INSTALL} == 0) {
             install.packages(pkgs = p, lib = '${LIB_DIR}', dependencies = TRUE);
           } else {
             install.packages(pkgs = p, dependencies = TRUE);
           };
         };
         library(p, character.only = TRUE);
       });
EOF
echo

echo '>>> Validate installed packages'
${CLIR_ROOT}/bin/clir install --devt=cran devtools docopt drat yaml
${CLIR_ROOT}/bin/clir validate devtools docopt drat yaml
echo

echo '>>> Done.'
# shellcheck disable=SC2016
[[ ${SYSTEM_INSTALL} -eq 0 ]] && echo '

To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add your R library path to ${R_LIBS_USER}
  $ echo "export R_LIBS_USER=${HOME}/.clir/r/library" >> ~/.bash_profile

If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

For more information, see https://github.com/dceoy/clir'
