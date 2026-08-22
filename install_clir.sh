#!/usr/bin/env bash
#
# Usage:
#   install_clir.sh [--root] [-f|--force] [--cran=<url>] [--delete-r-lib]
#   install_clir.sh -h|--help
#
# Description:
#   Set up `clir` command-line R package installer
#
# Options:
#   --root            Install clir into the system directory (/usr/local)
#   -f, --force       Force reinstallation
#   --cran=<url>      Set a URL for CRAN [default: https://cloud.r-project.org/]
#   --delete-r-lib    Delete the current clir-managed R library before installation
#   -h, --help        Print usage

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
DELETE_R_LIB=0

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
      CRAN_URL="${1#*=}" && shift 1
      ;;
    '--delete-r-lib' )
      DELETE_R_LIB=1 && shift 1
      ;;
    '-h' | '--help' )
      print_usage && exit 0
      ;;
    * )
      abort "invalid argument \`${1}\`"
      ;;
  esac
done

if [[ -n "${CLIR_SOURCE_DIR:-}" ]]; then
  CLIR_ROOT=$(realpath "${CLIR_SOURCE_DIR}")
elif [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  CLIR_ROOT="${HOME}/.clir"
else
  CLIR_ROOT='/usr/local/src/clir'
fi

echo '>>> Validate requirements'
R --version || abort 'R is not found.'
git --version || abort 'Git is not found.'
echo

function resolve_r_lib {
  # shellcheck disable=SC2016
  R --vanilla --slave -e '
    paths <- Sys.getenv(c("R_LIBS", "R_LIBS_USER"));
    paths <- paths[nzchar(paths) & paths != "NULL"];
    path <- strsplit(paths[1], .Platform$path.sep, fixed = TRUE)[[1]][1];
    # R expands conversion specifiers for R_LIBS_USER and R_LIBS_SITE at startup;
    # R_LIBS remains literal, matching the documented behavior.
    cat(path.expand(path));
  '
}

set +u
if [[ -n "${R_LIBS_USER}" && "${R_LIBS_USER}" != 'NULL' ]]; then
  export R_LIBS_USER
elif [[ -n "${R_LIBS}" && "${R_LIBS}" != 'NULL' ]]; then
  # Prevent R from synthesizing a higher-priority R_LIBS_USER path.
  export R_LIBS
  export R_LIBS_USER='NULL'
else
  # shellcheck disable=SC2016
  R_VERSION=$(R --vanilla --slave -e '
    cat(paste(
      R.version$major,
      strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1],
      sep = "."
    ))
  ')
  export R_LIBS_USER="${CLIR_ROOT}/r/${R_VERSION}/library"
fi
set -u
LIB_DIR=$(resolve_r_lib)

if [[ -n "${CLIR_SOURCE_DIR:-}" ]]; then
  [[ -f "${CLIR_ROOT}/src/clir.R" ]] || abort "clir source not found: ${CLIR_ROOT}"
else
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
fi

if [[ ${DELETE_R_LIB} -ne 0 ]]; then
  echo '>>> Delete the current clir-managed library'
  CLIR_ROOT="${CLIR_ROOT}" CLIR_LIBRARY="${LIB_DIR}" R --vanilla --slave -e '
    source(file.path(Sys.getenv("CLIR_ROOT"), "src", "util.R"));
    reset_clir_library(
      target = Sys.getenv("CLIR_LIBRARY"),
      clir_root_dir = Sys.getenv("CLIR_ROOT")
    )
  '
fi

echo '>>> Install dependencies'
mkdir -p "${LIB_DIR}"
if [[ ${SYSTEM_INSTALL} -ne 0 ]]; then
  ln -sf "${CLIR_ROOT}/bin/clir" /usr/local/bin/clir
fi
CLIR_CRAN_URL="${CRAN_URL}" CLIR_REINSTALL="${REINSTALL}" \
  R --vanilla -q <<'EOF' || abort 'Package installation failed.'
options(repos = c(CRAN = Sys.getenv("CLIR_CRAN_URL")));
pkgs <- c('docopt', 'yaml', 'pak');
reinstall <- identical(Sys.getenv("CLIR_REINSTALL"), "1");
for (p in pkgs) {
  if (reinstall || (!requireNamespace(p, quietly = TRUE))) {
    install.packages(
      pkgs = p,
      lib = .libPaths()[[1]],
      dependencies = NA,
      clean = TRUE
    );
  }
  if (!requireNamespace(p, quietly = TRUE)) {
    stop(paste('Loading', p, 'failed.'));
  }
}
EOF
echo

echo '>>> Validate installed packages'
"${CLIR_ROOT}/bin/clir" install ${DEBUG_FLAG} --no-upgrade docopt yaml pak
"${CLIR_ROOT}/bin/clir" validate ${DEBUG_FLAG} docopt yaml pak
echo

echo '>>> Done.'
if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  echo "Add ${CLIR_ROOT}/bin to PATH."
  echo "The clir library is ${LIB_DIR}."
  echo 'If you use Zsh, update ~/.zshrc; otherwise update ~/.bash_profile.'
  echo 'For more information, see https://github.com/dceoy/clir'
fi
