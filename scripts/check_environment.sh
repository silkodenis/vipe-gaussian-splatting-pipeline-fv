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

missing=()
for command_name in git python3 ffmpeg ffprobe; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    missing+=("${command_name}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing preprocessing commands: ${missing[*]}" >&2
fi

command -v git >/dev/null 2>&1 && echo "Git:     $(git --version)"
command -v python3 >/dev/null 2>&1 && echo "Python:  $(python3 --version)"
command -v ffmpeg >/dev/null 2>&1 && echo "FFmpeg:  $(ffmpeg -version | head -n 1)"

if command -v free >/dev/null 2>&1; then
  free -h
fi
df -h "${PROJECT_ROOT}"

if [[ "${mode}" == "preprocess" ]]; then
  if (( ${#missing[@]} > 0 )); then
    echo "Run scripts/bootstrap_ubuntu.sh on the Ubuntu host." >&2
    exit 1
  fi
  echo "Preprocessing prerequisites are available."
  exit 0
fi

gpu_errors=0
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "GPU stages require Linux; run this script on the Ubuntu host." >&2
  gpu_errors=1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "Missing GPU command: nvidia-smi" >&2
  gpu_errors=1
else
  nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap \
    --format=csv,noheader

  memory_mib="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | tr -d ' ')"
  if [[ "${memory_mib}" =~ ^[0-9]+$ ]] && (( memory_mib < 7500 )); then
    echo "Warning: less than 7.5 GiB VRAM detected; reduce input width before ViPE." >&2
  fi
fi

if [[ -z "${CONDA_BIN}" || ! -x "${CONDA_BIN}" ]]; then
  echo "Missing Conda. Run scripts/bootstrap_ubuntu.sh." >&2
  gpu_errors=1
else
  echo "Conda:   $("${CONDA_BIN}" --version)"
fi

if command -v gcc >/dev/null 2>&1; then
  echo "Host:    $(gcc --version | head -n 1)"
fi

if (( ${#missing[@]} > 0 || gpu_errors != 0 )); then
  echo "Environment is incomplete. Run scripts/bootstrap_ubuntu.sh and retry." >&2
  exit 1
fi

echo "GPU prerequisites are available."
