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
  iterations=3000
  experiment="${dataset_name}-smoke"
else
  iterations=30000
  experiment="${dataset_name}"
fi

mkdir -p "${output}"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" ns-train splatfacto \
  --output-dir "${output}" \
  --experiment-name "${experiment}" \
  --max-num-iterations "${iterations}" \
  colmap \
  --data "${data}" \
  --colmap-path . \
  --images-path . \
  --downscale-factor 1
