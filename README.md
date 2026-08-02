# ViPE Gaussian Splatting Pipeline

![3D scene reconstruction with camera path](readme_assets/results/3d_scene_with_camera_path.jpeg)

[▶ Watch the 3D reconstruction video on YouTube](https://youtu.be/_hh4plcQX_4)

This project transforms an ordered sequence of aerial images into an interactive
3D Gaussian Splatting scene. Camera parameters and trajectory are recovered with
NVIDIA ViPE, while Nerfstudio Splatfacto is used for reconstruction,
visualization, and video rendering.

## Built With

- **NVIDIA ViPE** — camera pose and intrinsic estimation
- **COLMAP format** — camera, image, and point-cloud interchange
- **Nerfstudio Splatfacto** — 3D Gaussian Splatting training and rendering
- **PyTorch and CUDA** — GPU-accelerated inference and optimization
- **FFmpeg** — image-sequence preprocessing and video generation
- **Python, Bash, Make, and Conda** — automation and reproducible environments

Tested end-to-end on a local server running **Ubuntu 26.04** with an
**NVIDIA GeForce RTX 4050 Laptop GPU and 6 GB of VRAM**.

## Quick Start

### 1. Clone the Repository

On the remote machine:

```bash
git clone git@github.com:silkodenis/vipe-gaussian-splatting-pipeline-fv.git
cd vipe-gaussian-splatting-pipeline-fv
```

### 2. Set Up the Environment

On the remote machine, from the repository root:

```bash
make bootstrap  # Install system dependencies and project-local Conda
make check      # Validate the host system and NVIDIA GPU
make setup      # Install the pinned ViPE and Splatfacto environments
make diagnose   # Validate both GPU environments
```

### 3. Upload the Dataset

On the local machine containing the dataset:

*Update the paths and remote connection details below for your environment.*

```bash
LOCAL_ZIP="/path/to/zavod70-20260801T082255Z-1-001.zip"
REMOTE_USER="<user>"
REMOTE_HOST="<host-or-ip>"
REMOTE_REPO="/absolute/path/to/vipe-gaussian-splatting-pipeline-fv"

scp "${LOCAL_ZIP}" \
  "${REMOTE_USER}@${REMOTE_HOST}:/tmp/zavod70-dataset.zip"

ssh "${REMOTE_USER}@${REMOTE_HOST}" \
  "mkdir -p '${REMOTE_REPO}/data/input/zavod70' && \
   unzip -j -n /tmp/zavod70-dataset.zip '*.jpg' \
     -d '${REMOTE_REPO}/data/input/zavod70'"
```

### 4. Inspect and Prepare the Dataset

On the remote machine, from the repository root:

```bash
make inspect
make prepare
```

The commands validate all 126 source images and create:

- `data/interim/zavod70-smoke.mp4`
- `data/interim/zavod70.mp4`
