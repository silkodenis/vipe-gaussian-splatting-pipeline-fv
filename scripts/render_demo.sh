#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 PATH_TO_NERFSTUDIO_CONFIG [PATH_TO_CAMERA_PATH]" >&2
  exit 2
fi

require_conda
load_config="$(absolute_path "$1")"
camera_path="$(absolute_path "${2:-configs/camera_path.json}")"
output="${PROJECT_ROOT}/renders/zavod70-demo.mp4"

if [[ ! -f "${load_config}" ]]; then
  echo "Nerfstudio config not found: ${load_config}" >&2
  exit 1
fi
if [[ ! -f "${camera_path}" ]]; then
  echo "Camera path not found: ${camera_path}" >&2
  echo "Create and export it from the Nerfstudio viewer first." >&2
  exit 1
fi

mkdir -p "$(dirname -- "${output}")"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python "${SCRIPT_DIR}/render_camera_path.py" \
  --load-config "${load_config}" \
  --camera-path "${camera_path}" \
  --output "${output}" \
  --settings "${PROJECT_ROOT}/configs/splatfacto.yaml"

echo "Demo video: ${output}"
