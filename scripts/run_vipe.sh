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
dataset_name="${DATASET_NAME:-zavod70}"
vipe_profile="${VIPE_PROFILE:-low-vram}"
vipe_dir="${PROJECT_ROOT}/.cache/vipe"

if [[ ! -f "${vipe_dir}/run.py" ]]; then
  echo "ViPE is not installed. Run scripts/setup_vipe.sh first." >&2
  exit 1
fi

if [[ "${mode}" == "smoke" ]]; then
  video="${PROJECT_ROOT}/data/interim/${dataset_name}-smoke.mp4"
else
  video="${PROJECT_ROOT}/data/interim/${dataset_name}.mp4"
fi
output="${PROJECT_ROOT}/artifacts/vipe/${mode}"

if [[ ! -f "${video}" ]]; then
  echo "Input video not found: ${video}" >&2
  exit 1
fi
mkdir -p "${output}"

vipe_args=(
  pipeline=no_vda
  streams=raw_mp4_stream
  "streams.base_path=${video}"
  streams.frame_start=0
  streams.frame_end=1000
  streams.frame_skip=1
  "pipeline.output.path=${output}"
  pipeline.output.save_artifacts=true
  pipeline.output.save_slam_map=true
)

case "${vipe_profile}" in
  low-vram)
    # The target RTX 4050 exposes only 5.64 GiB. Avoid keeping SAM, AOT,
    # GroundingDINO and a second depth network resident alongside SLAM.
    vipe_args+=(
      pipeline.init.instance=null
      pipeline.init.async_prefetch=false
      pipeline.init.prefetch_queue_size=1
      pipeline.slam.keyframe_depth=metric3d-small
      pipeline.post.depth_align_model=null
      pipeline.output.save_viz=false
    )
    ;;
  pose-only)
    # Emergency minimum-memory fallback. Its reconstruction has an arbitrary
    # global scale, which is acceptable for COLMAP/Splatfacto.
    vipe_args+=(
      pipeline.init.instance=null
      pipeline.init.async_prefetch=false
      pipeline.init.prefetch_queue_size=1
      pipeline.slam.keyframe_depth=null
      pipeline.post.depth_align_model=null
      pipeline.output.save_viz=false
    )
    ;;
  quality)
    vipe_args+=(pipeline.init.instance.kf_gap_sec=1.0)
    ;;
  *)
    echo "Unknown VIPE_PROFILE '${vipe_profile}'. Use low-vram, pose-only, or quality." >&2
    exit 2
    ;;
esac

pushd "${vipe_dir}" >/dev/null
config_path="${output}/composed-config.yaml"
config_tmp="${config_path}.tmp"
conda_cuda_run "${VIPE_ENV_NAME}" uv run python run.py \
  "${vipe_args[@]}" --cfg job >"${config_tmp}"
mv "${config_tmp}" "${config_path}"
echo "ViPE Hydra preflight: OK"
echo "ViPE profile: ${vipe_profile}"
conda_cuda_run "${VIPE_ENV_NAME}" uv run python run.py "${vipe_args[@]}"
popd >/dev/null

echo "ViPE ${mode} result: ${output}"
