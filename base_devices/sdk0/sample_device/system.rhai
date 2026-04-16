// ============================================================================
//  base_devices/sdk0/sample_device/system.rhai
//  Target-device patch for the SYSTEM partition. Runs AFTER every source
//  script on the same partition, so it has final say over any conflict.
// ============================================================================
//
//  When this runs, the pipeline has already:
//    1. Built a fresh ext4 system.img from the source + target trees.
//    2. Run common/global/system.rhai and sources/<rom>/system.rhai.
//    3. (Optionally) run sources/<rom>/system.<device>.rhai.
//
//  Now it's our turn. Every function call here mutates the IN-MEMORY ext4
//  image; the pipeline flushes it to disk after the script finishes.
//
//  Variables provided by the pipeline
//  ----------------------------------
//    SOURCE_NAME        "sample_a0_device"
//    DEVICE_NAME        "sample_device"
//    TARGET_DEVICE      same as DEVICE_NAME (alias)
//    DEVICE_CODE        from config
//    FEATURE_CONFIG     DEVICE_FEATURE_CONFIG from config
//    DEVICE_CONFIG      alias of FEATURE_CONFIG
//    BUILD_TYPE         "debug" | "release" | "debug_avc" | "release_enforcing" | …
//    IS_SAR             "true" | "false" (DEVICE_SYSTEM_AS_ROOT)
//    SYSTEM_AS_ROOT     same as IS_SAR
//    VENDOR_SDK         from config
//    BUILD_DATE         "YYYYMMDD"
//    BUILD_TIME         "HHMMSS"
//    BUILDER_NAME       OS user
//    BUILDER_MACHINE    "tgzxPortKitV3"
//
//  Path convention inside the image
//  --------------------------------
//    "build.prop"                  → /system/build.prop (SAR layout)
//    "bin/sh"                      → /system/bin/sh
//    "etc/init/foo.rc"             → /system/etc/init/foo.rc
//  SAR images keep their /system subdir so we glue on a `let root = …` prefix.
//
//  Every function used below is documented in the Common Resources → Scripts
//  API docs panel inside the app.
// ============================================================================

// ── SAR prefix helper ──────────────────────────────────────────────────────
let root = if IS_SAR == "true" { "system/" } else { "" };

// ── 1. build.prop: append device-specific properties ───────────────────────
// `append(file, text)` appends verbatim. If the file doesn't exist yet it
// gets created with default perms. We chmod 666 first so writes succeed
// regardless of how the source ROM shipped the file.
log("Appending sample_device properties to build.prop");
chmod(root + "build.prop", "666");
append(root + "build.prop", `
# ─── sample_device ───
ro.sample.chipset=sample_chipset
ro.sample.density=420
ro.sample.build.timestamp=` + BUILD_DATE + `_` + BUILD_TIME + `
`);

// ── 2. sed: rewrite an existing line ───────────────────────────────────────
// `sed(file, regex, replacement)` runs Rust `regex::Regex::replace_all`.
// Backslashes need escaping; use a backtick raw string to keep them readable.
log("Forcing ro.debuggable for debug builds");
if BUILD_TYPE.starts_with("debug") {
    sed(root + "build.prop", `ro\.debuggable=0`, "ro.debuggable=1");
}

// ── 3. read_prop / write_prop: surgical property edits ─────────────────────
// These speak build.prop syntax directly — no regex escaping trap. The read
// helper returns an empty string when the key is absent.
let old_sdk = read_prop(root + "build.prop", "ro.build.version.sdk");
log("Detected build.prop sdk = " + old_sdk);
write_prop(root + "build.prop", "ro.sample.previous_sdk", old_sdk);

// ── 4. Feature-flag branching ──────────────────────────────────────────────
// Toggle blocks of work per DEVICE_FEATURE_CONFIG. The sample flips two
// features on via the "sample_feature,demo_mode" list.
if DEVICE_CONFIG.contains("sample_feature") {
    log("sample_feature enabled → installing demo prop");
    write_prop(root + "build.prop", "ro.sample.feature.demo", "1");
}
if DEVICE_CONFIG.contains("demo_mode") {
    log("demo_mode enabled → widening log verbosity");
    write_prop(root + "build.prop", "log.tag.SampleHal", "V");
}

