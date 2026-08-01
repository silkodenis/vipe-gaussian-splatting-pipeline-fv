#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git
require_conda

if ! conda_exec env list | awk '{print $1}' | grep -Fxq "${NERFSTUDIO_ENV_NAME}"; then
  conda_exec create --name "${NERFSTUDIO_ENV_NAME}" --yes python=3.10 pip
fi

conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install --upgrade pip setuptools wheel
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "torch==${PYTORCH_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  "torchvision==${TORCHVISION_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  --extra-index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_SUFFIX}"
conda_exec install --name "${NERFSTUDIO_ENV_NAME}" --yes \
  --channel nvidia/label/cuda-11.8.0 --channel conda-forge \
  cuda-toolkit gcc_linux-64=11 gxx_linux-64=11
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install ninja
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install "nerfstudio==${NERFSTUDIO_VERSION}"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip check
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c \
  "import torch; print(f'PyTorch {torch.__version__}; CUDA available: {torch.cuda.is_available()}')"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" ns-train --help >/dev/null

echo "Nerfstudio ${NERFSTUDIO_VERSION} is ready in Conda environment ${NERFSTUDIO_ENV_NAME}."
