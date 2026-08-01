#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSIONS_FILE="${PROJECT_ROOT}/configs/versions.env"

if [[ ! -f "${VERSIONS_FILE}" ]]; then
  echo "Missing versions file: ${VERSIONS_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${VERSIONS_FILE}"

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
fi

default_conda_root="${XDG_DATA_HOME:-${HOME}/.local/share}/vipe-gs/miniforge3"
CONDA_BIN="${CONDA_EXE_PATH:-}"
if [[ -z "${CONDA_BIN}" ]] && command -v conda >/dev/null 2>&1; then
  CONDA_BIN="$(command -v conda)"
fi
if [[ -z "${CONDA_BIN}" && -x "${default_conda_root}/bin/conda" ]]; then
  CONDA_BIN="${default_conda_root}/bin/conda"
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

absolute_path() {
  local value="$1"
  if [[ "${value}" = /* ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "${PROJECT_ROOT}/${value}"
  fi
}

conda_run() {
  local environment_name="$1"
  shift
  require_conda
  "${CONDA_BIN}" run --no-capture-output -n "${environment_name}" "$@"
}

conda_exec() {
  require_conda
  "${CONDA_BIN}" "$@"
}

require_conda() {
  if [[ -z "${CONDA_BIN}" || ! -x "${CONDA_BIN}" ]]; then
    echo "Conda not found. Run scripts/bootstrap_ubuntu.sh first." >&2
    exit 1
  fi
}

conda_cuda_run() {
  local environment_name="$1"
  shift
  conda_run "${environment_name}" env \
    CC=x86_64-conda-linux-gnu-cc \
    CXX=x86_64-conda-linux-gnu-c++ \
    CUDAHOSTCXX=x86_64-conda-linux-gnu-c++ \
    MAX_JOBS="${MAX_JOBS:-4}" \
    "$@"
}
