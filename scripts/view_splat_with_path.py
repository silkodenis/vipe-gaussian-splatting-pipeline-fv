#!/usr/bin/env python3
"""Start Nerfstudio Viewer with an editable camera path already loaded."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import viser.transforms as tf


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--load-config", type=Path, required=True)
    parser.add_argument("--camera-path", type=Path, required=True)
    parser.add_argument("--websocket-host", default="0.0.0.0")
    return parser.parse_args()


def install_path_loader(camera_path_file: Path) -> None:
    """Extend the pinned Viewer API in-process; no site-packages are modified."""
    from nerfstudio.viewer import render_panel
    from nerfstudio.viewer import viewer as viewer_module

    payload = json.loads(camera_path_file.read_text(encoding="utf-8"))
    original_camera_path_class = render_panel.CameraPath
    created_paths = []

    class PreloadedCameraPath(original_camera_path_class):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            created_paths.append(self)

    original_populate = render_panel.populate_render_tab

    def populate_with_path(server, config_path, datapath, control_panel=None):
        state = original_populate(server, config_path, datapath, control_panel)
        if len(created_paths) != 1:
            raise RuntimeError(f"Expected one Viewer camera path, found {len(created_paths)}")

        camera_path = created_paths.pop()
        camera_path.reset()
        camera_path.default_fov = np.deg2rad(payload.get("default_fov", 75.0))
        camera_path.default_transition_sec = float(payload.get("default_transition_sec", 1.0))
        camera_path.framerate = float(payload.get("fps", 30.0))
        camera_path.loop = bool(payload.get("is_cycle", False))
        camera_path.tension = float(payload.get("smoothness_value", 0.0))

        scale_ratio = viewer_module.VISER_NERFSTUDIO_SCALE_RATIO
        for frame in payload["keyframes"]:
            pose = tf.SE3.from_matrix(np.asarray(frame["matrix"], dtype=np.float64).reshape(4, 4))
            pose = tf.SE3.from_rotation_and_translation(
                pose.rotation() @ tf.SO3.from_x_radians(np.pi),
                pose.translation(),
            )
            camera_path.add_camera(
                render_panel.Keyframe(
                    position=pose.translation() * scale_ratio,
                    wxyz=pose.rotation().wxyz,
                    override_fov_enabled=True,
                    override_fov_rad=np.deg2rad(frame["fov"]),
                    override_time_enabled=frame.get("override_time_enabled", False),
                    override_time_val=frame.get("render_time", 0.0),
                    aspect=float(frame["aspect"]),
                    override_transition_enabled=frame.get("override_transition_enabled", False),
                    override_transition_sec=frame.get("override_transition_sec"),
                )
            )

        camera_path._duration_element.value = camera_path.compute_duration()
        camera_path.update_spline()

        crop = payload.get("crop")
        if crop is not None and control_panel is not None:
            color = crop["crop_bg_color"]
            control_panel.background_color = (int(color["r"]), int(color["g"]), int(color["b"]))
            control_panel._crop_center.value = tuple(float(value) for value in crop["crop_center"])
            control_panel._crop_scale.value = tuple(float(value) for value in crop["crop_scale"])
            control_panel._crop_rot.value = tuple(float(value) for value in crop.get("crop_rot", (0, 0, 0)))
            control_panel.crop_viewport = True

        viewer_settings = payload.get("viewer", {})
        if control_panel is not None and "max_resolution" in viewer_settings:
            control_panel._max_res.value = int(viewer_settings["max_resolution"])

        print(f"Preloaded {len(payload['keyframes'])} editable keyframes from {camera_path_file}")
        return state

    render_panel.CameraPath = PreloadedCameraPath
    render_panel.populate_render_tab = populate_with_path
    # viewer.py imports the function by name, so replace that binding as well.
    viewer_module.populate_render_tab = populate_with_path


def main() -> int:
    args = parse_args()
    config_path = args.load_config.expanduser().resolve()
    camera_path = args.camera_path.expanduser().resolve()
    if not config_path.is_file():
        raise FileNotFoundError(config_path)
    if not camera_path.is_file():
        raise FileNotFoundError(camera_path)

    install_path_loader(camera_path)

    from nerfstudio.scripts.viewer.run_viewer import RunViewer, ViewerConfigWithoutNumRays

    viewer_config = ViewerConfigWithoutNumRays(websocket_host=args.websocket_host)
    RunViewer(load_config=config_path, viewer=viewer_config).main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
