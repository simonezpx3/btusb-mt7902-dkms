# MediaTek MT7902 Bluetooth DKMS Driver & Power Fix (`0489:e156`)

[![Version](https://img.shields.io/badge/version-1.0.2-3b82f6.svg)](https://github.com/simonezpx3/btusb-mt7902-dkms/releases/tag/v1.0.2)
[![Arch Linux](https://img.shields.io/badge/arch--linux-compatible-1793d1.svg?logo=arch-linux&logoColor=white)](https://archlinux.org)
[![Omarchy](https://img.shields.io/badge/omarchy-compatible-10b981.svg)](https://github.com/omacom/omarchy)
[![DKMS](https://img.shields.io/badge/dkms-autoinstall-f59e0b.svg)](https://github.com/dell/dkms)
[![Audio](https://img.shields.io/badge/audio-Sony%20LDAC%20Hi--Res-06b6d4.svg)](https://www.sony.net/Products/LDAC/)
[![License: GPL-2.0](https://img.shields.io/badge/license-GPL--2.0-8b5cf6.svg)](LICENSE)

Production-ready out-of-tree **DKMS kernel driver**, **power management fix**, and **diagnostic suite** for the **MediaTek MT7902** (Filogic 310) Bluetooth controller (`Foxconn 0489:e156`). Verified on **Arch Linux** and **Omarchy Linux** (Kernels 6.x / 7.x).

**Authors:** `simonez & Arci`  
**Version:** `1.0.2`  
**License:** GNU GPL-2.0  

---

## 1. Hardware Architecture & Problem Resolution

### The Hardware Context
Modern motherboards and laptops bundle Wi-Fi and Bluetooth onto a single M.2 Key-E card (such as the MediaTek MT7902 combo):
* **Wi-Fi 6E:** Routed via PCIe (`14c3:7902`) and supported in-tree via `mt7921e`.
* **Bluetooth 5.3:** Routed through the internal USB 2.0 bus with Foxconn OEM ID **`0489:e156`**.

### Why Stock Kernels Fail
1. **Missing Upstream ID:** While AzureWave variants (`13d3:3579`) are merged upstream in Linux v7.1+, the Foxconn device ID `0489:e156` is missing from in-tree `drivers/bluetooth/btusb.c`.
2. **Generic Binding Limitations:** Binding via `new_id` assigns `driver_info = 0`. Without the `BTUSB_MEDIATEK` vendor quirk, the controller fails MCU RAM firmware initialization (`BT_RAM_CODE_MT7902_*.bin`) and times out with error `-110`.
3. **USB Autosuspend Audio Dropout:** Under default aggressive USB autosuspend (`power/control = auto`), waking the controller interrupts high-bitrate audio streaming (**Sony LDAC 990 kbps / 48 kHz**), causing stuttering and disconnects.

---

## 2. Key Components & Driver Features

* **Patched `btusb` Driver:** Registers `USB_DEVICE(0x0489, 0xe156)` with `BTUSB_MEDIATEK | BTUSB_WIDEBAND_SPEECH | BTUSB_VALID_LE_STATES`.
* **Automated DKMS Integration:** Automatically rebuilds the module on every kernel update (`pacman -Syu`) into `/lib/modules/$(uname -r)/updates/dkms/`.
* **Permanent Power Stabilization:** Deploys udev and modprobe rules to permanently maintain `power/control = on` (`enable_autosuspend=0`).
* **Hardware Diagnostic Suite (`bt-debug`):** Real-time CLI tool for hardware inspection, DKMS validation, and live audio stream monitoring.

### Upstream Kernel Patch Diff
```diff
--- a/drivers/bluetooth/btusb.c
+++ b/drivers/bluetooth/btusb.c
@@ -645,6 +645,8 @@ static const struct usb_device_id quirks_table[] = {
 						     BTUSB_WIDEBAND_SPEECH },
 	{ USB_DEVICE(0x0489, 0xe158), .driver_info = BTUSB_MEDIATEK |
 						     BTUSB_WIDEBAND_SPEECH },
+	{ USB_DEVICE(0x0489, 0xe156), .driver_info = BTUSB_MEDIATEK |
+						     BTUSB_WIDEBAND_SPEECH },
```

---

## 3. Installation & Removal

### Automated Installation
```bash
git clone https://github.com/simonezpx3/btusb-mt7902-dkms.git
cd btusb-mt7902-dkms
chmod +x install.sh
sudo ./install.sh
```

The script automatically verifies prerequisites (`dkms`, `linux-headers`), builds and registers the module, deploys power stabilization rules (`/etc/udev/rules.d/99-bluetooth-mt7902-power.rules`, `/etc/modprobe.d/btusb.conf`), and installs `bt-debug`.

### Removal
```bash
cd btusb-mt7902-dkms
sudo ./uninstall.sh
```

---

## 4. Verification & Diagnostics (`bt-debug`)

Run the bundled diagnostic utility to verify hardware status, DKMS module binding, and active audio codec:

```bash
bt-debug            # Hardware overview, DKMS state, and connected devices
bt-debug --monitor  # Live audio packet stream telemetry
```

### Example Diagnostic Output
```text
===================================================================
    MediaTek MT7902 Bluetooth (Foxconn 0489:e156) Diagnostic     
===================================================================
[1] HARDWARE & USB BUS:    ● 0x0489:0xe156 (Power: on, Autosuspend: DISABLED)
[2] DRIVER & DKMS:         ● Installed (v1.0) via /lib/modules/updates/dkms/
[3] CONTROLLER & DEVICES:  ● Powered ON | AN01 Connected [Battery: 100%]
[4] AUDIO & PIPEWIRE:      ● Sink: AN01 | Codec: LDAC (float32le 2ch 48000Hz)
===================================================================
```
