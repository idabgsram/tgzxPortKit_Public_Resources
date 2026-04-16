// sources/sample_a0_device/product.rhai
//
// Source-side product cleanup. Runs BEFORE the target device's product.rhai.

log("Neutralising OEM product props");
chmod("etc/build.prop", "666");
sed("etc/build.prop", `^ro\.sample\.oem\.branding=.*`, "ro.sample.oem.branding=generic");

// Any region partition merged into /system/sample_region gets these touches.
if exists("sample_region/etc/region.prop") {
    log("Forcing region=WW on merged sample_region");
    write_prop("sample_region/etc/region.prop", "ro.sample.region", "WW");
}
