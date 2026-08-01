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

- `vipe`: ViPE v1.2.0 and its upstream CUDA 12.8 environment.
- `nerfstudio`: Nerfstudio v1.1.5, PyTorch 2.1.2, and CUDA toolkit 11.8.

This follows ViPE's official Conda-based installation and keeps its compiled
dependencies separate from Nerfstudio. Docker is not the primary workflow:
ViPE does not publish a matching official image, while the Nerfstudio image
uses a different CUDA stack. A container can be added after the native GPU
pipeline has been validated.

Pinned versions live in [`configs/versions.env`](configs/versions.env).

## Requirements

- Ubuntu Linux with an NVIDIA GPU and a driver compatible with CUDA 12.8
- Conda or Miniconda
- Git
- Python 3
- FFmpeg and FFprobe
- At least 20 GB of free disk space for environments and generated artifacts

The target laptop has an RTX 4070 with limited VRAM, so the initial pipeline
uses 1600 px frames and ViPE's `no_vda` configuration.

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

### 1. Check the machine

```bash
./scripts/check_environment.sh gpu
```

Save the output for the final reproducibility report.

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
1600 px width.

### 3. Install pinned GPU environments

```bash
make setup-vipe
make setup-splatfacto
```

The upstream ViPE checkout is stored under `.cache/vipe` and verified against
the pinned release commit. Both setup commands are safe to rerun.

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
