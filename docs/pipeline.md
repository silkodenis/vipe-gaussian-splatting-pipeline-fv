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

The separate Nerfstudio environment follows its v1.1.5 CUDA 11.8 installation
path. Project pins additionally constrain NumPy to 1.26.4 for PyTorch 2.1.2
and Setuptools to 80.9.0 because the pinned `tiny-cuda-nn` setup imports
`pkg_resources`, removed from Setuptools 82. `tiny-cuda-nn` is built from an
exact cached checkout without build isolation, targeting only compute
capability 8.9. The pinned commit is from the `tiny-cuda-nn` 1.7 development
line contemporary with Nerfstudio v1.1.5, avoiding an accidental dependency on
the newer 2.x API. The Conda CUDA driver stub directory is added to
`LIBRARY_PATH` for the link step only; it is deliberately excluded from
`LD_LIBRARY_PATH` so runtime loads the host driver's `libcuda.so.1`.

## Dataset contract

The input is `data/input/zavod70/`, containing DJI JPEG files named with a
four-digit frame index. `prepare_dataset.py` requires the images to be direct
children of that directory, requires one contiguous sequence, and deliberately
rejects nested directories or unexpected files. It writes normalized filenames
without modifying the JPEG payload, so EXIF/XMP remains available for
diagnostics.

The default Make targets enforce a SHA-256 over the ordered frame indices and
JPEG bytes, plus the frame count, first/last indices, and total byte count.
Both inspection and preparation fail on an identity mismatch. Alternative data
therefore requires an explicit, documented update of all `EXPECTED_*` values
in the local `.env`; changing only the directory is insufficient.

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

The wrapper probes the exact input frame count and sets the SLAM graph buffer
to `2N + 16` slots. ViPE can retain at most `N` accepted frames in pass 1 and
appends `N` frames in pass 2. For this dataset that means 56 smoke slots and
268 full-run slots instead of the upstream 1024-slot allocation. At ViPE's
internal 384×512 resolution, the upstream buffer reserves several GiB for RGB,
feature maps, GRU state, disparity, and masks even when those slots are unused.
The low-memory profiles also reduce `infill_chunk_size` from 16 to 4 to bound
temporary allocations during pass 2.

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

After conversion, the wrapper compares the RGB artifact's probed frame count
with both the extracted JPEG count and non-comment `images.txt` records. It
also requires exactly one camera and a non-empty `points3D.txt`, so a partial
conversion cannot silently proceed to training.

## Splatfacto stage

The smoke run trains for 3,000 iterations. The full run trains for 30,000.
Nerfstudio automatically loads the ViPE-generated point cloud to initialize
the Gaussian representation. During training the viewer is available on its
normal port, but `viewer.quit_on_train_completion=true` lets the automated
command return after the final checkpoint is written. The wrapper then requires
a non-empty `config.yml` and `step-*.ckpt`. `view_splat.sh` reopens the newest
validated run for interactive inspection.

On the 6 GiB reference GPU, the full preset caches image bytes in system RAM,
sets `stop_split_at=6000`, limits viewer chunks to 8,192 rays, and uses a
128 MiB PyTorch allocator split limit. This bounds memory after densification;
later iterations continue optimizing the fixed Gaussian population. Interrupted
runs are continued with `make resume-splat-full`. The wrapper locates the newest
checkpoint and converts the absolute 30,000-iteration target to Nerfstudio's
required additional iteration count.

Before accepting the result, inspect:

- camera frustums and trajectory continuity;
- floaters around trees and roof edges;
- reconstruction of dark building interiors;
- snow-covered, weakly textured surfaces;
- novel views that remain close to the observed camera path.

## Rendering stage

`make view-splat-full` uses the Nerfstudio dataparser API with `eval_mode=all`
to recover all 126 ordered camera poses, including the cameras held out by the
training/evaluation interval split. It converts them to editable Viewer
keyframes and preloads the path without modifying the installed Nerfstudio
package. The configured crop is applied to the interactive viewport and is
written into the final JSON by the Viewer's `Generate Command` action.
The default one-second transition matches the timestamp interval in every
source filename, producing a 125-second path from the 126 recovered cameras.

Prefer a slow trajectory near the original capture manifold; aggressive moves
into unseen space will expose holes and extrapolation artifacts. Edit the
preloaded spline as needed, export the final path JSON, and render it with
`scripts/render_demo.sh`.

## Execution records

For each successful run, record:

- Git commit of this repository;
- ViPE and Nerfstudio versions;
- Ubuntu, NVIDIA driver, and GPU model;
- commands and configuration overrides;
- wall-clock runtime and peak VRAM;
- representative screenshots and final video link.
