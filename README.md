# Nexus 5X (bullhead) BLOD 4-Core Workaround & Magisk v30 Root

Comprehensive technical guide and automated tooling to recover a Google Nexus 5X (`bullhead`) suffering from the hardware Bootloop of Death (BLOD) and install modern Magisk (v30+) with root access on stock Android 8.1 Oreo (build `OPM7.181205.001`).

---

## 1. Hardware Context: The BLOD Defect

The Qualcomm Snapdragon 808 (MSM8992) SoC in the Nexus 5X features a 6-core big.LITTLE configuration:
- 4x ARM Cortex-A53 (efficient cores, CPUs 0–3)
- 2x ARM Cortex-A57 (high-performance "big" cores, CPUs 4–5)

Due to package degradation and solder fatigue near the high-temperature big-core cluster, the Cortex-A57 cores fail over time. When the stock bootloader and kernel attempt to bring CPUs 4–5 online during the early boot sequence, the hardware crashes, resulting in an unrecoverable bootloop at the Google logo.

### The 4-Core Workaround
The workaround (originally developed by osm0sis and the XDA community) permanently disables the defective big cores:
1. **Kernel cmdline modification**: Appending `boot_cpus=0-3 maxcpus=4` forces the Linux kernel scheduler to enumerate and bring up only the Cortex-A53 cluster.
2. **Init cpuset remapping (`init.bullhead.rc`)**:
   - `foreground/cpus`: changed from `0-2,4-5` to `0-3`
   - `foreground/boost/cpus`: changed from `4-5` to `0-3`
   - `background/cpus`: changed from `0` to `3`
   - `system-background/cpus`: changed from `0-2` to `2-3`
   - `top-app/cpus`: changed from `0-5` to `0-3`

---

## 2. Magisk v30 Compatibility Challenges on Android 8.1 Oreo

Modern Magisk versions (v26 through v30+) utilize Rust-based early init binaries (`magiskinit`) and require specific environment parameters:

### Full Disk Encryption (FDE) Preservation
Stock Android 8.1 on the Nexus 5X uses legacy Full Disk Encryption (FDE).
- When Magisk's `boot_patch.sh` runs in host/PC mode without environment overrides, it defaults `KEEPFORCEENCRYPT=false`.
- This strips `forcefdeorfbe` from `fstab.bullhead`.
- As a consequence, `vold` attempts to mount `/data` as plain ext4, fails to read the encrypted blocks, and stalls indefinitely in the Android boot animation.
- **Solution**: Explicitly set `KEEPFORCEENCRYPT=true` and `KEEPVERITY=true`.

### Early Storage Partition (`PREINITDEVICE`)
Magisk v26+ requires an unencrypted, early-mountable partition to store SELinux policies and early runtime state before `/data` is decrypted.
- On the Nexus 5X (`bullhead`), this partition is `cache`.
- In offline patching environments, `$PREINITDEVICE` is left empty, causing `magiskinit` to fail during early boot.
- **Solution**: Explicitly set `PREINITDEVICE=cache`.

---

## 3. Tooling and Script Usage

### Step 1: Patch Stock Boot Image for 4 Cores
Unpack the factory `boot.img` (OPM7.181205.001) and apply the 4-core BLOD fix:
```bash
./scripts/patch_4core.sh work/ boot.img boot_4core.img
```

### Step 2: Patch 4-Core Boot Image with Magisk
Inject Magisk v30+ binaries while enforcing FDE and cache partition flags:
```bash
./scripts/patch_magisk.sh work_magisk/ boot_4core.img boot_magisk_4core.img tools/
```

### Step 3: Flash and Verify via Fastboot & ADB
Reboot the device to the bootloader, flash the boot partition, and confirm root access:
```bash
./scripts/flash_and_verify.sh boot_magisk_4core.img YOUR_DEVICE_SERIAL
```

---

## 4. Verification Commands

Once booted into Android, verify system integrity via ADB:

```bash
# Check online CPU cores (must return 0-3)
adb shell "cat /sys/devices/system/cpu/online"

# Check Magisk version (e.g. 30.7:MAGISK:R)
adb shell "magisk -v"

# Check su binary location
adb shell "which su"
```
