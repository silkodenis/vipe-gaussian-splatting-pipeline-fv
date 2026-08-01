#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This bootstrap supports Linux x86_64 only." >&2
  exit 1
fi
if [[ ! -f /etc/os-release ]]; then
  echo "Cannot identify the Linux distribution." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This bootstrap supports Ubuntu only; detected: ${ID:-unknown}." >&2
  exit 1
fi

echo "Installing reproducible system prerequisites..."
sudo apt-get update
sudo apt-get install --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  ffmpeg \
  git \
  ninja-build \
  pkg-config \
  unzip \
  zip

miniforge_root="${XDG_DATA_HOME:-${HOME}/.local/share}/vipe-gs/miniforge3"
if [[ ! -x "${miniforge_root}/bin/conda" ]]; then
  installer="$(mktemp -t miniforge.XXXXXX.sh)"
  trap 'rm -f "${installer}"' EXIT
  installer_url="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh"

  echo "Downloading Miniforge ${MINIFORGE_VERSION}..."
  curl --fail --location --show-error --silent "${installer_url}" --output "${installer}"
  printf '%s  %s\n' "${MINIFORGE_LINUX_X86_64_SHA256}" "${installer}" | sha256sum --check --status
  bash "${installer}" -b -p "${miniforge_root}"
fi

"${miniforge_root}/bin/conda" config --set auto_activate_base false
"${miniforge_root}/bin/conda" --version

echo
echo "Bootstrap complete. No shell restart is required by the project scripts."
echo "Next command: ./scripts/check_environment.sh gpu"
