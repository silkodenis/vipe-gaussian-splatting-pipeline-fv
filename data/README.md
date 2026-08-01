# Local data layout

This directory contains machine-local data and generated intermediates.
Everything below `raw/`, `interim/`, and `processed/` is ignored by Git.

```text
data/
├── raw/zavod70/
│   ├── images/frame_0001.jpg
│   └── manifest.json
├── interim/
│   ├── zavod70-smoke.mp4
│   └── zavod70.mp4
└── processed/
```

The source images contain GPS coordinates and equipment identifiers in EXIF
and XMP metadata. Keep them out of the public repository.
