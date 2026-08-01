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
"${SCRIPT_DIR}/validate_splat.sh" "${mode}"

dataset_name="${DATASET_NAME:-zavod70}"
experiment="${dataset_name}"
sequence_name="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  experiment="${dataset_name}-smoke"
  sequence_name="${dataset_name}-smoke"
fi

run_root="${PROJECT_ROOT}/artifacts/splatfacto/${experiment}/splatfacto"
checkpoint="$(
  find "${run_root}" -mindepth 3 -maxdepth 3 -type f -name 'step-*.ckpt' -print \
    | LC_ALL=C sort \
    | tail -n 1
)"
load_config="$(dirname -- "$(dirname -- "${checkpoint}")")/config.yml"
camera_path_dir="${PROJECT_ROOT}/artifacts/colmap/${mode}/${sequence_name}/camera_paths"

if [[ ! -d "${camera_path_dir}" ]]; then
  echo "Camera-path directory not found: ${camera_path_dir}" >&2
  echo "Run make view-splat-${mode}, then click RENDER -> Generate Command." >&2
  exit 1
fi

if [[ -n "${CAMERA_PATH_FILE:-}" ]]; then
  camera_path="$(absolute_path "${CAMERA_PATH_FILE}")"
else
  camera_path="$(
    find "${camera_path_dir}" -maxdepth 1 -type f \
      -name '20??-??-??-??-??-??.json' -print 2>/dev/null \
      | LC_ALL=C sort \
      | tail -n 1
  )"
fi

if [[ -z "${camera_path}" || ! -s "${camera_path}" ]]; then
  echo "No generated Viewer path found under ${camera_path_dir}" >&2
  echo "Run make view-splat-${mode}, then click RENDER -> Generate Command." >&2
  exit 1
fi

render_name="$(basename -- "${camera_path}" .json)"
output="${PROJECT_ROOT}/renders/${dataset_name}/${render_name}.mp4"

conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python "${SCRIPT_DIR}/render_camera_path.py" \
  --load-config "${load_config}" \
  --camera-path "${camera_path}" \
  --output "${output}"

echo "Rendered video: ${output}"
