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

## Steps to Reproduce

<details>
<summary><strong>1. Clone the Repository</strong></summary>

On the remote machine:

```bash
git clone git@github.com:silkodenis/vipe-gaussian-splatting-pipeline-fv.git
cd vipe-gaussian-splatting-pipeline-fv
```

</details>

<details>
<summary><strong>2. Set Up the Environment</strong></summary>

On the remote machine, from the repository root:

```bash
make bootstrap  # Install system dependencies and project-local Conda
make check      # Validate the host system and NVIDIA GPU
make setup      # Install the pinned ViPE and Splatfacto environments
make diagnose   # Validate both GPU environments
```

</details>

<details>
<summary><strong>3. Upload the Dataset</strong></summary>

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

</details>

<details>
<summary><strong>4. Inspect and Prepare the Dataset</strong></summary>

On the remote machine, from the repository root:

```bash
make inspect  # Validate the source images and dataset identity
make prepare  # Create the smoke and full ViPE input videos
```

The commands validate all 126 source images and create:

- `data/interim/zavod70-smoke.mp4`
- `data/interim/zavod70.mp4`

</details>

<details>
<summary><strong>5. Run the Full Reconstruction Pipeline</strong></summary>

On the remote machine, from the repository root:

```bash
make pipeline-full        # Run ViPE, COLMAP conversion, and Splatfacto training
make validate-splat-full  # Validate the trained model and final checkpoint
```

The commands produce and validate:

- ViPE camera poses and SLAM map
- COLMAP-compatible cameras, images, and point cloud
- trained Splatfacto model and final checkpoint

The generated artifacts are stored under:

- `artifacts/vipe/full/`
- `artifacts/colmap/full/zavod70/`
- `artifacts/splatfacto/zavod70/splatfacto/<run-timestamp>/`

</details>

<details>
<summary><strong>6. Review and Generate the Camera Path</strong></summary>

On the local machine, connect to the remote machine with Viewer port forwarding:

```bash
ssh -L 7007:localhost:7007 <user>@<host-or-ip>
```

In the remote SSH session, from the repository root:

```bash
make view-splat-full  # Open the trained model with the recovered camera path
```

Open [http://localhost:7007](http://localhost:7007), then:

1. Open the `RENDER` tab and review the preloaded camera path.
2. Adjust the keyframes or render settings if needed.
3. Click `Generate Command` to save the final camera-path JSON.
4. Do not copy or run the displayed `ns-render` command.
5. Stop the Viewer with `Ctrl+C`.

The generated camera path is stored under:

- `artifacts/colmap/full/zavod70/camera_paths/<timestamp>.json`

</details>

<details>
<summary><strong>7. Render the Video</strong></summary>

On the remote machine, from the repository root:

```bash
make render-splat-full  # Render the newest generated camera path
```

The final video is stored under:

- `renders/zavod70/<timestamp>.mp4`

</details>
