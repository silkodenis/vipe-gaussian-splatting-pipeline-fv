#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

mode="${1:-smoke}"
if [[ "${mode}" != "smoke" && "${mode}" != "full" ]]; then
  echo "Usage: $0 [smoke|full]" >&2
  exit 2
fi

require_conda
"${SCRIPT_DIR}/validate_splat.sh" "${mode}"

dataset_name="${DATASET_NAME:-zavod70}"
experiment="${dataset_name}"
if [[ "${mode}" == "smoke" ]]; then
  experiment="${dataset_name}-smoke"
fi
run_root="${PROJECT_ROOT}/artifacts/splatfacto/${experiment}/splatfacto"
config="$(find "${run_root}" -mindepth 2 -maxdepth 2 -type f -name config.yml -print | LC_ALL=C sort | tail -n 1)"

conda_cuda_run "${NERFSTUDIO_ENV_NAME}" ns-viewer \
  --load-config "${config}" \
  --viewer.websocket-host 0.0.0.0
