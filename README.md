# ViPE Gaussian Splatting Demo

Reproducible reconstruction of the `zavod70` DJI image sequence with NVIDIA
ViPE and Gaussian Splatting.

The pipeline estimates camera intrinsics and poses with ViPE, recovers scale
with a compact metric-depth prior, exports the ViPE SLAM map to COLMAP text
format, trains a Nerfstudio Splatfacto model, and renders a short camera-path
video.

## Pipeline

```text
DJI JPEG archive
  -> validated 1 FPS MP4
  -> ViPE camera poses and SLAM map
  -> COLMAP cameras, images, and point cloud
  -> Nerfstudio Splatfacto
  -> rendered demo video
```

The raw dataset, embedded GPS metadata, model weights, reconstructions, and
videos are intentionally excluded from Git.

## Environment strategy

The supported execution target is Ubuntu with an NVIDIA GPU. Two isolated
Conda environments are used:

- `vipe`: ViPE v1.2.0 native tooling and CUDA 12.8; the locked Python
  environment is managed by `uv` under `.cache/vipe/.venv`.
- `nerfstudio`: Nerfstudio v1.1.5, PyTorch 2.1.2, and CUDA toolkit 11.8.

This follows ViPE's official Conda-based installation and keeps its compiled
dependencies separate from Nerfstudio. Docker is not the primary workflow:
ViPE does not publish a matching official image, while the Nerfstudio image
uses a different CUDA stack. A container can be added after the native GPU
pipeline has been validated.

Pinned versions live in [`configs/versions.env`](configs/versions.env).

## Host requirements

- Ubuntu Linux with an NVIDIA GPU and a driver compatible with CUDA 12.8
- `sudo` access for the one-time bootstrap
- At least 20 GB of free disk space for environments and generated artifacts

The verified target laptop has an RTX 4050 Laptop GPU with 6141 MiB nominal
VRAM (5.64 GiB visible to PyTorch), so the project defaults to the reproducible
`low-vram` profile described below.

## Fresh Ubuntu checkout

These are the only commands required before dataset preparation:

```bash
git clone git@github.com:silkodenis/vipe-gaussian-splatting-pipeline-fv.git
cd vipe-gaussian-splatting-pipeline-fv
./scripts/bootstrap_ubuntu.sh
./scripts/check_environment.sh gpu
```

The bootstrap may request the user's `sudo` password for APT. It installs all
declared host packages and the project-local Conda distribution; do not install
Python or CUDA dependencies manually.

## Verified Ubuntu host

| Component | Detected value |
| --- | --- |
| OS | Ubuntu 26.04 LTS, Linux 7.0.0 x86_64 |
| GPU | NVIDIA GeForce RTX 4050 Laptop GPU |
| VRAM | 6141 MiB |
| Compute capability | 8.9 |
| NVIDIA driver | 595.71.05 |
| RAM / swap | 14 GiB / 4 GiB |
| FFmpeg | 8.0.1 |
| Conda | 26.3.2 (Miniforge) |
| System compiler | GCC 15.2.0 |

This host passed `scripts/check_environment.sh gpu`. The 6 GiB VRAM budget is
tight, so every GPU stage starts with a reduced-resolution smoke run.

The pinned ViPE installation has also been verified end-to-end on this host:

| Runtime component | Verified value |
| --- | --- |
| ViPE | 1.2.0, commit `95a8816947602ddc26fcb7a80bea4f9313059578` |
| Python | 3.10.20, managed by uv |
| PyTorch | 2.9.0+cu128 |
| CUDA visible to PyTorch | 12.8, available |
| NVCC | 12.8.61 |
| Conda host compiler | GCC 14.4.0 |
| uv | 0.12.1 |

The successful validation command is:

```bash
make diagnose-vipe
```

The 20-frame ViPE smoke run is also verified on this host with the default
`low-vram` profile. It used a 56-slot SLAM buffer, completed both SLAM passes,
reduced bundle-adjustment energy throughout optimization, and saved the RGB,
pose, intrinsics, metadata, and SLAM-map artifacts under
`artifacts/vipe/smoke`. With model weights already cached, the logged ViPE run
took approximately 20 seconds. Peak VRAM still needs to be recorded during the
full run.

The subsequent `make colmap-smoke` conversion is verified as well. It extracted
all 20 RGB frames, wrote 20 pose records and one PINHOLE camera with
`fx=fy=957.81`, `cx=640`, `cy=480`, and produced a non-empty SLAM-map point
cloud. The conversion wrapper validates these counts automatically before it
reports success. Upstream's `Extracted 19 frames` message refers to the final
zero-based frame index (frames 0 through 19), not a missing frame.

