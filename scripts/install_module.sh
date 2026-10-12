#!/usr/bin/env bash
# install_module.sh
# Builds and installs the Bullhead 4-Core Kernel & VM Optimizer Magisk module to the connected device.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEVICE_SERIAL="${1:-YOUR_DEVICE_SERIAL}"
OUTPUT_ZIP="${REPO_DIR}/bullhead-kernel-optimizer.zip"

echo "[*] Building module ZIP..."
"${SCRIPT_DIR}/build_module.sh"

echo "[*] Pushing module ZIP to ${DEVICE_SERIAL}..."
adb -s "${DEVICE_SERIAL}" push "${OUTPUT_ZIP}" /data/local/tmp/bullhead-kernel-optimizer.zip

echo "[*] Installing module via Magisk CLI..."
adb -s "${DEVICE_SERIAL}" shell "su -c 'magisk --install-module /data/local/tmp/bullhead-kernel-optimizer.zip'"

echo "[*] Executing runtime service script..."
adb -s "${DEVICE_SERIAL}" shell "su -c 'sh /data/adb/modules/bullhead-kernel-optimizer/service.sh &'"

echo "[+] Module successfully installed and active!"
