// ============================================================================
//  sources/sample_a0_device/system.rhai — source-side system patches
// ============================================================================
// Runs BEFORE the device-level system.rhai. This is where you normalise
// ROM-specific junk, kill OEM bloat, and rip out anything that would break
// on a different device.
//
// All the same variables + functions as the device script are available.
// See base_devices/sdk0/sample_device/system.rhai for the full reference.

let root = if IS_SAR == "true" { "system/" } else { "" };

// ── Remove the OEM's marketing splash ──────────────────────────────────────
// rm() is recursive for directories. It silently succeeds if the target is
// already missing.
log("Removing OEM bloatware");
rm(root + "app/SampleMarketing");
rm(root + "priv-app/SampleStoreClient");
rm(root + "media/bootanimation.zip");

// ── Strip OEM security props that don't apply to other devices ─────────────
log("Cleaning device-specific security props");
sed(root + "build.prop", `^ro\.sample\.security\.enforced=1`, "ro.sample.security.enforced=0");

// ── Add a build-time SELinux rule every device in the family needs ─────────
log("Adding source-wide SELinux rule");
append(root + "etc/selinux/plat_sepolicy.cil", `
; sample_a0_device: let zygote read /data/sample_shared
(allow zygote sample_data_file (dir (read search open getattr)))
(allow zygote sample_data_file (file (read open getattr)))
`);
chcon(root + "etc/selinux/plat_sepolicy.cil", "u:object_r:sepolicy_file:s0");

// ── Relocate a file the OEM put in the wrong place ─────────────────────────
// Nothing stops you from using exists() to guard an operation — cheap way
// to avoid noisy warnings when the source already looks like you want.
if exists(root + "etc/sample/old-config.xml") {
    log("Migrating legacy config path");
    cp("system/etc/sample/old-config.xml",
       root + "etc/sample/config.xml");
    rm(root + "etc/sample/old-config.xml");
    chcon(root + "etc/sample/config.xml", "u:object_r:system_file:s0");
}

log("system.rhai (sample_a0_device) done");
