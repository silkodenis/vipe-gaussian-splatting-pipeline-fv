# ViPE Gaussian Splatting Demo

Reproducible reconstruction of the `zavod70` DJI image sequence with NVIDIA
ViPE and Gaussian Splatting.

The pipeline estimates camera intrinsics and poses with ViPE, recovers scale
with a compact metric-depth prior, exports the ViPE SLAM map to COLMAP text
format, trains a Nerfstudio Splatfacto model, and renders a short camera-path
video.

## Pipeline

```text
DJI JPEG directory
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

The repository is private, so the machine must have a GitHub SSH key authorized
for it. These are the only commands required before dataset preparation:

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

The full 126-frame ViPE and COLMAP stages are verified too. They consumed every
prepared frame and produced 126 poses, one camera (`fx=fy=953.60`, `cx=640`,
`cy=480`), and 326,047 initialization points. The first full Splatfacto attempt
reached step 7,291 before its default Gaussian densification exceeded the
RTX 4050's 5.64 GiB of usable VRAM. The full preset now uses system-RAM image
caching, stops densification at step 6,000, reduces viewer chunks, and supports
checkpoint continuation. Final completion of the revised full run is pending
verification.

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

## Dataset directory

The dataset is distributed separately and must not be committed to Git. After
obtaining the `zavod70` dataset through the authorized channel, place its JPEG
images directly in the repository's existing input directory:

```text
data/input/zavod70/
├── dji_20250111171148_0001_v.jpg
├── dji_20250111171149_0002_v.jpg
├── ...
└── dji_20250111171353_0126_v.jpg
```

Do not add another nested `zavod70` directory. The images must be immediate
children of `data/input/zavod70/`. Their contents are ignored by Git; only the
hidden `.gitkeep` placeholder is versioned.

Then verify and prepare the sequence from the repository root:

```bash
make inspect
make prepare
```

Expected source identity:

| Property | Expected value |
| --- | --- |
| Ordered JPEG content SHA-256 | `e8f7dbe4ae97d225ef9b6daa1ff742e69459a8941f6bf6a546e0a1da2456ac9e` |
| Files | 126 contiguous JPEG frames, indices 1 through 126 |
| Uncompressed bytes | 1,074,302,976 |

The content checksum covers the ordered frame indices and all JPEG bytes. Do
not continue if it or the frame range differs. To intentionally use another
authorized sequence, copy `.env.example` to `.env` and update
`DATASET_INPUT_DIR` together with all five `EXPECTED_*` identity fields;
document its checksum and provenance in the final report.

The verified preparation result on Ubuntu is:

| Output | Resolution | FPS | Frames |
| --- | --- | --- | --- |
| `data/interim/zavod70-smoke.mp4` | 1280×960 | 1 | 20 |
| `data/interim/zavod70.mp4` | 1280×960 | 1 | 126 |

The input JPEGs, normalized copies, manifest, and MP4 files remain local and
are covered by `.gitignore`. Both `make inspect` and `make prepare` enforce the
content checksum, frame count and range, and byte count shown above; a
different sequence fails before any GPU stage starts.

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

Preparation verifies the complete directory, checks that frame indices are
contiguous, preserves the source JPEG bytes, records a manifest, and creates:

```text
data/interim/zavod70-smoke.mp4  # first 20 frames
data/interim/zavod70.mp4        # all 126 frames
```

Both videos use 1 FPS to preserve the capture timing and are resized to
1280 px width. FFprobe validation is part of `make prepare`; the command fails
if width, FPS, or frame counts differ from the expected 20/126 frames.

To override defaults, copy `.env.example` to `.env` and edit the values before
running `make`. The local `.env` file is ignored by Git. The example also
documents the reference GPU's Splatfacto memory limits; keep those defaults for
a 6 GiB card.

### 3. Install pinned GPU environments

```bash
make setup
make diagnose
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

The combined targets above run these explicit component commands in order:

```bash
make setup-vipe
make setup-splatfacto
make diagnose-vipe
make diagnose-splatfacto
```

### 4. Run the smoke pipeline

```bash
make pipeline-smoke
make validate-splat-smoke
```

`make pipeline-smoke` sequentially runs `make vipe-smoke`,
`make colmap-smoke`, and `make splat-smoke`; it stops immediately if any stage
fails. The final training wrapper already validates its checkpoint, while the
explicit validation command is retained as a clean-room acceptance check.

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
make pipeline-full
make validate-splat-full
```

`make pipeline-full` sequentially runs `make vipe-full`, `make colmap-full`,
and `make splat-full`. On a clean checkout this is a new run; use the resume
target only after an interrupted run has produced a checkpoint.

The full preset is deliberately sized for the verified 6 GiB RTX 4050. It
keeps source images in CPU memory, stops adding/splitting Gaussians at step
6,000, and continues optimizing the retained Gaussians through step 29,999.
The viewer remains available, but avoid leaving a live high-resolution view
rendering during this low-VRAM run.

Nerfstudio saves a checkpoint every 2,000 steps. If training is interrupted or
runs out of memory, do not restart the completed iterations. Pull the latest
project revision and resume the newest checkpoint with:

```bash
git pull --ff-only
make resume-splat-full
make validate-splat-full
make view-splat-full
```

The resume wrapper calculates the remaining iteration count because
Nerfstudio treats `--max-num-iterations` as an *additional* count after loading
a checkpoint. For example, `step-000006000.ckpt` resumes at 6,001 and runs
23,999 more iterations, ending at the original target step 29,999. A resumed
run is written to a new timestamped directory; the source checkpoint is kept.

### 6. Render the demo

Open the Nerfstudio viewer through an SSH tunnel, create a camera path, and
export it as `configs/camera_path.json`. Then run:

```bash
./scripts/render_demo.sh \
  artifacts/splatfacto/zavod70/splatfacto/<run-id>/config.yml
```

The result is written to `renders/zavod70-demo.mp4`.

## Clean-room acceptance sequence

Run this from a new directory on Ubuntu to test the repository exactly as a
reviewer would. The `zavod70` JPEG sequence is the only input supplied outside
Git:

```bash
git clone git@github.com:silkodenis/vipe-gaussian-splatting-pipeline-fv.git
cd vipe-gaussian-splatting-pipeline-fv

./scripts/bootstrap_ubuntu.sh
make check

# Place the 126 JPEGs directly under data/input/zavod70/ first.
make inspect
make prepare

make setup
make diagnose
make pipeline-smoke
make validate-splat-smoke
make pipeline-full
make validate-splat-full
make view-splat-full
```

For SSH access to the viewer, establish the tunnel from the client machine
before `make view-splat-full`:

```bash
ssh -L 7007:localhost:7007 user@ubuntu-host
```

Apart from placing the source JPEGs in `data/input/zavod70/`, do not copy
`.cache`, `data/raw`, `data/interim`, or `artifacts` from an earlier checkout.
Their absence is what proves that dependency installation, preprocessing, and
all pipeline stages are reproducible from the documented inputs.

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
