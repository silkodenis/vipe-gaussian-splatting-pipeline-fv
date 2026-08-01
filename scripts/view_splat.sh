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
"${SCRIPT_DIR}/validate_splat.sh" "${mode}"

dataset_name="${DATASET_NAME:-zavod70}"
experiment="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  experiment="${dataset_name}-smoke"
fi
run_root="${PROJECT_ROOT}/artifacts/splatfacto/${experiment}/splatfacto"
checkpoint="$(
  find "${run_root}" -mindepth 3 -maxdepth 3 -type f -name 'step-*.ckpt' -print \
    | LC_ALL=C sort \
    | tail -n 1
)"
config="$(dirname -- "$(dirname -- "${checkpoint}")")/config.yml"
if [[ "${mode}" == "smoke" ]]; then
  data="${PROJECT_ROOT}/artifacts/colmap/smoke/${dataset_name}-smoke"
else
  data="${PROJECT_ROOT}/artifacts/colmap/full/${dataset_name}"
fi
camera_path="${data}/camera_paths/ordered-dataset-cameras.json"

camera_path_args=(
  --load-config "${config}" \
  --output "${camera_path}" \
  --settings "${PROJECT_ROOT}/configs/splatfacto.yaml"
)
if [[ -n "${CAMERA_PATH_STRIDE:-}" ]]; then
  camera_path_args+=(--keyframe-stride "${CAMERA_PATH_STRIDE}")
fi
if [[ -n "${CAMERA_PATH_TRANSITION_SECONDS:-}" ]]; then
  camera_path_args+=(--transition-seconds "${CAMERA_PATH_TRANSITION_SECONDS}")
fi
if [[ -n "${CAMERA_PATH_RENDER_WIDTH:-}" ]]; then
  camera_path_args+=(--render-width "${CAMERA_PATH_RENDER_WIDTH}")
fi
if [[ -n "${CAMERA_PATH_RENDER_HEIGHT:-}" ]]; then
  camera_path_args+=(--render-height "${CAMERA_PATH_RENDER_HEIGHT}")
fi
if [[ -n "${CAMERA_PATH_FPS:-}" ]]; then
  camera_path_args+=(--fps "${CAMERA_PATH_FPS}")
fi

conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python "${SCRIPT_DIR}/generate_camera_path.py" \
  "${camera_path_args[@]}"

conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python "${SCRIPT_DIR}/view_splat_with_path.py" \
  --load-config "${config}" \
  --camera-path "${camera_path}" \
  --websocket-host 0.0.0.0
