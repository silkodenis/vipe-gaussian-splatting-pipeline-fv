#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git
require_conda

tcnn_dir="${PROJECT_ROOT}/.cache/tiny-cuda-nn"

if ! conda_exec env list | awk '{print $1}' | grep -Fxq "${NERFSTUDIO_ENV_NAME}"; then
  conda_exec create --name "${NERFSTUDIO_ENV_NAME}" --yes python=3.10 pip
fi

conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install --upgrade pip
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install "numpy==${NUMPY_VERSION}"
conda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "torch==${PYTORCH_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  "torchvision==${TORCHVISION_VERSION}+${PYTORCH_CUDA_SUFFIX}" \
  --extra-index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_SUFFIX}"
conda_exec install --name "${NERFSTUDIO_ENV_NAME}" --yes \
  --channel nvidia/label/cuda-11.8.0 --channel conda-forge \
  cuda-toolkit gcc_linux-64=11 gxx_linux-64=11
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install \
  "setuptools==${SETUPTOOLS_VERSION}" \
  "wheel==${WHEEL_VERSION}" \
  "ninja==${NINJA_VERSION}"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c \
  "import pkg_resources; print('tiny-cuda-nn build prerequisite: pkg_resources OK')"

if [[ ! -d "${tcnn_dir}/.git" ]]; then
  git clone --recursive "${TINY_CUDA_NN_REPOSITORY}" "${tcnn_dir}"
fi
git -C "${tcnn_dir}" checkout --detach "${TINY_CUDA_NN_COMMIT}"
git -C "${tcnn_dir}" submodule sync --recursive
git -C "${tcnn_dir}" submodule update --init --recursive
actual_tcnn_commit="$(git -C "${tcnn_dir}" rev-parse HEAD)"
if [[ "${actual_tcnn_commit}" != "${TINY_CUDA_NN_COMMIT}" ]]; then
  echo "tiny-cuda-nn commit mismatch: expected ${TINY_CUDA_NN_COMMIT}, got ${actual_tcnn_commit}" >&2
  exit 1
fi

nerfstudio_prefix="$(conda_run "${NERFSTUDIO_ENV_NAME}" python -c 'import sys; print(sys.prefix)')"
cuda_stub="$(find "${nerfstudio_prefix}" -path '*/stubs/libcuda.so' -print -quit)"
if [[ -z "${cuda_stub}" ]]; then
  echo "CUDA driver link stub not found under ${nerfstudio_prefix}. Re-run the CUDA toolkit installation." >&2
  exit 1
fi
cuda_stub_dir="$(dirname -- "${cuda_stub}")"
tcnn_marker="${tcnn_dir}/.installed-${TINY_CUDA_NN_COMMIT}-${NERFSTUDIO_ENV_NAME}"

# tiny-cuda-nn still imports pkg_resources from setup.py. Build isolation would
# install current Setuptools (>=82), from which pkg_resources was removed.
# Reuse the completely pinned build toolchain installed above instead. The
# CUDA driver stub is exposed only to the linker; runtime resolves libcuda.so.1
# from the host NVIDIA driver.
if [[ -f "${tcnn_marker}" ]] && conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c "import tinycudann"; then
  echo "tiny-cuda-nn ${TINY_CUDA_NN_COMMIT} is already installed."
else
  MAX_JOBS="${TCNN_MAX_JOBS}" conda_cuda_run "${NERFSTUDIO_ENV_NAME}" env \
    "TCNN_CUDA_ARCHITECTURES=${TCNN_CUDA_ARCHITECTURES}" \
    "LIBRARY_PATH=${cuda_stub_dir}${LIBRARY_PATH:+:${LIBRARY_PATH}}" \
    python -m pip install --no-build-isolation \
    "${tcnn_dir}/bindings/torch"
  conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c "import tinycudann"
  printf '%s\n' "${TINY_CUDA_NN_COMMIT}" >"${tcnn_marker}"
fi
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip install "nerfstudio==${NERFSTUDIO_VERSION}"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -m pip check
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" python -c \
  "import torch; print(f'PyTorch {torch.__version__}; CUDA available: {torch.cuda.is_available()}')"
conda_cuda_run "${NERFSTUDIO_ENV_NAME}" ns-train --help >/dev/null

echo "Nerfstudio ${NERFSTUDIO_VERSION} is ready in Conda environment ${NERFSTUDIO_ENV_NAME}."
