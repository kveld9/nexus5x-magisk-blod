# Nexus 5X (bullhead) BLOD 4-Core Workaround & Magisk Root

Recover a Nexus 5X stuck in the Bootloop of Death (BLOD) by disabling the defective Cortex-A57 cluster, then root stock Android 8.1 Oreo (build `OPM7.181205.001`) with the vendored Magisk 30.7. Includes a Magisk module that retunes governor, I/O, ZRAM and LMK for 4-core operation.

## Prerequisites

- Host: `adb`, `fastboot`, `magiskboot` in `PATH`, plus `zip` and standard Unix tools.
- Stock `boot.img` extracted from the `OPM7.181205.001` factory image.
- Bootloader unlocked, USB debugging authorized; know the device serial (`adb devices`).
- Unlocking the bootloader wipes `/data`: back up first. Flashing boot images carries brick risk; BLOD is a hardware defect this only works around.

## Layout

- `scripts/patch_4core.sh` — stock `boot.img` → 4-core `boot_4core.img`
- `scripts/patch_magisk.sh` — 4-core image → rooted `boot_magisk_4core.img` (uses `tools/`)
- `scripts/flash_and_verify.sh` — flash via fastboot, verify via adb
- `scripts/build_module.sh` — package `module/` into `bullhead-kernel-optimizer.zip`
- `scripts/install_module.sh` — build, push and install the module (applies tunings immediately)
- `module/` — Magisk module sources (`module.prop`, `service.sh`)
- `tools/` — vendored Magisk 30.7 binaries and patch scripts (`MAGISK_VER 30.7/30700`)
- Generated `*.img` / `*.zip` / `work*/` outputs are gitignored.

---

## 1. Hardware Context: The BLOD Defect

The Snapdragon 808 (MSM8992) has a 6-core big.LITTLE layout: 4x Cortex-A53 (CPUs 0–3) plus 2x Cortex-A57 (CPUs 4–5). Solder fatigue near the hot big cluster kills the A57s over time; when boot brings CPUs 4–5 online, the phone crash-loops at the Google logo.

The workaround (from osm0sis and the XDA community) keeps only the stable A53 cluster:

1. **Kernel cmdline**: append `boot_cpus=0-3 maxcpus=4`.
2. **Cpuset remap** in `init.bullhead.rc`:

| Group | Stock | Patched |
|---|---|---|
| `foreground/cpus` | `0-2,4-5` | `0-3` |
| `foreground/boost/cpus` | `4-5` | `0-3` |
| `background/cpus` | `0` | `3` |
| `system-background/cpus` | `0-2` | `2-3` |
| `top-app/cpus` | `0-5` | `0-3` |

---

## 2. Magisk Compatibility on Android 8.1 Oreo

Stock 8.1 on bullhead uses legacy Full Disk Encryption (FDE), and Magisk v26+ needs an early-mountable partition before `/data` decrypts. Offline patching gets both wrong by default:

- `boot_patch.sh` defaults `KEEPFORCEENCRYPT=false`, stripping `forcefdeorfbe` from `fstab.bullhead`, so `vold` stalls on encrypted `/data`. Fix: export `KEEPFORCEENCRYPT=true` and `KEEPVERITY=true`.
- `$PREINITDEVICE` is empty offline, so `magiskinit` has no early storage. On bullhead the answer is `cache`. Fix: export `PREINITDEVICE=cache`.

---

## 3. Usage

### Step 1: Patch stock boot image for 4 cores

```bash
./scripts/patch_4core.sh work/ boot.img boot_4core.img
```

Requires `magiskboot` in `PATH`; aborts otherwise.

### Step 2: Patch 4-core image with Magisk

```bash
./scripts/patch_magisk.sh work_magisk/ boot_4core.img boot_magisk_4core.img tools/
```

Sets the FDE/cache flags from §2 and runs the vendored `boot_patch.sh`.

### Step 3: Flash and verify

```bash
./scripts/flash_and_verify.sh boot_magisk_4core.img YOUR_DEVICE_SERIAL
```

Reboots to bootloader, flashes `boot`, waits for `sys.boot_completed`, then prints CPU status, Magisk version and `su` path. The image argument is optional (defaults to `boot_magisk_4core.img`); the serial is required.

---

## 4. Verification

```bash
# Online CPUs (must print 0-3)
adb -s YOUR_DEVICE_SERIAL shell "cat /sys/devices/system/cpu/online"

# Magisk version (e.g. 30.7:MAGISK:R)
adb -s YOUR_DEVICE_SERIAL shell "magisk -v"

# su location
adb -s YOUR_DEVICE_SERIAL shell "which su"
```

---

## 5. Kernel & VM Optimization Module

On 4x A53s alone, stock tuning stutters and kills background apps early. `module/service.sh` waits for boot completion, then applies the tunings below in three passes (+15s, +40s, +70s) so late `init.bullhead.rc` and ActivityManager triggers don't win:

- **Interactive governor** (`cpu0/cpufreq/interactive`): `go_hispeed_load` 99→85, `hispeed_freq` 960000→1248000, `target_loads` → `70 600000:80 960000:85 1248000:90`, `above_hispeed_delay` → `20000 1248000:40000`, `min_sample_time` →40000, `timer_rate` →20000, `io_is_busy` →1. `msm_performance/managed_cpus` pinned to `0-3`.
- **Block I/O** (`mmcblk0` and `dm-*`, incl. encrypted data): scheduler →`deadline`, `read_ahead_kb` →512, `rq_affinity` →2, `iostats` →0.
- **VM & ZRAM**: `zram0` resized to 1 GB `lz4` (only if currently smaller), then `swappiness` →100, `vfs_cache_pressure` →80, `dirty_ratio` →15, `dirty_background_ratio` →5.
- **LMK** `minfree` →`15360,19200,23040,26880,34560,46080`, then locked read-only.

### Installation

```bash
./scripts/install_module.sh YOUR_DEVICE_SERIAL
```

Builds the ZIP via `build_module.sh`, pushes it to `/data/local/tmp`, installs with `magisk --install-module`, and kicks `service.sh` at once (no reboot needed). To only build the flashable ZIP: `./scripts/build_module.sh`.

---

## License

GPL-3.0-or-later; see `LICENSE`. The `tools/` binaries and patch scripts are upstream Magisk 30.7, also GPL-licensed.
