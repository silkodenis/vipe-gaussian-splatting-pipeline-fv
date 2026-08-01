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

require_conda
dataset_name="${DATASET_NAME:-zavod70}"
vipe_dir="${PROJECT_ROOT}/.cache/vipe"

if [[ ! -f "${vipe_dir}/run.py" ]]; then
  echo "ViPE is not installed. Run scripts/setup_vipe.sh first." >&2
  exit 1
fi

if [[ "${mode}" == "smoke" ]]; then
  video="${PROJECT_ROOT}/data/interim/${dataset_name}-smoke.mp4"
else
  video="${PROJECT_ROOT}/data/interim/${dataset_name}.mp4"
fi
output="${PROJECT_ROOT}/artifacts/vipe/${mode}"

if [[ ! -f "${video}" ]]; then
  echo "Input video not found: ${video}" >&2
  exit 1
fi
mkdir -p "${output}"

pushd "${vipe_dir}" >/dev/null
conda_cuda_run "${VIPE_ENV_NAME}" python run.py \
  pipeline=no_vda \
  streams=raw_mp4_stream \
  "streams.base_path=${video}" \
  streams.frame_start=0 \
  streams.frame_end=1000 \
  streams.frame_skip=1 \
  pipeline.init.kf_gap_sec=1.0 \
  "pipeline.output.path=${output}" \
  pipeline.output.save_artifacts=true \
  pipeline.output.save_slam_map=true
popd >/dev/null

echo "ViPE ${mode} result: ${output}"
