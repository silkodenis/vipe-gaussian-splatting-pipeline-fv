# Troubleshooting

## A prerequisite is missing

Do not install project packages one by one. Run the idempotent bootstrap and
then collect the complete diagnostic report:

```bash
./scripts/bootstrap_ubuntu.sh
./scripts/check_environment.sh gpu
```

The bootstrap installs system tools and a pinned Miniforge distribution. The
project scripts locate that Conda installation without requiring `conda init`.

## Ubuntu 26.04 or GCC 15 is detected

CUDA 12.8 officially supports host GCC versions only through 14 and does not
list Ubuntu 26.04 as a qualified distribution. The setup scripts install GCC
14 inside the ViPE environment and GCC 11 inside the Nerfstudio environment,
then explicitly select those compilers for CUDA extension builds.

If compilation still fails because of the host glibc or distribution version,
do not use `--allow-unsupported-compiler`. Use the planned Ubuntu 24.04 CUDA
container fallback instead.

## `nvidia-smi` is missing

Install or repair the proprietary NVIDIA driver before creating Python
environments. CUDA packages inside Conda do not replace the host driver.

## ViPE installation fails while compiling CUDA code

Confirm that the active driver supports CUDA 12.8, then check:

Run `make diagnose-vipe` to report the pinned commit, NVCC, the Conda host
compiler, uv, PyTorch, CUDA runtime visibility, and the ViPE CLI status.

Do not install ViPE into the Nerfstudio environment.

## `envs/base.yml` is missing

ViPE v1.2.0 uses `envs/cu128.yml`; `base.yml` belongs to a different repository
revision. Pull commit `fix: follow the ViPE v1.2.0 uv installation layout` and
rerun `make setup-vipe`. The existing pinned checkout is reused.

## ViPE runs out of GPU memory

1. Confirm that no other process is using the GPU with `nvidia-smi`.
2. Keep the `no_vda` pipeline.
3. Re-run dataset preparation with a smaller even width, for example 960.
4. Validate on the 20-frame smoke video before retrying the full sequence.

## Camera tracking is fragmented

The source drone moves about 9.4 m between adjacent captures. Inspect the
smoke visualization for pose jumps. If tracking fails, try a larger input
width before changing model settings. Do not silently remove failed frames;
record any filtering rule in the dataset manifest and README.

## COLMAP conversion cannot find artifacts

Ensure the ViPE run used both:

```text
pipeline.output.save_artifacts=true
pipeline.output.save_slam_map=true
```

Also verify the sequence name inside the ViPE output: `zavod70-smoke` for the
smoke video and `zavod70` for the full video.

## Nerfstudio cannot find images

ViPE writes image names with an `images/` prefix. The training wrapper handles
this using:

```text
--colmap-path . --images-path .
```

Run `scripts/train_splat.sh` instead of assembling the command manually.

## Viewer is not reachable over SSH

Forward the viewer port from macOS to Ubuntu. Use the port printed by
Nerfstudio, for example:

```bash
ssh -L 7007:localhost:7007 user@ubuntu-host
```

Then open the local URL printed by the training process.
