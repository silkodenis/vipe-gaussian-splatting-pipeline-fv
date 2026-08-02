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
