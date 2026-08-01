# ViPE Gaussian Splatting Demo

Reproducible reconstruction of the `zavod70` DJI image sequence with NVIDIA
ViPE and Gaussian Splatting.

The pipeline estimates camera intrinsics, camera poses, and depth with ViPE,
exports the reconstruction to COLMAP text format, trains a Nerfstudio
Splatfacto model, and renders a short camera-path video.

## Pipeline

```text
DJI JPEG archive
  -> validated 1 FPS MP4
  -> ViPE camera poses and depth
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

The verified target laptop has an RTX 4050 Laptop GPU with 6141 MiB VRAM, so
the initial pipeline uses 1280 px frames and ViPE's `no_vda` configuration.

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

## Mac-to-Ubuntu workflow

Code and documentation are edited and committed on macOS. GPU commands run on
the Ubuntu machine over SSH.

```bash
# macOS
git push

# Ubuntu, through SSH
cd /path/to/FarsightVisionTestCase
git pull --ff-only
```

The dataset is not transferred through Git. Copy the archive separately:

```bash
scp zavod70-20260801T082255Z-1-001.zip \
  user@ubuntu-host:/path/to/FarsightVisionTestCase/
```

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
1280 px width.

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

Verify ViPE after installation with:

```bash
make diagnose-vipe
```

### 4. Run the smoke pipeline

```bash
make vipe-smoke
make colmap-smoke
make splat-smoke
```

Inspect camera poses, depth, the COLMAP point cloud, and GPU memory before
starting the full run.

### 5. Run the full pipeline

```bash
make vipe-full
make colmap-full
make splat-full
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
