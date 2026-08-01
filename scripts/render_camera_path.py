#!/usr/bin/env python3
"""Render a Viewer path while enforcing versioned project crop settings."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

from nerfstudio.scripts.render import RenderCameraPath


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--load-config", type=Path, required=True)
    parser.add_argument("--camera-path", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--settings", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    load_config = args.load_config.expanduser().resolve()
    camera_path = args.camera_path.expanduser().resolve()
    output = args.output.expanduser().resolve()
    settings_path = args.settings.expanduser().resolve()
    for path in (load_config, camera_path, settings_path):
        if not path.is_file():
            raise FileNotFoundError(path)

    payload = json.loads(camera_path.read_text(encoding="utf-8"))
    if not payload.get("camera_path"):
        raise ValueError(f"Camera path has no rendered frames; use Viewer Generate Command first: {camera_path}")

    settings = yaml.safe_load(settings_path.read_text(encoding="utf-8"))["render"]["dataset_path"]
    crop = settings["crop"]
    red, green, blue = (int(value) for value in crop["background_rgb"])
    payload["crop"] = {
        "crop_center": [float(value) for value in crop["center"]],
        "crop_scale": [float(value) for value in crop["scale"]],
        "crop_rot": [float(value) for value in crop["rotation"]],
        "crop_bg_color": {"r": red, "g": green, "b": blue},
    }

    effective_path = camera_path.with_name(f"{camera_path.stem}.project.json")
    effective_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Viewer path: {camera_path}")
    print(f"Effective path: {effective_path}")
    print(f"Crop background: RGB({red}, {green}, {blue})")
    print(f"Output: {output}")
    RenderCameraPath(
        load_config=load_config,
        camera_path_filename=effective_path,
        output_path=output,
    ).main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
