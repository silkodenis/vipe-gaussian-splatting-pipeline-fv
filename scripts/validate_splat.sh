#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

mode="${1:-smoke}"
if [[ "${mode}" != "smoke" && "${mode}" != "full" ]]; then
  echo "Usage: $0 [smoke|full]" >&2
  exit 2
fi

dataset_name="${DATASET_NAME:-zavod70}"
experiment="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  experiment="${dataset_name}-smoke"
fi
run_root="${PROJECT_ROOT}/artifacts/splatfacto/${experiment}/splatfacto"

if [[ ! -d "${run_root}" ]]; then
  echo "Splatfacto run directory not found: ${run_root}" >&2
  exit 1
fi

config="$(find "${run_root}" -mindepth 2 -maxdepth 2 -type f -name config.yml -print | LC_ALL=C sort | tail -n 1)"
if [[ -z "${config}" || ! -s "${config}" ]]; then
  echo "No non-empty Splatfacto config found under ${run_root}" >&2
  exit 1
fi

run_dir="$(dirname -- "${config}")"
checkpoint_dir="${run_dir}/nerfstudio_models"
if [[ ! -d "${checkpoint_dir}" ]]; then
  echo "Splatfacto checkpoint directory not found: ${checkpoint_dir}" >&2
  exit 1
fi
checkpoint="$(find "${checkpoint_dir}" -maxdepth 1 -type f -name 'step-*.ckpt' -print | LC_ALL=C sort | tail -n 1)"
if [[ -z "${checkpoint}" || ! -s "${checkpoint}" ]]; then
  echo "No non-empty Splatfacto checkpoint found under ${checkpoint_dir}" >&2
  exit 1
fi

echo "Validated Splatfacto ${mode} run"
echo "Config:     ${config}"
echo "Checkpoint: ${checkpoint}"
