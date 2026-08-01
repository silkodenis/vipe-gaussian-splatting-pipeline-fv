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

require_conda
require_command ffprobe
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

pushd "${vipe_dir}" >/dev/null
conda_cuda_run "${VIPE_ENV_NAME}" uv run python "${PROJECT_ROOT}/scripts/convert_slam_map_to_colmap.py" \
  "${input}" \
  --vipe-root "${vipe_dir}" \
  --sequence "${sequence_name}" \
  --output "${output_base}"
popd >/dev/null

result="${output_base}/${sequence_name}"
for required in cameras.txt images.txt points3D.txt; do
  if [[ ! -s "${result}/${required}" ]]; then
    echo "Missing or empty COLMAP file: ${result}/${required}" >&2
    exit 1
  fi
done

rgb_artifact="${input}/rgb/${sequence_name}.mp4"
expected_frames="$({ ffprobe \
  -v error \
  -count_frames \
  -select_streams v:0 \
  -show_entries stream=nb_read_frames \
  -of default=nokey=1:noprint_wrappers=1 \
  "${rgb_artifact}"; } | tr -d '[:space:]')"
image_files="$(find "${result}/images" -maxdepth 1 -type f -name 'frame_*.jpg' | wc -l | tr -d '[:space:]')"
image_records="$(awk '!/^#/ && NF { count++ } END { print count + 0 }' "${result}/images.txt")"
camera_records="$(awk '!/^#/ && NF { count++ } END { print count + 0 }' "${result}/cameras.txt")"
point_records="$(awk '!/^#/ && NF { count++ } END { print count + 0 }' "${result}/points3D.txt")"

if [[ ! "${expected_frames}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Could not determine frame count for ViPE RGB artifact: ${rgb_artifact}" >&2
  exit 1
fi
if [[ "${image_files}" -ne "${expected_frames}" || "${image_records}" -ne "${expected_frames}" ]]; then
  echo "COLMAP image count mismatch: expected=${expected_frames}, files=${image_files}, records=${image_records}" >&2
  exit 1
fi
if [[ "${camera_records}" -ne 1 ]]; then
  echo "Expected one COLMAP camera record, found ${camera_records}." >&2
  exit 1
fi
if [[ "${point_records}" -lt 1 ]]; then
  echo "COLMAP point cloud is empty: ${result}/points3D.txt" >&2
  exit 1
fi

echo "Validated COLMAP: cameras=${camera_records}, images=${image_records}, points=${point_records}"
echo "COLMAP dataset: ${result}"
