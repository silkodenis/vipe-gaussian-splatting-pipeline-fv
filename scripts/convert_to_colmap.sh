#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

mode="${1:-full}"
if [[ "${mode}" != "smoke" && "${mode}" != "full" ]]; then
  echo "Usage: $0 [smoke|full]" >&2
  exit 2
fi

require_command conda
dataset_name="${DATASET_NAME:-zavod70}"
sequence_name="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  sequence_name="${dataset_name}-smoke"
fi
vipe_dir="${PROJECT_ROOT}/.cache/vipe"
input="${PROJECT_ROOT}/artifacts/vipe/${mode}"
output_base="${PROJECT_ROOT}/artifacts/colmap/${mode}"

if [[ ! -d "${input}" ]]; then
  echo "ViPE result not found: ${input}" >&2
  exit 1
fi

conda_run "${VIPE_ENV_NAME}" python "${vipe_dir}/scripts/vipe_to_colmap.py" \
  "${input}" \
  --sequence "${sequence_name}" \
  --use_slam_map \
  --output "${output_base}"

result="${output_base}/${sequence_name}"
for required in cameras.txt images.txt points3D.txt; do
  if [[ ! -s "${result}/${required}" ]]; then
    echo "Missing or empty COLMAP file: ${result}/${required}" >&2
    exit 1
  fi
done

echo "COLMAP dataset: ${result}"
