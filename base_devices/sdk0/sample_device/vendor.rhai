// ============================================================================
//  base_devices/sdk0/sample_device/vendor.rhai — vendor partition overrides
// ============================================================================
// Because this device lists `vendor` in DEVICE_USE_IMAGE, the vendor image
// starts as a verbatim copy of base_devices/.../images/vendor_a.img. We only
// stitch in the things that genuinely differ.

// vendor always sits at the partition root — no /system prefix.
log("Patching vendor build.prop density");
chmod("build.prop", "666");
write_prop("build.prop", "ro.vendor.build.fingerprint",
           "sample/sample_device/SAMPLE_X0:0/SAMPLE/" + BUILD_DATE + ":user/release-keys");

// Cross-partition copy: pull a file that actually lives in the SOURCE rom's
// other partition images. Prefix syntax is  "<partition_name>:<inner path>".
// The engine searches every partition image the pipeline has staged.
//
// Example (uncomment when needed):
//     cp("vendor_sdk31:etc/vintf/manifest.xml", "etc/vintf/manifest.xml");

// Conditional selinux policy
if BUILD_TYPE.starts_with("debug") {
    log("Adding permissive domain for sample_hal (debug only)");
    append("etc/selinux/vendor_sepolicy.cil", `
(permissive sample_hal_domain)
`);
    chcon("etc/selinux/vendor_sepolicy.cil", "u:object_r:vendor_configs_file:s0");
}

log("vendor.rhai (sample_device) done");
