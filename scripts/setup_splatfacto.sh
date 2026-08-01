#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git
require_command conda

if ! conda env list | awk '{print $1}' | grep -Fxq "${NERFSTUDIO_ENV_NAME}"; then
  conda create --name "${NERFSTUDIO_ENV_NAME}" --yes python=3.10 pip
fi

conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install --upgrade pip setuptools wheel
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "torch==${PYTORCH_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  "torchvision==${TORCHVISION_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  --extra-index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_SUFFIX}"
conda install --name "${NERFSTUDIO_ENV_NAME}" --yes \
  -c nvidia/label/cuda-11.8.0 cuda-toolkit
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install ninja
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch"
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install "nerfstudio==${NERFSTUDIO_VERSION}"
conda_run "${NERFSTUDIO_ENV_NAME}" python -c \
  "import torch; print(f'PyTorch {torch.__version__}; CUDA available: {torch.cuda.is_available()}')"
conda_run "${NERFSTUDIO_ENV_NAME}" ns-train --help >/dev/null

echo "Nerfstudio ${NERFSTUDIO_VERSION} is ready in Conda environment ${NERFSTUDIO_ENV_NAME}."
