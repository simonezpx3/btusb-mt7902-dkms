#!/usr/bin/env bash
# uninstall.sh: Clean uninstaller for MT7902 Bluetooth DKMS driver & power fix

set -euo pipefail
umask 022

PACKAGE_NAME="btusb-e156"
PACKAGE_VERSION="1.1"
SRC_DIR="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "This uninstaller requires root privileges. Please run with sudo:"
    echo "  sudo ./uninstall.sh"
    exit 1
fi

if [[ "${SRC_DIR}" != /usr/src/btusb-e156-* ]]; then
    echo "Error: Invalid SRC_DIR path."
    exit 1
fi

echo "==================================================================="
echo "  Uninstalling MediaTek MT7902 Bluetooth DKMS Patch"
echo "==================================================================="

echo "-> Removing DKMS module ${PACKAGE_NAME}/${PACKAGE_VERSION}..."
dkms remove -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" --all >/dev/null 2>&1 || true

echo "-> Cleaning up DKMS source directory ${SRC_DIR}..."
if [[ -d "${SRC_DIR}" ]]; then
    rm -rf "${SRC_DIR}"
fi

echo "-> Removing power management configuration..."
rm -f /etc/udev/rules.d/99-bluetooth-mt7902-power.rules
rm -f /etc/modprobe.d/btusb.conf

echo "-> Reloading udev rules..."
udevadm control --reload-rules || true

echo "-> Removing /usr/local/bin/bt-debug..."
rm -f /usr/local/bin/bt-debug

echo "-> Triggering depmod..."
depmod -a "$(uname -r)"

echo "==================================================================="
echo "  Uninstallation complete. Upstream in-tree btusb driver restored."
echo "==================================================================="
