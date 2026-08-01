#!/usr/bin/env python3
"""Generate an editable Nerfstudio camera path from every ordered dataset pose."""

from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import yaml

from nerfstudio.engine.trainer import TrainerConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--load-config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--settings", type=Path, required=True)
    parser.add_argument("--keyframe-stride", type=int)
    parser.add_argument("--transition-seconds", type=float)
    parser.add_argument("--render-width", type=int)
    parser.add_argument("--render-height", type=int)
    parser.add_argument("--fps", type=float)
    return parser.parse_args()


def load_all_cameras(config_path: Path):
    """Use the pinned Nerfstudio dataparser API without loading the GPU model."""
    config = yaml.load(config_path.read_text(encoding="utf-8"), Loader=yaml.Loader)
    if not isinstance(config, TrainerConfig):
        raise TypeError(f"Unexpected Nerfstudio config type: {type(config)!r}")

    dataparser_config = copy.deepcopy(config.pipeline.datamanager.dataparser)
    if not hasattr(dataparser_config, "eval_mode"):
        raise TypeError("The trained model does not use a dataparser with eval_mode")

    # The training config uses an interval split. For the editable trajectory we
    # want every recovered pose, including the held-out evaluation cameras.
    dataparser_config.eval_mode = "all"
    dataparser = dataparser_config.setup()
    return dataparser.get_dataparser_outputs(split="train").cameras


def selected_indices(camera_count: int, stride: int) -> list[int]:
    if stride <= 0:
        raise ValueError("--keyframe-stride must be positive")
    indices = list(range(0, camera_count, stride))
    if indices[-1] != camera_count - 1:
        indices.append(camera_count - 1)
    return indices


def main() -> int:
    args = parse_args()
    config_path = args.load_config.expanduser().resolve()
    output = args.output.expanduser().resolve()
    settings_path = args.settings.expanduser().resolve()

    if not config_path.is_file():
        raise FileNotFoundError(config_path)
    if not settings_path.is_file():
        raise FileNotFoundError(settings_path)

    settings = yaml.safe_load(settings_path.read_text(encoding="utf-8"))["render"]["dataset_path"]
    crop = settings["crop"]
    keyframe_stride = args.keyframe_stride if args.keyframe_stride is not None else int(settings["keyframe_stride"])
    transition_seconds = (
        args.transition_seconds if args.transition_seconds is not None else float(settings["transition_seconds"])
    )
    render_width = args.render_width if args.render_width is not None else int(settings["resolution"][0])
    render_height = args.render_height if args.render_height is not None else int(settings["resolution"][1])
    fps = args.fps if args.fps is not None else float(settings["fps"])
    crop_center = tuple(float(value) for value in crop["center"])
    crop_scale = tuple(float(value) for value in crop["scale"])
    crop_rotation = tuple(float(value) for value in crop["rotation"])
    background_color = tuple(int(value) for value in crop["background_rgb"])

    if transition_seconds <= 0:
        raise ValueError("--transition-seconds must be positive")
    if render_width <= 0 or render_height <= 0 or fps <= 0:
        raise ValueError("Render dimensions and FPS must be positive")
    if any(value <= 0 for value in crop_scale):
        raise ValueError("Crop scale values must be positive")
    if any(value < 0 or value > 255 for value in background_color):
        raise ValueError("Background RGB values must be in [0, 255]")

    cameras = load_all_cameras(config_path)
    count = int(cameras.size)
    if count < 2:
        raise ValueError(f"At least two cameras are required, found {count}")

    indices = selected_indices(count, keyframe_stride)
    keyframes = []
    for index in indices:
        pose = cameras.camera_to_worlds[index].detach().cpu().numpy()
        matrix = [
            [float(pose[0, 0]), float(pose[0, 1]), float(pose[0, 2]), float(pose[0, 3])],
            [float(pose[1, 0]), float(pose[1, 1]), float(pose[1, 2]), float(pose[1, 3])],
            [float(pose[2, 0]), float(pose[2, 1]), float(pose[2, 2]), float(pose[2, 3])],
            [0.0, 0.0, 0.0, 1.0],
        ]
        width = float(cameras.width[index].item())
        height = float(cameras.height[index].item())
        fx = float(cameras.fx[index].item())
        fov_degrees = math.degrees(2.0 * math.atan(width / (2.0 * fx)))
        keyframes.append(
            {
                "matrix": [value for row in matrix for value in row],
                "fov": fov_degrees,
                "aspect": width / height,
                "override_transition_enabled": False,
                "override_transition_sec": None,
                "source_camera_index": index,
            }
        )

    default_fov = float(keyframes[0]["fov"])
    duration = transition_seconds * (len(keyframes) - 1)
    red, green, blue = background_color
    payload = {
        "default_fov": default_fov,
        "default_transition_sec": transition_seconds,
        "keyframes": keyframes,
        "camera_type": "perspective",
        "render_height": render_height,
        "render_width": render_width,
        "fps": fps,
        "seconds": duration,
        "is_cycle": False,
        "smoothness_value": 0.0,
        # The Viewer recomputes this dense list after the user edits the path.
        "camera_path": [],
        "crop": {
            "crop_center": list(crop_center),
            "crop_scale": list(crop_scale),
            "crop_rot": list(crop_rotation),
            "crop_bg_color": {"r": red, "g": green, "b": blue},
        },
        "source": {
            "type": "ordered-dataset-cameras",
            "camera_count": count,
            "keyframe_count": len(keyframes),
            "keyframe_stride": keyframe_stride,
        },
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Generated editable camera path: {output}")
    print(f"Dataset cameras: {count}; keyframes: {len(keyframes)}; duration: {duration:.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
