#!/usr/bin/env bash

set -e
[[ -n ${CLIR_DEBUG} ]] && set -x

CRAN_MIRROR_FILE='../r/cran_mirror'

if [[ -n ${1} ]]; then
  echo "CRAN mirror is set to ${1}"
  echo ${1} > ${CRAN_MIRROR_FILE}
fi
