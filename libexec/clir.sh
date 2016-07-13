#!/usr/bin/env bash

set -e

if [[ ${1} = '--debug' ]]; then
  set -x
  export CLIR_DEBUG=1
  shift
fi

