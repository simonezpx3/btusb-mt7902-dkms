#!/usr/bin/env bash
# install.sh: Automated installer for MT7902 Bluetooth DKMS driver & power fix
# Supports: Arch Linux, Omarchy, Fedora, Debian/Ubuntu (with dkms & kernel headers)

set -euo pipefail

PACKAGE_NAME="btusb-e156"
PACKAGE_VERSION="1.0"
SRC_DIR="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
    echo "This installation script requires root privileges. Please run with sudo:"
    echo "  sudo ./install.sh"
    exit 1
fi

echo "==================================================================="
echo "  Installing MediaTek MT7902 Bluetooth DKMS Patch (0489:e156)"
echo "==================================================================="

# 1. Dependency check
echo "-> Checking build tools and headers..."
if ! command -v dkms >/dev/null 2>&1; then
    echo "Error: 'dkms' is not installed. Please install it (e.g., sudo pacman -S dkms)."
    exit 1
fi

CURRENT_KERNEL="$(uname -r)"
if [[ ! -d "/lib/modules/${CURRENT_KERNEL}/build" ]]; then
    echo "Error: Linux kernel headers for ${CURRENT_KERNEL} are missing."
    echo "Please install them (e.g., sudo pacman -S linux-headers)."
    exit 1
fi

# 2. Setup DKMS source tree
echo "-> Preparing DKMS source directory at ${SRC_DIR}..."
rm -rf "${SRC_DIR}"
mkdir -p "${SRC_DIR}"

cp "${SCRIPT_DIR}/btusb.c" "${SRC_DIR}/"
cp "${SCRIPT_DIR}/Makefile" "${SRC_DIR}/"
cp "${SCRIPT_DIR}/dkms.conf" "${SRC_DIR}/"
for h in btmtk.h btintel.h btrtl.h btbcm.h; do
    if [[ -f "${SCRIPT_DIR}/${h}" ]]; then
        cp "${SCRIPT_DIR}/${h}" "${SRC_DIR}/"
    fi
done

# 3. Register, build and install via DKMS
echo "-> Registering module with DKMS..."
dkms remove -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" --all >/dev/null 2>&1 || true
dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}"

echo "-> Building and installing DKMS module for kernel ${CURRENT_KERNEL}..."
dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}"
dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" --force

# 4. Power stability configuration (Udev & Modprobe)
echo "-> Installing USB power management stability rules..."
cp "${SCRIPT_DIR}/99-bluetooth-mt7902-power.rules" /etc/udev/rules.d/
chmod 0644 /etc/udev/rules.d/99-bluetooth-mt7902-power.rules

cp "${SCRIPT_DIR}/btusb.conf" /etc/modprobe.d/
chmod 0644 /etc/modprobe.d/btusb.conf

echo "-> Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger -s usb -a idVendor=0489 -a idProduct=e156 || true

# Force live power control to 'on'
for dev in /sys/bus/usb/devices/*; do
    if [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]]; then
        vid=$(cat "$dev/idVendor" 2>/dev/null || true)
        pid=$(cat "$dev/idProduct" 2>/dev/null || true)
        if [[ "${vid,,}" == "0489" && "${pid,,}" == "e156" ]]; then
            if [[ -f "$dev/power/control" ]]; then
                echo "on" > "$dev/power/control"
                echo "-> Set live $dev/power/control to 'on'."
            fi
        fi
    fi
done

# 5. Install diagnostic utility
echo "-> Installing bt-debug utility to /usr/local/bin/bt-debug..."
cp "${SCRIPT_DIR}/bt-debug" /usr/local/bin/bt-debug
chmod 0755 /usr/local/bin/bt-debug

# 6. Reload module if user requested or system is idle
echo "-> Module installed successfully."
if lsmod | grep -q "^btusb"; then
    echo "Note: btusb module is currently active."
    echo "To activate immediately without rebooting, run:"
    echo "  sudo modprobe -r btusb && sudo modprobe btusb"
fi

echo
echo "==================================================================="
echo "  Installation Complete! Run 'bt-debug' to verify hardware status."
echo "==================================================================="
