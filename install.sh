#!/usr/bin/env bash
#
# Set up `clir`, command-line R package installer

set -e

if [[ "${1}" = '--debug' ]]; then
  set -x
  export DEBUG=1
  R="R --verbose --vanilla"
else
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


echo '>>> Check out clir from GitHub'

if [[ -d "${CLIR_ROOT}" ]]; then
  cd ${CLIR_ROOT} && git pull && cd -
else
  git clone https://github.com/dceoy/clir.git ${CLIR_ROOT}
fi


echo '>>> Install required libraries'

export R_LIBS_USER
${R} -q -e "install.packages(pkgs = c('docopt', 'yaml'), dependencies = TRUE, repos = '${CRAN_URL}');"
${R} -q -e "lapply(c('docopt', 'yaml'), library, character.only = TRUE);" || abort 'Package installation faild.'

${CLIR} config --init
echo 'Installing {devtools}, {drat}, and {yaml} --------------------------------------'
${CLIR} install --quiet devtools drat yaml
${R} -q -e 'devtools::has_devel()'
echo
${CLIR} validate devtools drat yaml


echo '
>>> Done.


To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add clir/r/library to ${R_LIBS_USER}
  $ echo "export R_LIBS_USER=${HOME}/.clir/r/library" >> ~/.bash_profile

If you use Zsh, modify `~/.zshrc` instead of `~/.bash_profile`.

For more information, see https://github.com/dceoy/clir'
