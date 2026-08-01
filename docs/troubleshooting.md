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

## `tiny-cuda-nn` cannot import `pkg_resources`

Setuptools removed `pkg_resources` in version 82, while the pinned
`tiny-cuda-nn` build script still imports it. Do not install packages by hand
and do not delete the partially created Conda environment. Pull the current
project revision and rerun:

```bash
make setup-splatfacto
make diagnose-splatfacto
```

The idempotent setup pins Setuptools 80.9.0 after the Conda CUDA transaction,
verifies the import, and builds the exact `tiny-cuda-nn` commit with
`--no-build-isolation`. `ns-train: No such file or directory` after this error
only means setup stopped before Nerfstudio itself was installed.

## `tiny-cuda-nn` linker cannot find `-lcuda`

The CUDA runtime wheels and the host driver normally provide `libcuda.so.1`,
while extension linking requires the unversioned `libcuda.so` name. Conda's
`cuda-driver-dev` package supplies a safe link stub under
`targets/x86_64-linux/lib/stubs`. The setup script discovers that file and
adds its directory to `LIBRARY_PATH` only for the `tiny-cuda-nn` build.

Do not add the stub directory to `LD_LIBRARY_PATH` and do not create system
symlinks: either can make runtime load a non-functional stub instead of the
real NVIDIA driver. Pull the fix and rerun `make setup-splatfacto`; the pinned
checkout under `.cache/tiny-cuda-nn` preserves intermediate build state for
subsequent attempts.

## `envs/base.yml` is missing

ViPE v1.2.0 uses `envs/cu128.yml`; `base.yml` belongs to a different repository
revision. Pull commit `fix: follow the ViPE v1.2.0 uv installation layout` and
rerun `make setup-vipe`. The existing pinned checkout is reused.

## ViPE runs out of GPU memory

1. Confirm that no other process is using the GPU with `nvidia-smi`.
2. Confirm the resolved config reports the default low-memory settings:

   ```bash
   grep -En "instance: null|keyframe_depth: metric3d-small|depth_align_model: null" \
     artifacts/vipe/smoke/composed-config.yaml
   ```

3. Retry the smoke run with `make vipe-smoke`. The default `low-vram` profile
   avoids the model-loading OOM caused by keeping SAM, AOT, GroundingDINO and
   `UniDepth-L` resident together. It also prints
   `ViPE SLAM buffer: 56 slots for 20 input frames`; if it reports 1024, the
   checkout is stale.
4. If loading `metric3d-small` still fails, run
   `VIPE_PROFILE=pose-only make vipe-smoke`. This removes metric scale recovery;
   relative geometry remains usable by COLMAP and Splatfacto.
5. Reduce `PREPARED_WIDTH` only if OOM occurs during frame processing. It does
   not solve an OOM raised by `self.model.cuda()` while weights are loading.

`PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` is not the fix for the
first observed log: only 17 MiB was free and the allocation failed while
loading model weights. A later run reached frame 13 with `metric3d-small` but
still used ViPE's 1024-slot SLAM buffer. The project now derives that buffer
from the video length, removing several GiB of unused preallocation rather
than depending on allocator tuning.

## Hydra rejects `pipeline.init.kf_gap_sec`

ViPE v1.2.0 nests this setting under the instance configuration. Pull commit
`fix: validate ViPE Hydra overrides before inference` and rerun
`make vipe-smoke`; the supported override is
`pipeline.init.instance.kf_gap_sec=1.0`. It is used only by the `quality`
profile because `low-vram` disables instance segmentation entirely. The
wrapper performs a composition preflight before loading any model.

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
smoke video and `zavod70` for the full video. The low-VRAM profile intentionally
does not create `depth/*.zip`; `scripts/convert_slam_map_to_colmap.py` checks
the RGB, poses, intrinsics, and SLAM map that this conversion path actually
uses.

## FFmpeg reports `not enough frames to estimate rate`

This warning can appear while ViPE saves the short 20-frame smoke artifact. It
is non-fatal when the log continues with `Saving SLAM map` and
`Finished processing zavod70-smoke`. Proceed with `make colmap-smoke`; that
command validates every artifact required by the SLAM-map conversion path.

## Nerfstudio cannot find images

ViPE writes image names with an `images/` prefix. The training wrapper handles
this using:

```text
--colmap-path . --images-path .
```

Run `scripts/train_splat.sh` instead of assembling the command manually.

## Training finished but the command still shows `Use ctrl+c to quit`

The checkpoint is already safe once Nerfstudio prints `Training Finished`.
Older project revisions left the embedded viewer running after training; press
`Ctrl+C`, pull the current revision, and validate the completed run without
retraining:

```bash
make validate-splat-smoke
```

Current training commands set `viewer.quit_on_train_completion=True`, validate
the final config/checkpoint automatically, and return to the shell. Use
`make view-splat-smoke` when an interactive viewer is wanted later.

## Viewer is not reachable over SSH

Forward the viewer port from macOS to Ubuntu. Use the port printed by
Nerfstudio, for example:

```bash
ssh -L 7007:localhost:7007 user@ubuntu-host
```

Then open the local URL printed by the training process.

For an already trained smoke model, start the viewer with
`make view-splat-smoke`; for the full model use `make view-splat-full`.
