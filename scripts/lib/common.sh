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
  conda run --no-capture-output -n "${environment_name}" "$@"
}