// ── 5. Copy a helper binary from the device's files dir ────────────────────
// `cp_reserve("device:…", …)` pulls from
// base_devices/sdk0/sample_device/, preserving any existing target
// metadata. Any path that ALREADY has a target file keeps the target's
// mode/uid/gid/mtime/selinux after this call.
//
// Uncomment and drop a real binary at the referenced path to use this:
//
//     cp_reserve("device:files/sample-hal.sh", root + "bin/sample-hal.sh");
//     chmod(root + "bin/sample-hal.sh", "755");
//     chown(root + "bin/sample-hal.sh", 0, 2000);            // root:shell
//     chcon(root + "bin/sample-hal.sh", "u:object_r:system_file:s0");

// ── 6. Symlinks ────────────────────────────────────────────────────────────
// cp/cp_reserve recreate real ext4 symlinks when the source is one. The
// engine also understands Windows-checked-out repos that store symlinks as
// `IntxLNK`-prefixed files — you don't need to do anything special for them.
//
// To create a symlink programmatically from scratch you currently delete the
// target and re-add it via a staged file copy; simpler to just commit the
// real symlink under base_devices/sdk0/sample_device/files/ and `cp_reserve`
// it.

// ── 7. SELinux policy additions ────────────────────────────────────────────
// plat_sepolicy.cil is compiled into the runtime policy on boot. Invalid
// lines will fail CIL validation (step 12 of the pipeline) — if the user
// toggles Auto Fix SELinux in the Build menu, failures get deleted and
// logged to `sources/<rom>/selinux.<device>.rhai` for next time.
log("Adding SELinux grant for sample_hal");
append(root + "etc/selinux/plat_sepolicy.cil", `
; ─── sample_device SELinux additions ───
(allow init sysfs_sample_file (file (read write open)))
`);
// Always re-label after writing — otherwise the file keeps its default
// context and the CIL parser in early-boot won't load it.
chcon(root + "etc/selinux/plat_sepolicy.cil", "u:object_r:sepolicy_file:s0");

// ── 8. Permissive / enforcing switch (debug vs release) ────────────────────
// The common/global script installs BOTH tgzx-boot.sh (permissive) and
// tgzx-boot_enforcing.sh (enforcing). Debug builds keep the permissive
// script. Release + *_enforcing build types swap it in.
if BUILD_TYPE.ends_with("_enforcing") || BUILD_TYPE == "release" {
    log("Enforcing build → swapping tgzx-boot to enforcing variant");
    if exists(root + "bin/tgzx-boot_enforcing.sh") {
        cp_reserve("common:system/bin/tgzx-boot_enforcing.sh",
                   root + "bin/tgzx-boot.sh");
    }
}

// ── 9. Removing files ──────────────────────────────────────────────────────
// `rm(path)` silently succeeds when the file is already gone — safe to run
// on every build.
rm(root + "etc/sample-vendor-leftover.xml");

// ── 10. Optional: APK patching demo (safe to remove) ───────────────────────
// `apk_decompile` extracts an APK into a work folder using the bundled
// APKEditor (Java). Use `smali_patch` / `smali_inject_after` etc. to edit,
// then `apk_recompile` to put it back.
//
// Uncomment when you have an actual APK to modify:
//
//     let work = apk_decompile(root + "priv-app/SampleApp/SampleApp.apk");
//     smali_inject_after(
//         work,
//         "com/example/sample/MainActivity",
//         "onCreate",                   // method name
//         "invoke-super",                // anchor line (first match)
//         `    const-string v0, "patched by tgzxPortKit V3"
//     invoke-static {v0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I`,
//     );
//     apk_recompile(work, root + "priv-app/SampleApp/SampleApp.apk");

log("system.rhai (sample_device) done");
