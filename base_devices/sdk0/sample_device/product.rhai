// ============================================================================
//  base_devices/sdk0/sample_device/product.rhai — product partition overrides
// ============================================================================
// Product is usually where OEM apps + region-specific props live. Keep edits
// cautious here; the source ROM's product is the canonical content and this
// file exists to layer device-facing finishing touches.

log("Layering sample_device product props");
chmod("etc/build.prop", "666");
write_prop("etc/build.prop", "ro.product.name",  "sample_device_product");
write_prop("etc/build.prop", "ro.product.brand", "sample");
write_prop("etc/build.prop", "ro.product.model", "SAMPLE_X0");

// Remove an OEM app only the source device shipped with. If the path
// doesn't exist this is a no-op — safe to leave in.
rm("priv-app/SampleBloatware");

log("product.rhai (sample_device) done");
