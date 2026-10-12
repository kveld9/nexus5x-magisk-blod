#!/usr/bin/env bash
# patch_magisk.sh
# Patches the 4-core boot image with Magisk v30+, preserving Full Disk Encryption (FDE)
# and setting PREINITDEVICE=cache for Android 8.1 Oreo on Nexus 5X (bullhead).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${1:-${SCRIPT_DIR}/../work_magisk}"
INPUT_BOOT="${2:-${SCRIPT_DIR}/../boot_4core.img}"
OUTPUT_BOOT="${3:-${SCRIPT_DIR}/../boot_magisk_4core.img}"
TOOLS_DIR="${4:-${SCRIPT_DIR}/../tools}"

if [[ ! -f "${INPUT_BOOT}" ]]; then
  echo "Error: Input 4-core boot image not found: ${INPUT_BOOT}" >&2
  exit 1
fi

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Copy Magisk tools and scripts
cp "${TOOLS_DIR}"/* .
chmod +x magisk magiskboot init-ld boot_patch.sh util_functions.sh

echo "[*] Running Magisk boot_patch with FDE and cache preinit flags..."
export KEEPFORCEENCRYPT=true
export KEEPVERITY=true
export PREINITDEVICE=cache
export BOOTMODE=true

sh boot_patch.sh "${INPUT_BOOT}"

if [[ -f new-boot.img ]]; then
  cp new-boot.img "${OUTPUT_BOOT}"
  echo "[+] Magisk 4-core boot image generated successfully: ${OUTPUT_BOOT}"
else
  echo "Error: new-boot.img was not generated." >&2
  exit 1
fi
