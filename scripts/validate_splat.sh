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

checkpoint="$(
  find "${run_root}" -mindepth 3 -maxdepth 3 -type f -name 'step-*.ckpt' -print \
    | LC_ALL=C sort \
    | tail -n 1
)"
if [[ -z "${checkpoint}" || ! -s "${checkpoint}" ]]; then
  echo "No non-empty Splatfacto checkpoint found under ${run_root}" >&2
  exit 1
fi

run_dir="$(dirname -- "$(dirname -- "${checkpoint}")")"
config="${run_dir}/config.yml"
if [[ ! -s "${config}" ]]; then
  echo "Checkpoint has no matching non-empty config: ${config}" >&2
  exit 1
fi

checkpoint_name="$(basename -- "${checkpoint}")"
checkpoint_step="${checkpoint_name#step-}"
checkpoint_step="${checkpoint_step%.ckpt}"
checkpoint_step=$((10#${checkpoint_step}))
if [[ "${mode}" == "smoke" ]]; then
  expected_final_step=2999
else
  expected_final_step=29999
fi
if (( checkpoint_step < expected_final_step )); then
  echo "Splatfacto ${mode} checkpoint is incomplete: step ${checkpoint_step}, expected at least ${expected_final_step}." >&2
  echo "Continue it with: make resume-splat-${mode}" >&2
  exit 1
fi

echo "Validated Splatfacto ${mode} run"
echo "Config:     ${config}"
echo "Checkpoint: ${checkpoint}"
