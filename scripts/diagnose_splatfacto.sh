#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_conda

echo "Nerfstudio environment: ${NERFSTUDIO_ENV_NAME}"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" nvcc --version
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" x86_64-conda-linux-gnu-c++ --version | head -n 1
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c \
  "import importlib.metadata as m; import numpy, torch, tinycudann; print(f'Python environment: torch={torch.__version__}, numpy={numpy.__version__}, setuptools={m.version(\"setuptools\")}, tinycudann={m.version(\"tinycudann\")}, nerfstudio={m.version(\"nerfstudio\")}'); print(f'CUDA available: {torch.cuda.is_available()}; device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"none\"}')"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" ns-train --help >/dev/null
echo "Splatfacto diagnostics: OK"
