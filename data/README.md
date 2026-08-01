# Local data layout

This directory contains machine-local inputs and generated intermediates.
Source images below `input/zavod70/` and everything below `raw/`, `interim/`,
and `processed/` are ignored by Git.

```text
data/
├── input/zavod70/          # user-supplied DJI JPEGs
├── raw/zavod70/
│   ├── images/frame_0001.jpg
│   └── manifest.json
├── interim/
│   ├── zavod70-smoke.mp4
│   └── zavod70.mp4
└── processed/
```

Place the 126 `zavod70` source JPEGs directly under `input/zavod70/`; do not
create another nested dataset directory. Source images contain GPS coordinates
and equipment identifiers in EXIF and XMP metadata. Git ignores every file in
that directory except `.gitkeep`.