The complete Splatfacto smoke stage is verified on the same RTX 4050 host:
Nerfstudio 1.1.5, PyTorch 2.1.2+cu118, NumPy 1.26.4, `tinycudann` 1.7, CUDA
11.8, and GCC 11.4 all passed `make diagnose-splatfacto`. Training completed
all 3,000 iterations without an out-of-memory error; the final logged rate was
approximately 23.3 ms/iteration and 52.8 M rays/s.

## Mac-to-Ubuntu workflow

Code and documentation are edited and committed on macOS. GPU commands run on
the Ubuntu machine over SSH.

```bash
# macOS
git push

# Ubuntu, through SSH
cd /path/to/vipe-gaussian-splatting-pipeline-fv
git pull --ff-only
```

## Dataset archive

The dataset is distributed separately and must not be committed to Git. Obtain
the authorized archive from the dataset provider and place it in the repository
root with this exact default name:

```text
zavod70-20260801T082255Z-1-001.zip
```

For example, copy it from the development machine to the Ubuntu host:

```bash
scp zavod70-20260801T082255Z-1-001.zip \
  user@ubuntu-host:/path/to/vipe-gaussian-splatting-pipeline-fv/
```

Then verify and prepare it from the repository root:

```bash
test -f zavod70-20260801T082255Z-1-001.zip
sha256sum zavod70-20260801T082255Z-1-001.zip
make inspect
make prepare
```

Expected source identity:

| Property | Expected value |
| --- | --- |
| SHA-256 | `d17b0a89fcb59ea22e5d89de95beb9a36eb42a6119620b4959b35763bbece1c0` |
| Files | 126 contiguous JPEG frames, indices 1 through 126 |
| Uncompressed bytes | 1,074,302,976 |

Do not continue if the checksum or frame range differs. To use another archive,
copy `.env.example` to `.env` and set `DATASET_ARCHIVE`; document its checksum
and provenance in the final report.

The verified preparation result on Ubuntu is:

| Output | Resolution | FPS | Frames |
| --- | --- | --- | --- |
| `data/interim/zavod70-smoke.mp4` | 1280×960 | 1 | 20 |
| `data/interim/zavod70.mp4` | 1280×960 | 1 | 126 |

The source ZIP, extracted JPEGs, manifest, and MP4 files remain local and are
covered by `.gitignore`.

## Quick start on Ubuntu

### 1. Bootstrap and check the machine

```bash
./scripts/bootstrap_ubuntu.sh
./scripts/check_environment.sh gpu
```

The idempotent bootstrap installs the required Ubuntu packages and a pinned,
checksum-verified Miniforge distribution. It does not require manual Conda
activation or modification of shell startup files. Save the environment check
output for the final reproducibility report.

### 2. Inspect and prepare the dataset

```bash
make inspect
make prepare
```

Preparation verifies the complete ZIP, checks that frame indices are
contiguous, preserves the source JPEG bytes, records a manifest, and creates:

```text
data/interim/zavod70-smoke.mp4  # first 20 frames
data/interim/zavod70.mp4        # all 126 frames
```

Both videos use 1 FPS to preserve the capture timing and are resized to
1280 px width. FFprobe validation is part of `make prepare`; the command fails
if width, FPS, or frame counts differ from the expected 20/126 frames.

To override defaults, copy `.env.example` to `.env` and edit the values before
running `make`. The local `.env` file is ignored by Git.

### 3. Install pinned GPU environments

```bash
make setup-vipe
make setup-splatfacto
```

The upstream ViPE checkout is stored under `.cache/vipe` and verified against
the pinned release commit. ViPE is installed with the release's official
`envs/cu128.yml` plus `uv sync --frozen`, so `uv.lock` controls all Python
dependencies. Both setup commands are safe to rerun. They install
Conda-managed host compilers as well: GCC 14 for CUDA 12.8 and GCC 11 for CUDA
11.8, avoiding dependence on the host distribution's compiler.

The Nerfstudio environment also pins PyTorch 2.1.2+cu118, NumPy 1.26.4,
Setuptools 80.9.0, and the exact `tiny-cuda-nn` source commit. The Setuptools
pin is required because `tiny-cuda-nn` imports the legacy `pkg_resources`
module, which was removed in Setuptools 82. Its CUDA extension is built without
an isolated temporary environment, for compute capability 8.9 and with two
parallel compiler jobs. The pinned checkout and intermediate build files live
under `.cache/tiny-cuda-nn`, allowing failed or repeated builds to reuse local
state. The selected 1.7-era commit matches the period of the Nerfstudio v1.1.5
release rather than current `tiny-cuda-nn` 2.x. During linking only, the script
exposes Conda CUDA's `libcuda.so` stub; runtime continues to use the real NVIDIA
driver. A commit-specific marker avoids rebuilding an already verified local
extension. No package needs to be installed manually.

