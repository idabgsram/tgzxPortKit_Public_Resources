// ============================================================================
//  sources/sample_a0_device/system.sample_device.rhai
//  Source + device-pair override. Runs ONLY when building sample_a0_device
//  onto the sample_device target. Use for combinations that only make sense
//  together (e.g. "only on this one device, adjust the source's battery
//  props to match the device's chipset").
// ============================================================================

let root = if IS_SAR == "true" { "system/" } else { "" };

log("Applying sample_a0_device + sample_device specific tweaks");

// Example: chipset-specific battery drain workaround that only makes sense
// on this device.
if DEVICE_CONFIG.contains("sample_feature") {
    append(root + "build.prop", `
# Pair-specific battery saver (sample_a0_device on sample_device)
ro.sample.battery.calibration_model=SAMPLE_X0
`);
}
