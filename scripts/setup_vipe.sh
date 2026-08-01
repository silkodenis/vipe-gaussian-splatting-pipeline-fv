#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git
require_conda

vipe_dir="${PROJECT_ROOT}/.cache/vipe"
if [[ ! -d "${vipe_dir}/.git" ]]; then
  mkdir -p "$(dirname -- "${vipe_dir}")"
  git clone --branch "${VIPE_REF}" --depth 1 "${VIPE_REPOSITORY}" "${vipe_dir}"
fi

actual_commit="$(git -C "${vipe_dir}" rev-parse HEAD)"
if [[ "${actual_commit}" != "${VIPE_COMMIT_PREFIX}"* ]]; then
  echo "ViPE checkout mismatch: expected ${VIPE_COMMIT_PREFIX}, got ${actual_commit}" >&2
  exit 1
fi

if ! conda_exec env list | awk '{print $1}' | grep -Fxq "${VIPE_ENV_NAME}"; then
  conda_exec env create --name "${VIPE_ENV_NAME}" --file "${vipe_dir}/envs/base.yml"
fi

conda_exec install --name "${VIPE_ENV_NAME}" --yes --channel conda-forge \
  gcc_linux-64=14 gxx_linux-64=14
conda_cuda_run "${VIPE_ENV_NAME}" python -m pip install \
  --requirement "${vipe_dir}/envs/requirements.txt" \
  --extra-index-url https://download.pytorch.org/whl/cu128
conda_cuda_run "${VIPE_ENV_NAME}" python -m pip install --no-build-isolation "${vipe_dir}"
conda_cuda_run "${VIPE_ENV_NAME}" python -m pip check
conda_cuda_run "${VIPE_ENV_NAME}" python -c "import vipe; print('ViPE import: OK')"

echo "ViPE ${VIPE_REF} is ready in Conda environment ${VIPE_ENV_NAME}."
