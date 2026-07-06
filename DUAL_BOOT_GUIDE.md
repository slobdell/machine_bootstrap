# Dual-Boot Windows & Ubuntu Setup Guide

This guide provides comprehensive, step-by-step instructions for installing Ubuntu alongside an existing Windows installation on a laptop.

---

## 📋 Table of Contents
1. [Phase 1: Pre-Requisites & Windows Preparation](#phase-1-pre-requisites--windows-preparation)
2. [Phase 2: Create a Bootable Ubuntu USB Drive](#phase-2-create-a-bootable-ubuntu-usb-drive)
3. [Phase 3: Configure BIOS / UEFI Settings](#phase-3-configure-bios--uefi-settings)
4. [Phase 4: Install Ubuntu Alongside Windows](#phase-4-install-ubuntu-alongside-windows)
5. [Phase 5: Post-Installation & GRUB Bootloader Configuration](#phase-5-post-installation--grub-bootloader-configuration)

---

## Phase 1: Pre-Requisites & Windows Preparation

Before changing partitions or boot configurations, configure Windows to ensure a smooth setup.

### 1. Locate and Save Your BitLocker Recovery Key (CRITICAL)
If Windows BitLocker device encryption is enabled, resizing partitions or changing UEFI boot orders might trigger BitLocker recovery mode, locking you out of Windows unless you have the key.
* In Windows, search for **BitLocker** in the Start Menu, or go to **Settings > Update & Security > Device Encryption**.
* Back up your recovery key to your Microsoft account, print it, or save it to a physical location (like a phone or another USB drive).
* *Alternative*: You can temporarily disable/suspend BitLocker encryption in Control Panel during the installation process.

### 2. Disable Windows Fast Startup
Fast Startup prevents Windows from fully shutting down. It leaves NTFS partitions in a hibernated, semi-mounted state, making them read-only or inaccessible from Ubuntu and potentially leading to filesystem corruption.
1. Open the **Control Panel** and navigate to **Power Options**.
2. Click **"Choose what the power buttons do"** on the left.
3. Click **"Change settings that are currently unavailable"** (requires Admin privileges).
4. Uncheck **"Turn on fast startup (recommended)"**.
5. Save changes.

### 3. Shrink the Windows C: Drive
Resizing Windows partitions from within the Windows OS is much safer than letting the Linux installer do it.
1. Right-click the Start button and select **Disk Management** (or run `diskmgmt.msc`).
2. Right-click your main Windows partition (usually **C:**) and select **Shrink Volume**.
3. Enter the amount of space to shrink (e.g., `102400` MB for 100 GB).
4. Click **Shrink**. You will see a block of **Unallocated Space** appear. Leave this unallocated—the Ubuntu installer will claim it.

---

## Phase 2: Create a Bootable Ubuntu USB Drive

### 1. Download the Ubuntu Desktop ISO
Ensure you download the LTS (Long-Term Support) version of Ubuntu Desktop from the official [Ubuntu Download Page](https://ubuntu.com/download/desktop).

### 2. Flash the ISO to USB
* **On Ubuntu / Debian / Linux (Using CLI / Terminal - Recommended)**:
  1. Identify your USB/SD card block device and mount status using `lsblk`:
     ```bash
     lsblk
     ```
     Identify the raw disk (e.g., `/dev/mmcblk0` or `/dev/sdb`) by matching its size.
  2. Unmount any mounted partitions on the device before writing (e.g., if `/dev/mmcblk0p1` is mounted at `/media/slobdell/...`):
     ```bash
     sudo umount /dev/mmcblk0p1
     ```
  3. Flash the ISO directly to the raw block device (not a partition):
     ```bash
     sudo dd if=~/Downloads/ubuntu-26.04-desktop-amd64.iso of=/dev/mmcblk0 bs=4M status=progress conv=fdatasync
     ```
     *(Note: Ensure you write to `/dev/mmcblk0` and NOT a partition like `/dev/mmcblk0p1`)*.
* **On Ubuntu / Debian / Linux (Using GUI)**:
  1. Launch **Startup Disk Creator** (pre-installed on Ubuntu Desktop):
     ```bash
     usb-creator-gtk
     ```
  2. Select `~/Downloads/ubuntu-26.04-desktop-amd64.iso` and target `/dev/mmcblk0`.
  3. Click **Make Startup Disk**.
* **On Windows (Recommended)**: Use **Rufus**.
  1. Open Rufus and insert a USB drive (minimum 8GB, all data on it will be wiped).
  2. Select the downloaded Ubuntu ISO.
  3. Under **Partition Scheme**, select **GPT**.
  4. Under **Target System**, select **UEFI (non-CSM)**.
  5. Click **START**. If prompted to choose a mode, choose **Write in ISO Image mode**.
* **On macOS / Linux / Windows**: Use **BalenaEtcher**.
  1. Select the ISO.
  2. Select the USB drive.
  3. Click **Flash**.

---

## Phase 3: Configure BIOS / UEFI Settings

To boot into the USB installer and access the drive, certain BIOS configurations must be updated.

### 1. Access UEFI / BIOS
Reboot the laptop and repeatedly press the BIOS hotkey.
* Common hotkeys: **F2** (Dell, Acer), **F12** (Lenovo), **F10** (HP), or **Esc**.

### 2. Configure SATA Controller Mode (AHCI vs. RAID)
If your storage controller is set to **Intel RST / RAID**, the Ubuntu installer will not detect your NVMe SSD. It must be set to **AHCI**.
> [!IMPORTANT]
> If Windows is already installed in RAID mode, changing it to AHCI directly will cause Windows to crash on boot (Blue Screen).
> **How to fix this safely:**
> 1. In Windows, press `Win + R`, type `cmd`, and press `Ctrl + Shift + Enter` to open an elevated command prompt.
> 2. Run: `bcdedit /set {current} safeboot minimal`
> 3. Reboot the computer and immediately enter the BIOS/UEFI.
> 4. Change the SATA/Storage Controller mode from **RAID** or **Intel RST** to **AHCI**.
> 5. Save changes and exit. The laptop will boot Windows into Safe Mode.
> 6. Open the elevated command prompt again and run: `bcdedit /deletevalue {current} safeboot`
> 7. Reboot once more. Windows will now boot normally in AHCI mode!

### 3. Disable Secure Boot (Optional but Recommended)
While Ubuntu supports Secure Boot, certain proprietary drivers (such as Nvidia GPUs or certain Broadcom Wi-Fi chipsets) require kernel module signing, which can fail or block installation under Secure Boot.
* In BIOS, navigate to the **Security** or **Boot** tab.
* Set **Secure Boot** to **Disabled**.

### 4. Adjust Boot Order
* Navigate to the **Boot** menu.
* Move **USB Storage Device** (or similar) to the top of the boot priority list.
* Alternatively, use the Boot Menu key (often **F12** or **F11**) on startup to select the USB drive directly.
* **If the USB/SD Card does not automatically appear in the boot list:**
  1. Select **"Add Boot Option"** or **"Add New Boot Option"**.
  2. Select the USB/SD Card reader filesystem (it may show up as `PciRoot...` or `ESP` or similar).
  3. Browse the files and navigate to **`EFI` -> `boot`**.
  4. Select **`BOOTX64.EFI`** (this is the standard Shim bootloader, which handles secure boot loading before passing execution to GRUB).
  5. Name the boot option (e.g., "Ubuntu USB") and save it.
  6. Set this newly created boot option to the top of your boot priority list.

---

## Phase 4: Install Ubuntu Alongside Windows

1. Insert your bootable USB drive and start the laptop.
2. Select **Try or Install Ubuntu** from the GRUB boot menu.
3. Once booted, click **Install Ubuntu** on the welcome screen.
4. Select your language, keyboard layout, and connect to Wi-Fi.
5. Choose **Normal Installation** (includes web browser, utilities, office software, media players) or **Minimal Installation** (just browser and basic utilities).
6. Under **Other options**, check the box for **"Install third-party software for graphics and Wi-Fi hardware and additional media formats"** (highly recommended for laptops).
7. Under **Installation Type**:
   * **Option A (Easiest)**: Select **Install Ubuntu alongside Windows Boot Manager** if available. The installer will automatically configure partitions using the free space.
   * **Option B (Manual / Precise Control)**: Select **Something else**.
     1. Find the **free space** you created in Phase 1.
     2. Click the `+` button to create a new partition.
     3. **Size**: Use the remaining free space (or leave 8-16 GB if you want to create a swap partition, though Ubuntu uses swap files by default now).
     4. **Type**: Primary.
     5. **Location**: Beginning of this space.
     6. **Use as**: **Ext4 journaling file system**.
     7. **Mount point**: `/` (this is the root directory).
     8. Under **Device for boot loader installation**, make sure your main storage drive is selected (e.g., `/dev/nvme0n1` or `/dev/sda`). Do not select a specific partition like `/dev/nvme0n1p1`.
8. Click **Install Now**, verify the summary of changes, and click **Continue**.
9. Select your timezone, create your user account (use the username configured in your `config.env` file to match path settings), and start the installation.

---

## Phase 5: Post-Installation & GRUB Bootloader Configuration

Once the installation is complete, reboot and remove the USB drive. You should be greeted by the GRUB bootloader menu.

### 1. What to do if GRUB doesn't show Windows
If the GRUB menu boots directly to Ubuntu and doesn't display Windows, we need to run `os-prober`.
1. Open a terminal in Ubuntu (`Ctrl + Alt + T`).
2. Open the GRUB configuration file:
   ```bash
   sudo nano /etc/default/grub
   ```
3. Look for the line `#GRUB_DISABLE_OS_PROBER=false` and uncomment it by removing the `#`:
   ```text
   GRUB_DISABLE_OS_PROBER=false
   ```
4. Save and exit (in Nano: `Ctrl + O`, `Enter`, then `Ctrl + X`).
5. Update GRUB settings:
   ```bash
   sudo update-grub
   ```
   You should see output indicating that Windows Boot Manager has been detected.

### 2. Time Synchronization (Fix Windows/Ubuntu Clock Desync)
Dual-booting laptops often suffer from time desynchronization. Windows interprets the hardware clock (RTC) as local time, while Linux interprets it as UTC.
To fix this, configure Ubuntu to write local time to the hardware clock:
```bash
timedatectl set-local-rtc 1 --adjust-system-clock
```

---

🎉 **Next Step**: Once you boot successfully into your fresh Ubuntu install, clone this repository, configure your `config.env`, and run `./bootstrap_machine.sh` to automatically install all editor settings, tools, and developer environments.
