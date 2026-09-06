# MediaTek MT7902 Bluetooth DKMS Driver & Power Fix (`0489:e156`)

[![License: GPL-2.0](https://img.shields.io/badge/License-GPL%202.0-blue.svg)](LICENSE)
[![Linux: Arch / Omarchy](https://img.shields.io/badge/Linux-Arch%20%2F%20Omarchy-1793d1.svg?logo=arch-linux)](https://archlinux.org)
[![DKMS: Supported](https://img.shields.io/badge/DKMS-Supported-brightgreen.svg)]()
[![Hardware: MediaTek MT7902](https://img.shields.io/badge/Hardware-MediaTek%20MT7902-orange.svg)]()
[![Codec: Sony LDAC Hi--Res](https://img.shields.io/badge/Audio-Sony%20LDAC%2048kHz-success.svg)]()

Production-ready out-of-tree **DKMS kernel driver**, **power management fix**, and **diagnostic suite** for the **MediaTek MT7902** (Filogic 310) Bluetooth controller (`Foxconn 0489:e156`).

Tested and verified on **Arch Linux**, **Omarchy Linux** (Kernel 6.x to 7.x), Gigabyte B850M FORCE WIFI6E, HP EliteMini, and ASUS gaming laptops.

---

## 🔍 The Problem

Modern motherboards and laptops bundle Wi-Fi and Bluetooth onto a single M.2 Key-E card (such as the MediaTek MT7902 combo):
* **Wi-Fi 6E** is routed through the **PCIe bus** (`14c3:7902`) and works out-of-the-box via the in-tree kernel driver `mt7921e`.
* **Bluetooth 5.3** is routed through the internal **USB 2.0 bus** with OEM vendor/product ID **`0489:e156`** (Foxconn / Hon Hai).

### Why doesn't Bluetooth work out of the box?
1. **Missing Upstream ID:** While AzureWave variants (`13d3:3579`) are present upstream in Linux v7.1+, the Foxconn ID `0489:e156` has not been merged into `drivers/bluetooth/btusb.c`.
2. **Why `echo "0489 e156" > /sys/bus/usb/drivers/btusb/new_id` fails:** Generic binding assigns `driver_info = 0`. Without the `BTUSB_MEDIATEK` quirk, the driver skips the MediaTek vendor handshake, fails to load the MCU RAM firmware (`BT_RAM_CODE_MT7902_*.bin`), and crashes with timeout error `-110`.
3. **USB Autosuspend Glitches:** When idling, Linux puts the USB controller into autosuspend (`power/control = auto`). For high-bitrate audio streaming (e.g., **Sony LDAC 990 kbps** or **aptX HD**), waking the controller causes audio stuttering, buffer underruns, and random disconnects.

---

## 🛠️ The Solution

This repository provides:
1. **Patched `btusb` Driver:** Adds `USB_DEVICE(0x0489, 0xe156)` with `BTUSB_MEDIATEK | BTUSB_WIDEBAND_SPEECH | BTUSB_VALID_LE_STATES`.
2. **DKMS Integration:** Automatically recompiles and updates your kernel module on every system update (`pacman -Syu` / kernel upgrade) without manual intervention.
3. **USB Power Stabilization:** Installs udev and modprobe rules to permanently keep the controller in `power/control = on` mode (`enable_autosuspend=0`).
4. **`bt-debug` Diagnostic Utility:** Real-time Python CLI for hardware inspection, DKMS validation, and live audio stream monitoring.

---

## 🚀 Quick Installation (Automated)

Clone this repository and run the installer:

```bash
git clone https://github.com/simonezpx3/btusb-mt7902-dkms.git
cd btusb-mt7902-dkms
chmod +x install.sh
sudo ./install.sh
```

### What `install.sh` does:
* Verifies `dkms` and `linux-headers` are installed.
* Registers, builds, and installs the module into `/lib/modules/$(uname -r)/updates/dkms/`.
* Deploys `/etc/udev/rules.d/99-bluetooth-mt7902-power.rules`.
* Deploys `/etc/modprobe.d/btusb.conf`.
* Installs the `bt-debug` utility to `/usr/local/bin/bt-debug`.
* Immediately forces live power control to `on`.

---

## 📊 Verification & Diagnostics

Run the bundled diagnostic tool:

```bash
bt-debug
```

### Example Output:
```text
===================================================================
    MediaTek MT7902 Bluetooth (Foxconn 0489:e156) Diagnostic     
===================================================================

[1] HARDWARE & USB BUS
  Device ID:          0x0489:0xe156 (MediaTek Inc. - Wireless_Device)
  USB Topology:       Bus 1, Device 4 (Speed: 480 Mbps)
  Sysfs Path:         /sys/bus/usb/devices/1-10
  Power Control:      ● on (Autosuspend DISABLED - Ultra Stable)
  Autosuspend Delay:  2000 ms
  Runtime Status:     active

[2] DRIVER & DKMS SUBSYSTEM
  DKMS Module:        ● Installed (v1.0)
  Active Driver:      ● DKMS override (/lib/modules/7.1.9-arch1-2/updates/dkms/btusb.ko.zst)

[3] BLUEZ CONTROLLER & DEVICES
  HCI Controller:     AC:F2:3C:56:6E:28 (cml) - Powered ON
  Device:             AN01 (D3:0D:EC:35:B7:AA) -> ● CONNECTED [Battery: 100%]

[4] AUDIO STREAM & PIPEWIRE CODEC
  Audio Sink:         AN01
  Active Codec:       LDAC (Hi-Res Streaming)
  Specification:      float32le 2ch 48000Hz
  Volume:             39%

[5] RECENT KERNEL EVENTS (DMESG)
  No recent Bluetooth kernel events
===================================================================
```

### Live Stream Monitoring
To monitor audio streaming and ensure zero packet dropouts:
```bash
bt-debug --monitor
```

---

## 📖 Manual Installation (Alternative)

If you prefer to install manually step-by-step:

### 1. Prerequisites (Arch Linux)
```bash
sudo pacman -S --needed linux-headers base-devel dkms
```

### 2. Register DKMS
```bash
sudo mkdir -p /usr/src/btusb-e156-1.0
sudo cp btusb.c Makefile dkms.conf bt*.h /usr/src/btusb-e156-1.0/
sudo dkms add -m btusb-e156 -v 1.0
sudo dkms build -m btusb-e156 -v 1.0
sudo dkms install -m btusb-e156 -v 1.0
```

### 3. Disable Autosuspend
```bash
sudo cp 99-bluetooth-mt7902-power.rules /etc/udev/rules.d/
sudo cp btusb.conf /etc/modprobe.d/
sudo udevadm control --reload-rules
sudo udevadm trigger -s usb -a idVendor=0489 -a idProduct=e156
```

### 4. Reload Driver
```bash
sudo modprobe -r btusb
sudo modprobe btusb
sudo systemctl restart bluetooth
```

---

## 🗑️ Uninstallation

To cleanly remove the DKMS module and restore stock in-tree drivers:

```bash
sudo ./uninstall.sh
```

---

## 📜 Upstream Kernel Patch

For Linux kernel developers or maintainers packaging vanilla kernels, the patch file is provided at [`0001-btusb-add-foxconn-mt7902-0489-e156.patch`](0001-btusb-add-foxconn-mt7902-0489-e156.patch):

```diff
--- a/drivers/bluetooth/btusb.c
+++ b/drivers/bluetooth/btusb.c
@@ -645,6 +645,8 @@ static const struct usb_device_id quirks_table[] = {
 						     BTUSB_WIDEBAND_SPEECH },
 	{ USB_DEVICE(0x0489, 0xe158), .driver_info = BTUSB_MEDIATEK |
 						     BTUSB_WIDEBAND_SPEECH },
+	{ USB_DEVICE(0x0489, 0xe156), .driver_info = BTUSB_MEDIATEK |
+						     BTUSB_WIDEBAND_SPEECH },
 
 	/* Additional MediaTek MT7921 Bluetooth devices */
 	{ USB_DEVICE(0x0489, 0xe0c8), .driver_info = BTUSB_MEDIATEK |
```

---

## 👥 Authors & Maintainers
* **simonez & Arci**
* Developed for **Omarchy Linux** & the Arch Linux Community.
* Licensed under the [GNU General Public License v2](LICENSE).
