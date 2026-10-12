#!/usr/bin/env bash
# install_module.sh
# Installs the Bullhead 4-Core Kernel & VM Optimizer Magisk module to the connected device.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE_DIR="${REPO_DIR}/module"
DEVICE_SERIAL="${1:-YOUR_DEVICE_SERIAL}"

echo "[*] Creating module structure on device: ${DEVICE_SERIAL}..."
adb -s "${DEVICE_SERIAL}" shell "su -c 'mkdir -p /data/adb/modules/bullhead-kernel-optimizer'"

echo "[*] Pushing module files..."
adb -s "${DEVICE_SERIAL}" push "${MODULE_DIR}/module.prop" /data/local/tmp/module.prop
adb -s "${DEVICE_SERIAL}" push "${MODULE_DIR}/service.sh" /data/local/tmp/service.sh

adb -s "${DEVICE_SERIAL}" shell "su -c '
mv /data/local/tmp/module.prop /data/adb/modules/bullhead-kernel-optimizer/module.prop
mv /data/local/tmp/service.sh /data/adb/modules/bullhead-kernel-optimizer/service.sh
chmod 644 /data/adb/modules/bullhead-kernel-optimizer/module.prop
chmod 755 /data/adb/modules/bullhead-kernel-optimizer/service.sh
touch /data/adb/modules/bullhead-kernel-optimizer/auto_mount
sh /data/adb/modules/bullhead-kernel-optimizer/service.sh &
'"

echo "[+] Module installed and executed successfully!"
