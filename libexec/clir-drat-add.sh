#!/usr/bin/env bash

set -e
[[ -n ${CLIR_DEBUG} ]] && set -x

DRAT_ACCOUNTS_FILE='../r/drat_accounts'

if [[ ${#} -gt 0 ]]; then
  accounts=($(cat ${DRAT_ACCOUNTS_FILE}) ${@})
  echo "The following accounts are set as Drat repositories:"
  for a in ${@}; do
    echo "  - ${a}"
    grep -e "^${a}$" ${DRAT_ACCOUNTS_FILE} > /dev/null || echo ${a} >> ${DRAT_ACCOUNTS_FILE}
  done
fi
