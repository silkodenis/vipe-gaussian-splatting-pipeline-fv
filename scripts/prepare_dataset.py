#!/usr/bin/env python3
"""Validate the DJI archive, extract normalized frames, and create ViPE MP4 inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from fractions import Fraction
from pathlib import Path


FRAME_PATTERN = re.compile(r"_(\d{4})_v\.jpg$", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Google Drive ZIP archive")
    parser.add_argument("--project-root", type=Path, default=project_root)
    parser.add_argument("--dataset-name", default="zavod70")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--fps", type=float, default=1.0)
    parser.add_argument("--smoke-frames", type=int, default=20)
    parser.add_argument("--expected-sha256")
    parser.add_argument("--expected-frame-count", type=int)
    parser.add_argument("--expected-first-frame", type=int)
    parser.add_argument("--expected-last-frame", type=int)
    parser.add_argument("--expected-uncompressed-bytes", type=int)
    parser.add_argument(
        "--inspect-only",
        action="store_true",
        help="Validate and summarize the archive without extracting it",
    )
    return parser.parse_args()


def validate_expected_dataset(summary: dict[str, object], args: argparse.Namespace) -> None:
    expected = {
        "archive_sha256": args.expected_sha256,
        "frame_count": args.expected_frame_count,
        "first_frame_index": args.expected_first_frame,
        "last_frame_index": args.expected_last_frame,
        "uncompressed_bytes": args.expected_uncompressed_bytes,
    }
    mismatches = [
        f"{key}: got {summary[key]!r}, expected {value!r}"
        for key, value in expected.items()
        if value is not None and summary[key] != value
    ]
    if mismatches:
        raise ValueError("Dataset identity mismatch; " + "; ".join(mismatches))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_frames(archive: zipfile.ZipFile) -> list[tuple[int, zipfile.ZipInfo]]:
    frames: list[tuple[int, zipfile.ZipInfo]] = []
    for member in archive.infolist():
        if member.is_dir():
            continue
        match = FRAME_PATTERN.search(member.filename)
        if match is None:
            raise ValueError(f"Unexpected archive member: {member.filename}")
        frames.append((int(match.group(1)), member))

    frames.sort(key=lambda item: item[0])
    if not frames:
        raise ValueError("The archive contains no DJI JPEG frames")

    indices = [index for index, _ in frames]
    expected = list(range(indices[0], indices[-1] + 1))
    if indices != expected:
        missing = sorted(set(expected) - set(indices))
        raise ValueError(f"Frame sequence is not contiguous; missing: {missing}")
    return frames


def run_ffmpeg(
    images_dir: Path,
    output: Path,
    first_index: int,
    fps: float,
    width: int,
    frame_limit: int | None,
) -> None:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg is required to create ViPE input videos")

    output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "warning",
        "-y",
        "-framerate",
        str(fps),
        "-start_number",
        str(first_index),
        "-i",
        str(images_dir / "frame_%04d.jpg"),
        "-vf",
        f"scale={width}:-2:flags=lanczos",
    ]
    if frame_limit is not None:
        command.extend(["-frames:v", str(frame_limit)])
    command.extend(
        ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", str(output)]
    )
    subprocess.run(command, check=True)


def validate_video(output: Path, expected_width: int, expected_fps: float, expected_frames: int) -> dict[str, object]:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height,nb_frames,r_frame_rate",
        "-of",
        "json",
        str(output),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    payload = json.loads(result.stdout)
    streams = payload.get("streams", [])
    if len(streams) != 1:
        raise RuntimeError(f"Expected one video stream in {output}, found {len(streams)}")

    stream = streams[0]
    actual_width = int(stream["width"])
    actual_frames = int(stream["nb_frames"])
    actual_fps = float(Fraction(stream["r_frame_rate"]))
    if actual_width != expected_width:
        raise RuntimeError(f"Unexpected width in {output}: {actual_width}, expected {expected_width}")
    if actual_frames != expected_frames:
        raise RuntimeError(f"Unexpected frame count in {output}: {actual_frames}, expected {expected_frames}")
    if abs(actual_fps - expected_fps) > 1e-6:
        raise RuntimeError(f"Unexpected FPS in {output}: {actual_fps}, expected {expected_fps}")

    return {
        "path": str(output),
        "width": actual_width,
        "height": int(stream["height"]),
        "fps": actual_fps,
        "frames": actual_frames,
    }


def main() -> int:
    args = parse_args()
    archive_path = args.archive.expanduser().resolve()
    project_root = args.project_root.expanduser().resolve()

    if not archive_path.is_file():
        raise FileNotFoundError(archive_path)
    if args.width <= 0 or args.width % 2:
        raise ValueError("--width must be a positive even number")
    if args.fps <= 0:
        raise ValueError("--fps must be positive")
    if args.smoke_frames <= 0:
        raise ValueError("--smoke-frames must be positive")

    with zipfile.ZipFile(archive_path) as archive:
        bad_member = archive.testzip()
        if bad_member is not None:
            raise ValueError(f"Corrupt ZIP member: {bad_member}")
        frames = collect_frames(archive)
        total_bytes = sum(member.file_size for _, member in frames)
        summary = {
            "archive": archive_path.name,
            "archive_sha256": sha256(archive_path),
            "dataset": args.dataset_name,
            "frame_count": len(frames),
            "first_frame_index": frames[0][0],
            "last_frame_index": frames[-1][0],
            "uncompressed_bytes": total_bytes,
            "prepared_width": args.width,
            "capture_fps": args.fps,
        }

        print(json.dumps(summary, indent=2))
        validate_expected_dataset(summary, args)
        if args.inspect_only:
            return 0

        images_dir = project_root / "data" / "raw" / args.dataset_name / "images"
        if images_dir.exists() and any(images_dir.iterdir()):
            raise FileExistsError(
                f"Refusing to overwrite non-empty directory: {images_dir}. Remove it explicitly to rebuild."
            )
        images_dir.mkdir(parents=True, exist_ok=True)

        manifest_frames = []
        for index, member in frames:
            destination = images_dir / f"frame_{index:04d}.jpg"
            with archive.open(member) as source, destination.open("wb") as target:
                shutil.copyfileobj(source, target, length=8 * 1024 * 1024)
            manifest_frames.append(
                {
                    "index": index,
                    "source_name": member.filename,
                    "prepared_name": destination.name,
                    "bytes": member.file_size,
                    "crc32": f"{member.CRC:08x}",
                }
            )

    manifest = {
        **summary,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "frames": manifest_frames,
    }
    manifest_path = project_root / "data" / "raw" / args.dataset_name / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    interim_dir = project_root / "data" / "interim"
    smoke_frames = min(args.smoke_frames, len(frames))
    smoke_video = interim_dir / f"{args.dataset_name}-smoke.mp4"
    full_video = interim_dir / f"{args.dataset_name}.mp4"
    run_ffmpeg(
        images_dir,
        smoke_video,
        frames[0][0],
        args.fps,
        args.width,
        smoke_frames,
    )
    run_ffmpeg(
        images_dir,
        full_video,
        frames[0][0],
        args.fps,
        args.width,
        None,
    )
    videos = [
        validate_video(smoke_video, args.width, args.fps, smoke_frames),
        validate_video(full_video, args.width, args.fps, len(frames)),
    ]
    print(json.dumps({"validated_videos": videos}, indent=2))
    print(f"Prepared dataset under {project_root / 'data'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, FileExistsError, RuntimeError, ValueError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1) from error
