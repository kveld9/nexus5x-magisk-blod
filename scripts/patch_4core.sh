#!/usr/bin/env bash
# patch_4core.sh
# Disables the two unstable Cortex-A57 "big" cores (CPUs 4 & 5) on the Nexus 5X (bullhead)
# to resolve the hardware Bootloop of Death (BLOD) flaw.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${1:-${SCRIPT_DIR}/../work}"
INPUT_BOOT="${2:-${SCRIPT_DIR}/../boot.img}"
OUTPUT_BOOT="${3:-${SCRIPT_DIR}/../boot_4core.img}"

command -v magiskboot >/dev/null 2>&1 || {
  echo "Error: magiskboot not found in PATH." >&2
  exit 1
}

if [[ ! -f "${INPUT_BOOT}" ]]; then
  echo "Error: Input boot image not found: ${INPUT_BOOT}" >&2
  exit 1
fi

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo "[*] Unpacking boot image..."
magiskboot unpack -h "${INPUT_BOOT}"

echo "[*] Patching cmdline in header..."
sed -i 's/boot_cpus=0-5/boot_cpus=0-3 maxcpus=4/g' header
if ! grep -q "boot_cpus=0-3" header; then
  sed -i 's/cmdline=/cmdline=boot_cpus=0-3 maxcpus=4 /' header
fi

echo "[*] Patching cpuset in init.bullhead.rc..."
magiskboot cpio ramdisk.cpio "extract init.bullhead.rc init.bullhead.rc"

sed -i 's/write \/dev\/cpuset\/foreground\/cpus 0-2,4-5/write \/dev\/cpuset\/foreground\/cpus 0-3/' init.bullhead.rc
sed -i 's/write \/dev\/cpuset\/foreground\/boost\/cpus 4-5/write \/dev\/cpuset\/foreground\/boost\/cpus 0-3/' init.bullhead.rc
sed -i 's/write \/dev\/cpuset\/background\/cpus 0/write \/dev\/cpuset\/background\/cpus 3/' init.bullhead.rc
sed -i 's/write \/dev\/cpuset\/system-background\/cpus 0-2/write \/dev\/cpuset\/system-background\/cpus 2-3/' init.bullhead.rc
sed -i 's/write \/dev\/cpuset\/top-app\/cpus 0-5/write \/dev\/cpuset\/top-app\/cpus 0-3/' init.bullhead.rc

magiskboot cpio ramdisk.cpio "add 0750 init.bullhead.rc init.bullhead.rc"

echo "[*] Repacking 4-core boot image..."
magiskboot repack "${INPUT_BOOT}" "${OUTPUT_BOOT}"

echo "[+] Successfully generated: ${OUTPUT_BOOT}"
