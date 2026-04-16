# tgzxPortKit V3 — Public Example Resources

**Example version:** `1.0.0a`

A **minimal, heavily-commented** starter project for tgzxPortKit V3.
Clone this repo, point the app's "Project Directory" setting at it,
and you have a working skeleton you can learn from and modify.

Everything here is **fictional** — SDK0, sample_device, sample_a0_device —
so nothing clashes with a real device. The scripts show every API the
Rhai engine exposes, with inline comments explaining what each call does
and when to reach for it.

---

## Quick start (5 minutes)

1. Install tgzxPortKit V3.
2. Clone or download this repo anywhere you like
3. In the app → **Settings → Workspace**, set *Project Directory* to the
   cloned folder.
4. **Settings → Identity** — pick a builder name.
5. Drop real partition images into:
   - `sources/sample_a0_device/images/` (your source ROM's `super.img`)
   - `base_devices/sdk0/sample_device/images/` (the target device's
     stock vendor / odm / etc)
6. Open the **Build** menu, pick `Sample Android 0` → `Sample Device` →
   `debug`, click **Start Build**.

You'll get a flashable `super.img` under `work/out/…` in about 5 minutes
on a modern desktop.

---

## Repo layout

```
.
├── README.md                               ← you are here
├── .gitignore                              ← ignores images, work/, out/
│
├── base_devices/
│   └── sdk0/sample_device/
│       ├── config                          ← device targets + switches
│       ├── excludes/                       ← per-partition skip lists
│       ├── images/                         ← drop stock device images
│       ├── system.rhai                     ← system partition patch
│       ├── system_ext.rhai                 ← system_ext partition patch
│       ├── product.rhai                    ← product partition patch
│       ├── vendor.rhai                     ← vendor partition patch
│       └── release/
│           ├── dynamic_zip/
│           │   ├── config                  ← filename → partition map
│           │   └── images/                 ← boot.img / dtbo.img / …
│           └── super_zip/                  ← alternative: single super.img zip
│
├── sources/
│   └── sample_a0_device/
│       ├── config                          ← source ROM definition
│       ├── excludes/sample_region.list     ← prune source partitions
│       ├── images/                         ← drop the source super.img
│       ├── system.rhai                     ← source-side system patch
│       ├── system.sample_device.rhai       ← only runs on sample_device target
│       ├── product.rhai                    ← source-side product patch
│       ├── vendor.rhai
│       └── release/sample_device/dynamic_zip/
│           ├── config                      ← source+device overlay images
│           └── images/
│
└── common/
    └── global/
        ├── system.rhai                     ← ALWAYS runs, every build
        ├── vendor.rhai
        ├── system/
        │   ├── bin/
        │   │   ├── tgzx-boot.sh            ← permissive variant
        │   │   └── tgzx-boot_enforcing.sh  ← enforcing variant
        │   └── etc/init/tgzx-boot.rc       ← init service wiring
        └── release/dynamic_zip/META-INF/com/google/android/
            └── update-binary               ← flashable OTA edify runtime
```

---

## How a build runs

Given the two names — source `sample_a0_device`, target `sample_device` —
the pipeline does this, in order:

```
1. Open source images  (sources/sample_a0_device/images/super.img)
2. Open target images  (base_devices/sdk0/sample_device/images/*.img)
3. Apply SOURCE excludes (sources/sample_a0_device/excludes/*.list)
4. Create per-partition ext4 images in memory
5. Apply patches per partition, in this order:
     a. common/global/<partition>.rhai
     b. sources/sample_a0_device/<partition>.rhai
     c. sources/sample_a0_device/<partition>.sample_device.rhai   ← device-specific
     d. base_devices/sdk0/sample_device/<partition>.rhai
6. Validate SELinux CIL policy across every partition
7. Convert to EROFS            (release builds only)
8. Build super.img              (debug) OR
   img2sdat + brotli + OTA zip  (release + dynamic_zip)
```

The pipeline honours two toggles on the Build menu:

- **Auto Fix SELinux** — on a CIL failure, delete the offending line,
  log it to `sources/<rom>/selinux.<device>.rhai`, retry up to 100×.
  On the next build the pipeline re-applies every saved line
  automatically.
- **Enforcing / custom flags** — picks `debug_enforcing` / `debug_avc`
  / `release_enforcing` variants; scripts read `BUILD_TYPE` to branch.

---

## Writing rhai scripts — full API

Every function is registered with the Rhai runtime. The app ships inline
docs (Common Resources → Scripts → API tab) but here's the quick
reference:

### File I/O

| Fn                                | Use for                                                  |
|-----------------------------------|-----------------------------------------------------------|
| `cp(src, dst)`                    | Copy from the CURRENT source image; preserves source meta |
| `cp("<part>:path", dst)`          | Copy from a DIFFERENT partition's image (cross-partition) |
| `cp_reserve("common:path", dst)`  | Copy from `common/global/…` (fs tree), preserves TARGET meta |
| `cp_reserve("device:path", dst)`  | Copy from `base_devices/.../<codename>/` (fs tree)        |
| `cp_reserve("path", dst)`         | Auto: try device → common → resources                     |
| `rm(path)`                        | Delete file or dir (recursive, safe if missing)           |
| `mkdir(path)`                     | Create directory                                          |
| `exists(path)` → bool             | Does path exist in the current build image?               |

### Metadata

| Fn                                | Use for                                                  |
|-----------------------------------|-----------------------------------------------------------|
| `chmod(path, "755")`              | Octal string or integer — same numeric you'd give `chmod` |
| `chown(path, uid, gid)`           | `chown(path, 0, 2000)` = root:shell                       |
| `chown(path, uid, gid, true)`     | 4th arg enables recursion for directories                 |
| `chcon(path, "u:object_r:...")`   | Set SELinux context (single file)                         |
| `chcon(path, ctx, true)`          | Recursive                                                 |

### Text patching

| Fn                                   | Use for                                               |
|--------------------------------------|-------------------------------------------------------|
| `sed(file, regex, replacement)`      | Rust regex find-and-replace                           |
| `append(file, text)`                 | Append; auto-creates the file                         |
| `read_prop(file, key)` → string      | `build.prop` key lookup (empty string if absent)     |
| `write_prop(file, key, value)`       | Set/update a `build.prop` key                         |

### APK / smali patching

APKs live inside your images as `.apk` or `.jar`. The runtime uses the
bundled APKEditor (Java — the one external runtime dep).

| Fn                                               | Use for                                |
|--------------------------------------------------|-----------------------------------------|
| `apk_decompile(path_in_image)` → workdir         | Pull APK out, decode into smali/res     |
| `apk_recompile(workdir, path_in_image)`          | Rebuild + replace original APK          |
| `apk_add_dex(path_in_image, dex_file)`           | Inject a prebuilt .dex                  |
| `smali_find_line(work, class, method, needle)`   | First matching line index               |
| `smali_inject_before(work, class, method, anchor, new)` | Insert before the first anchor match |
| `smali_inject_after(work, class, method, anchor, new)`  | Insert after                           |
| `smali_replace(work, class, method, needle, new)` | Line-level replace                      |
| `smali_replace_method(work, class, method, body)` | Swap entire method body                 |
| `smali_patch(work, class, patch_string)`         | Free-form patch                         |
| `smali_add_class(work, class, body)`             | Create a new smali class                |
| `smali_find_register(work, class, method, pat)`  | Extract register name from regex        |

### Logging

```rhai
log("Any string you want in the build log");
```

### Pipeline constants (all strings)

```
SOURCE_NAME       DEVICE_NAME        TARGET_DEVICE     DEVICE_CODE
FEATURE_CONFIG    DEVICE_CONFIG      BUILD_TYPE        IS_SAR
SYSTEM_AS_ROOT    VENDOR_SDK         BUILD_DATE        BUILD_TIME
BUILDER_NAME      BUILDER_MACHINE
```

---

## Updater-script template

Release (`dynamic_zip`) builds emit a flashable OTA whose logic lives in
`updater-script`. You can customise it without touching source:

- **Common Resources → Updater Script** tab in the app opens a Monaco
  editor with the built-in default.
- Edit → **Save** persists the override at
  `common/global/release/updater-script.tmpl`.
- Next build picks up the override automatically. Hit **Reset to
  Default** to drop back to the packaged template.
- The right-side panel lists every `{{PLACEHOLDER}}` with examples.

---

## Debug vs release

| Flag             | BUILD_TYPE value      | Policy default      | Output                          |
|------------------|-----------------------|---------------------|---------------------------------|
| Debug            | `debug`               | permissive          | `super.img` (ext4, sparse)      |
| Debug + custom   | `debug_avc`           | permissive          | `super.img` + your flag visible |
| Debug enforcing  | `debug_enforcing`     | enforcing           | `super.img`                     |
| Release          | `release`             | enforcing           | `<project>_ota.zip` (EROFS + sdat + brotli) |
| Release custom   | `release_enforcing`   | enforcing           | `<project>_ota.zip`             |

Scripts test `BUILD_TYPE.starts_with("debug")` /
`BUILD_TYPE.ends_with("_enforcing")` — see
`base_devices/sdk0/sample_device/system.rhai` for live examples.

---

## Compression levels

Both brotli quality and deflate level are tunable in
**Settings → Compression**. V1's defaults (brotli q6, deflate 6) are
the starting points; max (brotli q11, deflate 9) squeezes another ~5 %
at significant CPU cost.

---

## Troubleshooting

**Build fails at "SELinux validation"** — either fix the policy manually
or toggle **Auto Fix SELinux** in the Build menu. The lines it strips
get recorded to `sources/<rom>/selinux.<device>.rhai` so subsequent
builds apply the same fix automatically.

**APK repack errors** — check the app's Common Resources → Tools tab;
APKEditor needs Java to be reachable. Pre-built JVM can be downloaded
from that screen.

**"Build super partition (… bytes) exceeds maximum size"** — the
generated super is bigger than `DEVICE_SUPER_SIZE`. Tighten your
exclude lists (`sources/<rom>/excludes/*.list`) to strip unused bloat.

**Symlink looks wrong on Windows** — Windows checkouts store POSIX
symlinks as text markers. The engine already detects the `IntxLNK`
pattern and recreates real ext4 symlinks in the image, so just commit
the real symlink on Linux/macOS and the tool handles the rest.

---

## License

This example repo is provided for learning purposes. Scripts are
provided as-is; adapt freely to your device & source.
