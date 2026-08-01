#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_command git

mode="${1:-install}"
if [[ "${mode}" != "install" && "${mode}" != "--validate-only" ]]; then
  echo "Usage: $0 [--validate-only]" >&2
  exit 2
fi

vipe_dir="$(absolute_path "${VIPE_DIR_OVERRIDE:-.cache/vipe}")"
if [[ ! -d "${vipe_dir}/.git" ]]; then
  mkdir -p "$(dirname -- "${vipe_dir}")"
  git clone --branch "${VIPE_REF}" --depth 1 "${VIPE_REPOSITORY}" "${vipe_dir}"
fi

actual_commit="$(git -C "${vipe_dir}" rev-parse HEAD)"
if [[ "${actual_commit}" != "${VIPE_COMMIT_PREFIX}"* ]]; then
  echo "ViPE checkout mismatch: expected ${VIPE_COMMIT_PREFIX}, got ${actual_commit}" >&2
  exit 1
fi

environment_file="${vipe_dir}/envs/cu128.yml"
for required_file in "${environment_file}" "${vipe_dir}/uv.lock" "${vipe_dir}/pyproject.toml"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Pinned ViPE checkout has an unexpected layout; missing: ${required_file}" >&2
    exit 1
  fi
done

if [[ "${mode}" == "--validate-only" ]]; then
  echo "ViPE ${VIPE_REF} checkout and installation files are valid."
  exit 0
fi

require_conda

if ! conda_exec env list | awk '{print $1}' | grep -Fxq "${VIPE_ENV_NAME}"; then
  conda_exec env create --name "${VIPE_ENV_NAME}" --file "${environment_file}"
fi

conda_exec install --name "${VIPE_ENV_NAME}" --yes --channel conda-forge \
  gcc_linux-64=14 gxx_linux-64=14

pushd "${vipe_dir}" >/dev/null
conda_cuda_run "${VIPE_ENV_NAME}" uv sync --frozen
conda_cuda_run "${VIPE_ENV_NAME}" uv run python -c "import torch, vipe; print(f'ViPE import: OK; torch={torch.__version__}; cuda={torch.version.cuda}')"
conda_cuda_run "${VIPE_ENV_NAME}" uv run vipe --help >/dev/null
popd >/dev/null

echo "ViPE ${VIPE_REF} is ready in Conda environment ${VIPE_ENV_NAME}."
