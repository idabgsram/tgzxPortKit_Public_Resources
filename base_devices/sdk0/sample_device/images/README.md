# Device images

Drop the target device's **stock factory images** here. The pipeline reads
these to learn what the vendor partition looks like on the target device
(needed so the ported ROM actually boots).

Typical shopping list for a modern A/B phone (all raw / non-sparse):

| file                | purpose                               |
|---------------------|---------------------------------------|
| `vendor_a.img`      | vendor partition                      |
| `vendor_dlkm_a.img` | vendor kernel module partition        |
| `odm_dlkm_a.img`    | ODM kernel module partition           |
| `system_a.img`      | only if you're also copying target system |
| `super.img`         | super (legacy; will be auto-extracted)|

The suffix `_a` reflects the A slot when `DEVICE_AB_SLOT=true` in `../config`.

If your source only has `super.img`, you can drop just that — the pipeline
splits it into per-partition images automatically.

> These files can be **huge** (GBs). They are listed in `.gitignore` at
> the repo root so you don't accidentally commit them.
