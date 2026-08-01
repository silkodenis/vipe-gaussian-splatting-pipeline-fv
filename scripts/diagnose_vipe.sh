#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_conda
vipe_dir="${PROJECT_ROOT}/.cache/vipe"
if [[ ! -f "${vipe_dir}/uv.lock" ]]; then
  echo "ViPE checkout is missing. Run make setup-vipe first." >&2
  exit 1
fi

echo "ViPE commit: $(git -C "${vipe_dir}" rev-parse HEAD)"
conda_cuda_run "${VIPE_ENV_NAME}" nvcc --version
conda_cuda_run "${VIPE_ENV_NAME}" x86_64-conda-linux-gnu-cc --version | head -n 1

pushd "${vipe_dir}" >/dev/null
conda_cuda_run "${VIPE_ENV_NAME}" uv --version
conda_cuda_run "${VIPE_ENV_NAME}" uv run python -c \
  "import torch, vipe; print(f'torch={torch.__version__}; torch_cuda={torch.version.cuda}; cuda_available={torch.cuda.is_available()}')"
conda_cuda_run "${VIPE_ENV_NAME}" uv run vipe --help >/dev/null
popd >/dev/null

echo "ViPE diagnostics passed."
