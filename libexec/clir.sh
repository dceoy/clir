#!/usr/bin/env bash

set -e

if [[ ${1} = '--debug' ]]; then
  set -x
  export CLIR_DEBUG=1
  shift
fi

R_LIBRARY='../r/library'
[[ -d ${R_LIBRARY} ]] || mkdir -p ${R_LIBRARY}

version='0.0.1'
echo "clir version ${version}"
