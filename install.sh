#!/usr/bin/env bash

set -e

echo '
This script install CLI-based R package installer `clir`.
'

echo '
<<<   Version of R to be used
'

R --version || exit 1
echo "PATH: $(which R)"


echo '
<<<   Checking out from GitHub
'

CLIR_ROOT="${HOME}/.clir"
if [[ -d "${CLIR_ROOT}" ]]; then
  cd "${CLIR_ROOT}" && git pull && cd -
else
  git clone https://github.com/dceoy/clir.git "${CLIR_ROOT}"
fi


echo '
<<<   Installing required libraries
'

CLIR="${CLIR_ROOT}/bin/clir"
export R_LIBS="${CLIR_ROOT}/r/library"
"${CLIR}" set-cran --default
"${CLIR}" set-drat eddelbuettel
echo 'Installing {devtools} and {drat} -----------------------------------------------
'
"${CLIR}" cran-install --quiet devtools drat
"${CLIR}" test-load devtools drat


echo '
Done.


To access the utility, set environment variables as follows:

  # Add clir/bin to ${PATH}
  $ echo "export PATH=${HOME}/.clir/bin:${PATH}" >> ~/.bash_profile

  # Add clir/r/library to ${R_LIBS}
  $ echo "export R_LIBS=${HOME}/.clir/r/library" >> ~/.bash_profile

For more information, see https://github.com/dceoy/clir'
