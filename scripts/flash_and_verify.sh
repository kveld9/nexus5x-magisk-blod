#!/usr/bin/env bash
# flash_and_verify.sh
# Flashes the Magisk 4-core boot image via fastboot and verifies ADB connectivity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-${SCRIPT_DIR}/../boot_magisk_4core.img}"
DEVICE_SERIAL="${2:?Usage: $0 [boot-image] <device-serial>}"

if [[ ! -f "${IMAGE}" ]]; then
  echo "Error: Boot image not found: ${IMAGE}" >&2
  exit 1
fi

echo "[*] Rebooting ${DEVICE_SERIAL} to bootloader..."
adb -s "${DEVICE_SERIAL}" reboot bootloader 2>/dev/null || true
sleep 4

echo "[*] Waiting for device in fastboot mode..."
fastboot -s "${DEVICE_SERIAL}" wait-for-device

echo "[*] Flashing boot partition..."
fastboot -s "${DEVICE_SERIAL}" flash boot "${IMAGE}"

echo "[*] Rebooting device..."
fastboot -s "${DEVICE_SERIAL}" reboot

echo "[*] Waiting for Android boot completion..."
adb -s "${DEVICE_SERIAL}" wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'

echo "[+] Boot complete! Verifying Magisk and CPU configuration:"
adb -s "${DEVICE_SERIAL}" shell "cat /sys/devices/system/cpu/online; magisk -v; which su"
