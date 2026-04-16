# Source+device release overlays

Images here get merged into the release OTA zip in addition to the
device-level overlays at
`base_devices/sdk0/sample_device/release/dynamic_zip/images/`.

Use this directory when the image is tied to a **specific source +
target device** combination, e.g. a boot image that only makes sense
when building sample_a0_device onto sample_device.
