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
if [[ ${#} -ge 1 ]]; then
  for a in "${@}"; do
    [[ "${a}" = '--debug' ]] && set -x && break
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
R_VERSION=''

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

function read_r_library_env {
  local startup_mode="${1:-normal}"
  # shellcheck disable=SC2016
  local r_code='
    libs <- Sys.getenv(c("R_LIBS", "R_LIBS_USER"));
    version <- paste(
      R.version$major,
      strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1],
      sep = "."
    );
    arch <- sub("^/", "", Sys.getenv("R_ARCH"));
    env_names <- if (nzchar(arch)) {
      c(paste0(".Renviron.", arch), ".Renviron")
    } else {
      ".Renviron"
    };
    site_file <- Sys.getenv("R_ENVIRON", unset = NA_character_);
    site_files <- if (is.na(site_file)) {
      candidates <- file.path(R.home("etc"), "Renviron.site");
      if (nzchar(arch)) {
        candidates <- c(file.path(R.home("etc"), arch, "Renviron.site"), candidates);
      }
      existing <- candidates[file.exists(candidates)];
      if (length(existing)) existing[[1L]] else character()
    } else if (nzchar(site_file)) {
      path.expand(site_file)
    } else {
      character()
    };
    user_file <- Sys.getenv("R_ENVIRON_USER", unset = NA_character_);
    user_files <- if (is.na(user_file)) {
      candidates <- c(
        file.path(getwd(), env_names),
        file.path(path.expand("~"), env_names)
      );
      existing <- candidates[file.exists(candidates)];
      if (length(existing)) existing[[1L]] else character()
    } else if (nzchar(user_file)) {
      path.expand(user_file)
    } else {
      character()
    };
    env_files <- unique(c(site_files, user_files));
    has_library_assignment <- any(vapply(
      env_files,
      function(path) {
        if (!file.exists(path)) return(FALSE);
        lines <- tryCatch(readLines(path, warn = FALSE), error = function(...) character());
        any(grepl("^[[:space:]]*(R_LIBS|R_LIBS_USER)[[:space:]]*=", lines));
      },
      logical(1)
    ));
    cat(paste(c(libs, version, as.integer(has_library_assignment)), collapse = "\034"));
  '
  case "${startup_mode}" in
    'normal' )
      # shellcheck disable=SC2016
      env -u R_LIBS -u R_LIBS_USER \
        R --no-site-file --no-init-file --no-save --no-restore --no-echo \
        --slave -e "${r_code}"
      ;;
    'vanilla' )
      # shellcheck disable=SC2016
      env -u R_LIBS -u R_LIBS_USER R --vanilla --slave -e "${r_code}"
      ;;
    * )
      echo "Unknown R startup probe mode: ${startup_mode}" >&2
      return 2
      ;;
  esac
}

function use_r_startup_library {
  local separator=$'\034'
  local startup_env startup_rest startup_version_rest
  local vanilla_env vanilla_rest
  local startup_r_libs startup_r_libs_user vanilla_r_libs vanilla_r_libs_user
  local startup_has_library_assignment
  startup_env=$(read_r_library_env 'normal')
  startup_r_libs="${startup_env%%"${separator}"*}"
  startup_rest="${startup_env#*"${separator}"}"
  startup_r_libs_user="${startup_rest%%"${separator}"*}"
  startup_version_rest="${startup_rest#*"${separator}"}"
  R_VERSION="${startup_version_rest%%"${separator}"*}"
  startup_has_library_assignment="${startup_version_rest#*"${separator}"}"

  vanilla_env=$(read_r_library_env 'vanilla')
  vanilla_r_libs="${vanilla_env%%"${separator}"*}"
  vanilla_rest="${vanilla_env#*"${separator}"}"
  vanilla_r_libs_user="${vanilla_rest%%"${separator}"*}"

  if [[ -n "${startup_r_libs}" && "${startup_r_libs}" != 'NULL' &&
    "${startup_r_libs}" != "${vanilla_r_libs}" ]]; then
    export R_LIBS="${startup_r_libs}"
    return 0
  fi
  if [[ -n "${startup_r_libs_user}" &&
    "${startup_r_libs_user}" != 'NULL' &&
    "${startup_r_libs_user}" != "${vanilla_r_libs_user}" ]]; then
    export R_LIBS_USER="${startup_r_libs_user}"
    return 0
  fi

  # A startup-file assignment can intentionally equal R's synthesized
  # default. The normal probe preserves conditional expansion semantics, and
  # the R-side assignment flag distinguishes that case from an untouched
  # default without injecting a value into the expansion.
  if [[ "${startup_has_library_assignment}" = 1 ]]; then
    if [[ -n "${startup_r_libs}" && "${startup_r_libs}" != 'NULL' ]]; then
      export R_LIBS="${startup_r_libs}"
      return 0
    fi
    if [[ -n "${startup_r_libs_user}" &&
      "${startup_r_libs_user}" != 'NULL' ]]; then
      export R_LIBS_USER="${startup_r_libs_user}"
      return 0
    fi
  fi
  return 1
}

