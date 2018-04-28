#!/usr/bin/env bash
#
# Set up `clir`, command-line R package installer

set -e

if [[ "${1}" = '--debug' ]]; then
  set -ux
  export DEBUG=1
  R="R --verbose --vanilla"
else
  set -u
  R="R --vanilla --slave"
fi

function abort {
  {
    if [[ ${#} -eq 0 ]]; then
      cat -
    else
      echo "install.sh: ${*}"
    fi
  } >&2
  exit 1
}

CRAN_URL='https://cloud.r-project.org/'
CLIR_ROOT="${HOME}/.clir"
CLIR="${CLIR_ROOT}/bin/clir"
R_LIBS_USER="${CLIR_ROOT}/r/library"

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
export R_LIBS_USER
echo "
options(repos = c(CRAN = '${CRAN_URL}'));
deps <- c('docopt', 'yaml', 'devtools', 'drat');
if (! require('devtools')) install.packages(pkgs = 'devtools', dependencies = TRUE);
devtools::install_cran(deps, dependencies = TRUE);
sapply(deps, library, character.only = TRUE);
" | ${R} -q || abort 'Package installation faild.'
echo

echo '>>> Validate installed packages'
${CLIR} validate devtools docopt drat yaml

# shellcheck disable=SC2016
echo '
>>> Done.


To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add clir/r/library to ${R_LIBS_USER}
  $ echo "export R_LIBS_USER=${HOME}/.clir/r/library" >> ~/.bash_profile

If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

For more information, see https://github.com/dceoy/clir'
