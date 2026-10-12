#!/usr/bin/env bash
# build_module.sh
# Packages the Bullhead 4-Core Kernel & VM Optimizer into a flashable Magisk module ZIP.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${REPO_DIR}/work_zip"
OUTPUT_ZIP="${REPO_DIR}/bullhead-kernel-optimizer.zip"

rm -rf "${WORK_DIR}" "${OUTPUT_ZIP}"
mkdir -p "${WORK_DIR}/META-INF/com/google/android"

cat << 'EOF' > "${WORK_DIR}/META-INF/com/google/android/update-binary"
#!/sbin/sh
umask 022
ui_print() { echo "$1"; }
require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}
OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null
[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk
install_module
exit 0
EOF

echo "#MAGISK" > "${WORK_DIR}/META-INF/com/google/android/updater-script"
cp "${REPO_DIR}/module/module.prop" "${WORK_DIR}/"
cp "${REPO_DIR}/module/service.sh" "${WORK_DIR}/"

cd "${WORK_DIR}"
zip -r "${OUTPUT_ZIP}" . >/dev/null
rm -rf "${WORK_DIR}"

echo "[+] Flashable Magisk module ZIP created: ${OUTPUT_ZIP}"
