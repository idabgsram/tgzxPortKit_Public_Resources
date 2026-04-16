# Source ROM images

Drop the **source ROM's super.img** here (or the individual partition images
if your ROM ships them separately).

Expected filename matches `SOURCE_IMAGE_FILE` in `../config`; for the sample
that's `super.img`.

If your source ships **per-partition** images instead (`system.img`,
`system_ext.img`, `vendor.img`, etc.), drop them in and leave out
`super.img` — the pipeline auto-detects which mode you're in.

Example layout:

```
images/
├── super.img          ← preferred, single blob
└── (or these 5 instead:)
    ├── system.img
    ├── system_ext.img
    ├── product.img
    ├── vendor.img
    └── sample_region.img
```

All of these are big and live in the root `.gitignore` — they won't be
committed by accident.
