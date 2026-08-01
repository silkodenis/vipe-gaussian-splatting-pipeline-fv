#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

mode="${1:-gpu}"
if [[ "${mode}" != "gpu" && "${mode}" != "preprocess" ]]; then
  echo "Usage: $0 [gpu|preprocess]" >&2
  exit 2
fi

echo "Project: ${PROJECT_ROOT}"
echo "Kernel:  $(uname -srmo)"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "OS:      ${PRETTY_NAME}"
else
  echo "OS:      $(uname -s)"
fi

require_command git
require_command python3
require_command ffmpeg
require_command ffprobe

echo "Git:     $(git --version)"
echo "Python:  $(python3 --version)"
echo "FFmpeg:  $(ffmpeg -version | head -n 1)"

if command -v free >/dev/null 2>&1; then
  free -h
fi
df -h "${PROJECT_ROOT}"

if [[ "${mode}" == "preprocess" ]]; then
  echo "Preprocessing prerequisites are available."
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "GPU stages require Linux; run this script on the Ubuntu host." >&2
  exit 1
fi

require_command nvidia-smi
require_command conda

nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap \
  --format=csv,noheader

memory_mib="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')"
if [[ "${memory_mib}" =~ ^[0-9]+$ ]] && (( memory_mib < 7500 )); then
  echo "Warning: less than 7.5 GiB VRAM detected; reduce input width before ViPE." >&2
fi

echo "GPU prerequisites are available."
