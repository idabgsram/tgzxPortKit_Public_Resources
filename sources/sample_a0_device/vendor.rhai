// sources/sample_a0_device/vendor.rhai
//
// Since DEVICE_USE_IMAGE in the device config includes 'vendor', this vendor
// image starts as the TARGET device's vendor, not the source's. This file
// adjusts vendor in source-agnostic ways.

log("Stamping source identity on vendor build.prop");
chmod("build.prop", "666");
write_prop("build.prop", "ro.sample.source.codename", SOURCE_NAME);
