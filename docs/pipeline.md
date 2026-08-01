# Pipeline design

## Bootstrap contract

`scripts/bootstrap_ubuntu.sh` is the only supported manual entry point for a
fresh Ubuntu host. It installs required APT packages and a pinned Miniforge
installer whose SHA-256 digest is stored in `configs/versions.env`.

GPU libraries are not installed globally. ViPE and Nerfstudio use independent
Conda environments and independent CUDA-compatible host compilers.

ViPE v1.2.0 uses a two-layer environment: `envs/cu128.yml` supplies CUDA,
native libraries, and `uv`; `uv sync --frozen` creates `.cache/vipe/.venv`
from the release's committed `uv.lock`. Project commands therefore run through
both `conda run` and `uv run`.

This installation path is verified on the target RTX 4050 Laptop host. The
recorded runtime is Python 3.10.20, PyTorch 2.9.0+cu128, NVCC 12.8.61, and the
Conda GCC 14.4.0 host compiler; `torch.cuda.is_available()` returns `True`.

## Dataset contract

The input is a ZIP containing DJI JPEG files named with a four-digit frame
index. `prepare_dataset.py` requires one contiguous sequence and deliberately
rejects unexpected files. It writes normalized filenames without modifying
the JPEG payload, so EXIF/XMP remains available for diagnostics.

Prepared video parameters:

- 1 FPS, matching the source capture interval
- 1280 px width with preserved aspect ratio
- H.264, CRF 18, YUV 4:2:0
- 20-frame smoke video and a full 126-frame video

## ViPE stage

ViPE consumes MP4 files. The project uses the `no_vda` pipeline plus a
`low-vram` override profile on the 5.64 GiB target GPU. Instance segmentation
is disabled, initialization is serialized, `metric3d-small` supplies scale on
SLAM keyframes, dense depth post-processing is disabled, and the SLAM map is
saved. Frame acceptance remains controlled by ViPE's DROID motion filter; the
instance-segmentation cadence is unrelated to SLAM keyframe selection.

Before inference, the wrapper runs Hydra with `--cfg job` and writes the
resolved configuration to `composed-config.yaml` in the output directory.
This validates the complete override path without loading models or using GPU
memory.

Outputs required by the next stage are:

- RGB frame artifacts
- camera intrinsics
- camera-to-world poses
- saved SLAM map

The full run should only start after the smoke trajectory is coherent and the
SLAM-map point cloud contains recognizable scene geometry.

## COLMAP stage

The project adapter creates `cameras.txt`, `images.txt`, `points3D.txt`, and an
`images/` directory by reusing the pinned ViPE v1.2.0 conversion functions. It
uses the saved SLAM map and therefore does not require a dense-depth artifact.
The adapter exists because the upstream converter checks for a depth ZIP even
on its `--use_slam_map` branch, although that branch never reads the ZIP.

ViPE derives its sequence identifier from the MP4 stem. The wrappers therefore
use `zavod70-smoke` for smoke artifacts and `zavod70` for the full run.

The generated `images.txt` stores paths such as `images/frame_000000.jpg`.
For Nerfstudio, both `--colmap-path` and `--images-path` are therefore set to
`.` relative to the sequence root.

## Splatfacto stage

The smoke run trains for 3,000 iterations. The full run trains for 30,000.
Nerfstudio automatically loads the ViPE-generated point cloud to initialize
the Gaussian representation.

Before accepting the result, inspect:

- camera frustums and trajectory continuity;
- floaters around trees and roof edges;
- reconstruction of dark building interiors;
- snow-covered, weakly textured surfaces;
- novel views that remain close to the observed camera path.

## Rendering stage

Create the final path in the Nerfstudio viewer. Prefer a slow trajectory near
the original capture manifold; aggressive moves into unseen space will expose
holes and extrapolation artifacts. Export the path JSON and render it with
`scripts/render_demo.sh`.

## Execution records

For each successful run, record:

- Git commit of this repository;
- ViPE and Nerfstudio versions;
- Ubuntu, NVIDIA driver, and GPU model;
- commands and configuration overrides;
- wall-clock runtime and peak VRAM;
- representative screenshots and final video link.
