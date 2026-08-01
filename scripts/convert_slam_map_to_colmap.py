#!/usr/bin/env python3

"""Convert ViPE artifacts using its SLAM map without requiring dense depth.

ViPE v1.2.0's upstream converter checks for a depth ZIP unconditionally,
including when ``--use_slam_map`` selects a point-cloud path that never reads
that ZIP. This adapter reuses the pinned upstream conversion functions while
checking only the files that the SLAM-map path actually consumes.
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
from types import ModuleType

from vipe.utils.io import ArtifactPath


def load_upstream_converter(vipe_root: Path) -> ModuleType:
    source = vipe_root / "scripts" / "vipe_to_colmap.py"
    if not source.is_file():
        raise FileNotFoundError(f"Pinned ViPE converter not found: {source}")
    spec = importlib.util.spec_from_file_location("vipe_upstream_colmap", source)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load upstream converter: {source}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("vipe_path", type=Path)
    parser.add_argument("--vipe-root", type=Path, required=True)
    parser.add_argument("--sequence", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    upstream = load_upstream_converter(args.vipe_root.resolve())
    artifact = ArtifactPath(args.vipe_path.resolve(), args.sequence)
    required = {
        "RGB video": artifact.rgb_path,
        "poses": artifact.pose_path,
        "intrinsics": artifact.intrinsics_path,
        "SLAM map": artifact.slam_map_path,
    }
    missing = [f"{label}: {path}" for label, path in required.items() if not path.is_file()]
    if missing:
        raise FileNotFoundError("Required ViPE SLAM-map artifact(s) missing:\n" + "\n".join(missing))

    output = args.output.resolve() / args.sequence
    output.mkdir(parents=True, exist_ok=True)
    width, height = upstream.extract_frames(artifact, output)
    upstream.write_cameras_txt(output, artifact, width, height)
    upstream.write_images_txt(output, artifact)
    upstream.write_points3d_txt_from_slam_map(output, artifact)
    print(f"COLMAP conversion completed: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
