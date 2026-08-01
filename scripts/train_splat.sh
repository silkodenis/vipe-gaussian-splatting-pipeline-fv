#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

mode="${1:-smoke}"
start_mode="${2:-fresh}"
if [[ "${mode}" != "smoke" && "${mode}" != "full" ]] || \
  [[ "${start_mode}" != "fresh" && "${start_mode}" != "resume" ]]; then
  echo "Usage: $0 [smoke|full] [fresh|resume]" >&2
  exit 2
fi

require_conda
dataset_name="${DATASET_NAME:-zavod70}"
sequence_name="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  sequence_name="${dataset_name}-smoke"
fi
data="${PROJECT_ROOT}/artifacts/colmap/${mode}/${sequence_name}"
output="${PROJECT_ROOT}/artifacts/splatfacto"

if [[ ! -s "${data}/cameras.txt" || ! -d "${data}/images" ]]; then
  echo "COLMAP dataset is incomplete: ${data}" >&2
  exit 1
fi

if [[ "${mode}" == "smoke" ]]; then
  target_iterations=3000
  experiment="${dataset_name}-smoke"
else
  target_iterations=30000
  experiment="${dataset_name}"
fi

mkdir -p "${output}"
iterations="${target_iterations}"
load_args=()
run_root="${output}/${experiment}/splatfacto"

if [[ "${start_mode}" == "resume" ]]; then
  if [[ ! -d "${run_root}" ]]; then
    echo "No Splatfacto run directory is available to resume: ${run_root}" >&2
    echo "Start a new run with: make splat-${mode}" >&2
    exit 1
  fi
  checkpoint="$(
    find "${run_root}" -mindepth 3 -maxdepth 3 -type f -name 'step-*.ckpt' -print 2>/dev/null \
      | LC_ALL=C sort \
      | tail -n 1
  )"
  if [[ -z "${checkpoint}" || ! -s "${checkpoint}" ]]; then
    echo "No checkpoint is available to resume under ${run_root}" >&2
    echo "Start a new run with: make splat-${mode}" >&2
    exit 1
  fi

  checkpoint_name="$(basename -- "${checkpoint}")"
  checkpoint_step="${checkpoint_name#step-}"
  checkpoint_step="${checkpoint_step%.ckpt}"
  checkpoint_step=$((10#${checkpoint_step}))
  next_step=$((checkpoint_step + 1))

  if (( next_step >= target_iterations )); then
    echo "Checkpoint already reached the ${target_iterations}-iteration target: ${checkpoint}"
    "${SCRIPT_DIR}/validate_splat.sh" "${mode}"
    exit 0
  fi

  # Nerfstudio interprets max-num-iterations as an additional count when a
  # checkpoint is loaded. Subtract the already completed steps so the resumed
  # run still ends at the original absolute target.
  iterations=$((target_iterations - next_step))
  load_args=(--load-dir "$(dirname -- "${checkpoint}")")
  echo "Resuming Splatfacto ${mode} from step ${checkpoint_step}: ${checkpoint}"
  echo "Running ${iterations} additional iterations to absolute step $((target_iterations - 1))."
fi

memory_args=()
if [[ "${mode}" == "full" ]]; then
  # The verified 6 GiB RTX 4050 cannot hold GPU-cached full-resolution images
  # while Splatfacto continues densifying past roughly 7,200 steps. Keep image
  # bytes in system RAM, freeze the Gaussian population before that point, and
  # use smaller viewer chunks. The remaining iterations still optimize the
  # existing Gaussians, opacity, scale, rotation, and spherical harmonics.
  memory_args=(
    --pipeline.datamanager.cache-images cpu
    --pipeline.model.stop-split-at "${SPLAT_FULL_STOP_SPLIT_AT:-6000}"
    --viewer.num-rays-per-chunk "${SPLAT_VIEWER_RAYS_PER_CHUNK:-8192}"
  )
fi

conda_cuda_run "${NERFSTUDIO_ENV_NAME}" env \
  PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-max_split_size_mb:128}" \
  ns-train splatfacto \
  --output-dir "${output}" \
  --experiment-name "${experiment}" \
  --max-num-iterations "${iterations}" \
  "${load_args[@]}" \
  "${memory_args[@]}" \
  --viewer.quit-on-train-completion True \
  colmap \
  --data "${data}" \
  --colmap-path . \
  --images-path . \
  --downscale-factor 1

"${SCRIPT_DIR}/validate_splat.sh" "${mode}"
