# Device-level dynamic_zip overlay images

Anything you drop here gets packed into the release OTA zip and written
directly to the named partition via `package_extract_file(...)` in
updater-script. Common use: `boot.img`, `dtbo.img`, `vbmeta.img`, vendor
firmware blobs, bootloader images.

1. Edit `../config` to map `<filename> = <partition_name>`.
2. Drop the file here with the exact `<filename>` you used.
3. Rebuild in release mode — it'll be in the OTA.

The images go in UNCOMPRESSED and are streamed as-is to `/dev/block/by-name/<partition>`.
