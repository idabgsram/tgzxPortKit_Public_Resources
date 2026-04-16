// ============================================================================
//  common/global/system.rhai — runs on EVERY build, regardless of source or
//  target device. Keep edits here truly universal.
// ============================================================================

let root = if IS_SAR == "true" { "system/" } else { "" };

// ── 1. Stamp the build with who/what/when ──────────────────────────────────
log("Stamping tgzxPortKit V3 build metadata");
chmod(root + "build.prop", "666");
append(root + "build.prop", `
# ─── tgzxPortKit V3 build stamp ───
ro.tgzx.port=1
ro.tgzx.source=` + SOURCE_NAME + `
ro.tgzx.device=` + TARGET_DEVICE + `
ro.tgzx.build_type=` + BUILD_TYPE + `
ro.tgzx.builder=` + BUILDER_NAME + `@` + BUILDER_MACHINE + `
ro.tgzx.build_date=` + BUILD_DATE + `_` + BUILD_TIME + `
`);

// ── 2. Install the tgzx-boot.sh runtime (permissive by default) ────────────
// The common filesystem dir is addressed by "common:". The file itself
// lives at common/global/system/bin/tgzx-boot.sh relative to the project
// resources root.
//
// cp_reserve keeps any existing target metadata; on a fresh install it'll
// use sensible defaults and we tighten them up with chmod/chown/chcon.
log("Installing tgzx-boot runtime");
cp_reserve("common:system/bin/tgzx-boot.sh", root + "bin/tgzx-boot.sh");
chmod(root + "bin/tgzx-boot.sh", "755");
chown(root + "bin/tgzx-boot.sh", 0, 2000);           // root:shell
chcon(root + "bin/tgzx-boot.sh", "u:object_r:system_file:s0");

// Also drop the enforcing variant on disk — the per-device script decides
// which one becomes the active tgzx-boot.sh based on BUILD_TYPE.
cp_reserve("common:system/bin/tgzx-boot_enforcing.sh",
           root + "bin/tgzx-boot_enforcing.sh");
chmod(root + "bin/tgzx-boot_enforcing.sh", "755");
chown(root + "bin/tgzx-boot_enforcing.sh", 0, 2000);
chcon(root + "bin/tgzx-boot_enforcing.sh", "u:object_r:system_file:s0");

// ── 3. Service wiring: tgzx-boot.rc ────────────────────────────────────────
cp_reserve("common:system/etc/init/tgzx-boot.rc",
           root + "etc/init/tgzx-boot.rc");
chmod(root + "etc/init/tgzx-boot.rc", "644");
chown(root + "etc/init/tgzx-boot.rc", 0, 0);
chcon(root + "etc/init/tgzx-boot.rc", "u:object_r:system_file:s0");

// ── 4. Global SELinux grant for tgzx-boot ──────────────────────────────────
// Keep this minimal — any policy you add here runs on every port from every
// source. Per-source / per-device policy belongs in those scripts.
log("Granting tgzx-boot its init-class context");
append(root + "etc/selinux/plat_sepolicy.cil", `
; tgzxPortKit V3 global: tgzx-boot.sh runtime
(typeattribute su_temp)
(typeattributeset domain (su_temp))
`);
chcon(root + "etc/selinux/plat_sepolicy.cil", "u:object_r:sepolicy_file:s0");

log("common/global system.rhai done");