Verify both environments after installation with:

```bash
make diagnose-vipe
make diagnose-splatfacto
```

### 4. Run the smoke pipeline

```bash
make vipe-smoke
make colmap-smoke
make splat-smoke
make validate-splat-smoke
```

`make vipe-smoke` first performs a Hydra composition-only preflight and saves
the exact resolved job configuration as
`artifacts/vipe/smoke/composed-config.yaml`. Models and CUDA processing start
only if every override is valid.

The default `VIPE_PROFILE=low-vram` is designed for the verified RTX 4050. It
disables SAM/AOT/GroundingDINO instance masks and async prefetch, uses ViPE's
smaller `metric3d-small` keyframe prior to recover scale, skips dense depth
post-processing, reduces the dense-infill chunk to four frames, sizes the GPU
SLAM buffer from the probed video frame count, and saves the 3D-consistent SLAM
map used by the next stage. The allocation is `2 × frames + 16` slots: 56 for
the 20-frame smoke video and 268 for the 126-frame full video. This safely
covers both ViPE passes without its memory-heavy 1024-slot default.
This is intentional: ViPE's `no_vda` preset still loads `UniDepth-L`, which
runs out of memory while loading on this GPU before the first frame.

`make colmap-smoke` uses the pinned ViPE conversion functions but does not
require a dense-depth ZIP when converting from the SLAM map. This corrects an
upstream v1.2.0 precondition that checks for that unused file.
It then verifies one camera record, matching image-file and pose-record counts,
and at least one 3D point before allowing Splatfacto training to continue.

Training keeps the viewer available while optimization is running, saves the
final checkpoint, validates the newest config/checkpoint pair, and then exits
automatically. To inspect the trained smoke model again, run:

```bash
make view-splat-smoke
```

Stop the standalone viewer with `Ctrl+C` when inspection is complete.

For a GPU with substantially more memory, opt into the original masks and
dense-depth path explicitly:

```bash
VIPE_PROFILE=quality make vipe-smoke
```

If `metric3d-small` itself cannot fit after confirming that the GPU is idle,
use the minimum-memory fallback (the resulting reconstruction has arbitrary
global scale, which is acceptable to Splatfacto):

```bash
VIPE_PROFILE=pose-only make vipe-smoke
```

Inspect camera poses, the COLMAP point cloud, and GPU memory before starting
the full run. Use the same selected profile for smoke and full runs; the
default requires no environment override.

### 5. Run the full pipeline

```bash
make vipe-full
make colmap-full
make splat-full
make validate-splat-full
```

### 6. Render the demo

Open the Nerfstudio viewer through an SSH tunnel, create a camera path, and
export it as `configs/camera_path.json`. Then run:

```bash
./scripts/render_demo.sh \
  artifacts/splatfacto/zavod70/splatfacto/<run-id>/config.yml
```

The result is written to `renders/zavod70-demo.mp4`.

## Repository layout

```text
configs/      Reproducible parameters and pinned versions
scripts/      Setup, preprocessing, reconstruction, and render entry points
docs/         Pipeline details and troubleshooting notes
data/         Raw and processed inputs; ignored by Git
artifacts/    ViPE, COLMAP, and Splatfacto outputs; ignored by Git
renders/      Generated videos; ignored by Git
.cache/       Pinned upstream source checkouts; ignored by Git
```

See [`docs/pipeline.md`](docs/pipeline.md) for stage contracts and
[`docs/troubleshooting.md`](docs/troubleshooting.md) for recovery steps.

## Reproducibility policy

- Do not use unpinned upstream `main` branches.
- Keep ViPE and Nerfstudio in separate environments.
- Run the smoke pipeline before every full reconstruction on a new machine.
- Record `nvidia-smi`, environment exports, commands, runtimes, and peak VRAM.
- Never commit source imagery, EXIF/GPS metadata, checkpoints, or render output.

## Ubuntu 26.04 note

CUDA 12.8 officially qualifies Ubuntu through 24.04 and host GCC versions
through 14. Ubuntu 26.04 ships GCC 15 and is therefore outside that matrix.
The project mitigates the compiler mismatch with Conda-managed toolchains, but
the host OS remains an explicit compatibility risk. If an upstream binary
fails because of glibc or OS detection, the fallback is an Ubuntu 24.04 CUDA
container or an Ubuntu 24.04 host installation.