function resolve_r_lib {
  # Resolve conversion specifiers without loading user-controlled startup
  # files. The shared utility keeps this in sync with src/clir.R.
  # shellcheck disable=SC2016
  CLIR_ROOT="${CLIR_ROOT}" R --vanilla --slave -e '
    source(file.path(Sys.getenv("CLIR_ROOT"), "src", "util.R"));
    env <- Sys.getenv(c("R_LIBS", "R_LIBS_USER"));
    names(env) <- c("R_LIBS", "R_LIBS_USER");
    cat(resolve_r_library(
      clir_root_dir = Sys.getenv("CLIR_ROOT"),
      env = env
    ));
  '
}

set +u
if [[ ${SYSTEM_INSTALL} -ne 0 ]]; then
  if [[ -n "${R_LIBS_USER}" && "${R_LIBS_USER}" != 'NULL' ]]; then
    export R_LIBS_USER
  elif [[ -n "${R_LIBS}" && "${R_LIBS}" != 'NULL' ]]; then
    export R_LIBS
  else
    # Root installation must not derive a privileged library from user
    # startup files. Use the R version from an isolated probe instead.
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
elif [[ -n "${R_LIBS_USER}" && "${R_LIBS_USER}" != 'NULL' ]]; then
  export R_LIBS_USER
elif [[ -n "${R_LIBS}" && "${R_LIBS}" != 'NULL' ]]; then
  # R combines R_LIBS before R_LIBS_USER; preserve the user library.
  export R_LIBS
elif use_r_startup_library; then
  :
else
  [[ -n "${R_VERSION}" ]] || abort 'Failed to determine the R version.'
  export R_LIBS_USER="${CLIR_ROOT}/r/${R_VERSION}/library"
fi
set -u

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

LIB_DIR=$(resolve_r_lib)

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
  R --no-environ --no-site-file --no-init-file --no-save --no-restore \
    --no-echo -q <<'EOF' || abort 'Package installation failed.'
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
if [[ ${SYSTEM_INSTALL} -ne 0 ]]; then
  R_ENVIRON=/dev/null R_ENVIRON_USER=/dev/null \
    R_PROFILE=/dev/null R_PROFILE_USER=/dev/null \
    "${CLIR_ROOT}/bin/clir" install --no-upgrade docopt yaml pak
  R_ENVIRON=/dev/null R_ENVIRON_USER=/dev/null \
    R_PROFILE=/dev/null R_PROFILE_USER=/dev/null \
    "${CLIR_ROOT}/bin/clir" validate docopt yaml pak
else
  "${CLIR_ROOT}/bin/clir" install --no-upgrade docopt yaml pak
  "${CLIR_ROOT}/bin/clir" validate docopt yaml pak
fi
echo

echo '>>> Done.'
if [[ ${SYSTEM_INSTALL} -eq 0 ]]; then
  echo "Add ${CLIR_ROOT}/bin to PATH."
  echo "The clir library is ${LIB_DIR}."
  echo 'If you use Zsh, update ~/.zshrc; otherwise update ~/.bash_profile.'
  echo 'For more information, see https://github.com/dceoy/clir'
fi
