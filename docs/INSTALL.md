# Stronk 1 Installation Guide

**Your Computer. Actually Yours.**

This guide walks you through the complete process of installing Stronk 1 on a supported Chromebook, from firmware preparation to first boot.

**Time required:** 20-30 minutes total
**Difficulty:** Moderate (requires opening the laptop case once)

---

## What You Need

- A supported Chromebook (see below)
- A USB drive (4GB or larger)
- A small Phillips screwdriver (#0 or #1)
- Internet connection (for firmware download; Stronk installs offline)
- The Stronk 1 ISO image written to your USB drive

### Supported Chromebooks

| Model | Board Name | RAM | CPU | Write-Protect Method |
|-------|-----------|-----|-----|---------------------|
| Dell Chromebook 11 3180 | KEFKA | 4GB | Intel N3060 | WP screw |
| HP Chromebook 11 G5 EE | SETZER | 2GB | Intel N3060 | WP screw |
| HP Chromebook 11 G6 EE | SNAPPY | 4GB | Intel N3350 | Battery disconnect |

Stronk 1 also works on other x86-64 UEFI machines. If you are not using a Chromebook, skip to [Part 2](#part-2-write-the-usb).

---

## Part 1: Flash MrChromebox Firmware (Chromebooks Only)

Chromebooks ship with custom firmware that only boots ChromeOS. You need to replace it with standard UEFI firmware from MrChromebox. This is a one-time procedure.

### Step 1.1: Enable Developer Mode

1. Power off the Chromebook completely.
2. Hold **Esc + Refresh** (the circular arrow key) and press **Power**.
3. At the recovery screen, press **Ctrl+D**.
4. Confirm by pressing **Enter**.
5. Wait for Developer Mode to enable (~5 minutes). The Chromebook will wipe local data and reboot.
6. At the "OS verification is OFF" screen, press **Ctrl+D** to boot into ChromeOS.

### Step 1.2: Disable Write Protection

The firmware chip is hardware write-protected. You must disable this to flash new firmware.

**KEFKA (Dell Chromebook 11 3180) and SETZER (HP Chromebook 11 G5 EE):**

1. Power off and unplug the Chromebook.
2. Remove the bottom cover screws and lift the cover.
3. Locate the write-protect (WP) screw -- a silver screw on the motherboard bridging two contacts. Search your model name + "WP screw location" for photos.
4. Remove the WP screw. You do not need to put it back.
5. Reassemble the cover.

**SNAPPY (HP Chromebook 11 G6 EE):**

1. Power off and unplug the Chromebook.
2. Remove the bottom cover.
3. Disconnect the battery cable from the motherboard.
4. Connect the AC charger (powers the board without the battery).
5. Leave the battery disconnected during firmware flash.
6. Reconnect the battery and reassemble after flashing (Step 1.4).

### Step 1.3: Flash the Firmware

1. Boot into ChromeOS (Developer Mode).
2. Log in (or use Guest mode).
3. Open a terminal: press **Ctrl+Alt+T** to open crosh.
4. Type `shell` and press Enter.
5. Run the MrChromebox firmware utility:

```
cd; curl -LO mrchromebox.tech/firmware-util.sh
sudo bash firmware-util.sh
```

6. Select: **Install/Update UEFI (Full ROM) Firmware**
7. Confirm when prompted. The script will back up your stock firmware (save this backup to a USB drive if offered) and flash the UEFI Full ROM.
8. When complete, power off the Chromebook.

### Step 1.4: Reassemble

- **KEFKA/SETZER:** The WP screw can stay out permanently.
- **SNAPPY:** Reconnect the battery cable and reassemble the bottom cover.

Your Chromebook now boots like a standard UEFI PC.

---

## Part 2: Write the USB

Download the Stronk 1 ISO image and write it to a USB drive.

**On Linux or macOS:**

```
sudo dd if=stronk1-x86_64.iso of=/dev/sdX bs=4M status=progress
sync
```

Replace `/dev/sdX` with your USB drive's device path. Use `lsblk` (Linux) or `diskutil list` (macOS) to identify it. Double-check before running -- this erases the target drive.

**On Windows:**

Use [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.balena.io):

1. Select the Stronk 1 ISO file.
2. Select your USB drive.
3. Click Start/Flash and wait for completion.

---

## Part 3: Boot the USB

1. Insert the Stronk 1 USB drive into the Chromebook (or any x86-64 UEFI machine).
2. Power on the machine.
3. The UEFI firmware should detect and boot the USB automatically.
4. If it boots to a UEFI shell or setup screen instead, press **Esc** to open the boot menu and select the USB drive.

Stronk 1 will boot to the COSMIC desktop. This is a live session running from USB -- nothing has been written to your internal storage yet.

---

## Part 4: Run the Installer

1. From the desktop, open **Install Stronk 1** from the app launcher (or open a terminal and run `stronk-installer`).
2. The installer wizard walks you through:

   **Welcome** -- Overview of what the installer will do.

   **Disk Selection** -- Choose the internal drive to install to. The USB boot drive is automatically excluded. All data on the selected disk will be erased.

   **Hardware Profile** -- The installer auto-detects your Chromebook model. Confirm or select manually:
   - KEFKA: Dell Chromebook 11 3180
   - SETZER: HP Chromebook 11 G5 EE
   - SNAPPY: HP Chromebook 11 G6 EE
   - Generic: Other x86-64 machines

   **Browser Choice** -- Select your default browser:
   - **Brave** (default) -- installs offline from the USB image
   - **Firefox** -- requires an active internet connection during install

   **Timezone** -- Select your timezone from the list.

   **Confirmation** -- Review your choices. The installer shows exactly what will happen.

   **Installation** -- The installer partitions the disk, copies the system, and configures it. This takes several minutes.

3. When the installer reports success, click OK.

---

## Part 5: First Boot

1. Remove the USB drive.
2. Reboot the machine.
3. Stronk 1 boots directly to the COSMIC desktop. There is no login screen -- you are signed in automatically as the "stronk" user.

### What you get

Five pre-installed apps, nothing more:

1. **Brave** (or Firefox) -- your web browser
2. **COSMIC Files** -- file manager
3. **COSMIC Terminal** -- terminal emulator
4. **COSMIC Settings** -- system configuration
5. **The Forge** -- app store (coming soon)

The system is fully functional offline. WiFi can be configured from the system tray.

---

## Troubleshooting

### Firmware flash fails
- Verify write protection is fully disabled (Step 1.2).
- Ensure internet is connected.
- Run the firmware utility script again.

### Chromebook does not boot after firmware flash
- The UEFI firmware may take a moment on first boot (up to 30 seconds).
- If nothing happens, hold the Power button for 10 seconds to force-off, then try again.

### USB drive not detected at boot
- Try a different USB port.
- Re-write the ISO to the USB drive.
- Enter UEFI setup (press Esc at boot) and check the boot order.

### Installation fails
- Check the installer log at `/tmp/stronk-install.log` (open a terminal on the live USB desktop).
- Ensure the target disk has at least 4GB of space.
- If Firefox was selected, ensure the internet connection is active.

### No audio after install
- **KEFKA/SETZER:** Audio uses the SOF driver. If speakers do not work, open a terminal and run `pactl set-default-sink` to check available audio outputs.
- **SNAPPY:** Audio uses the AVS driver. Headphone output may require testing.

### Want to go back to ChromeOS
You can restore ChromeOS at any time using a ChromeOS recovery USB from [chromeos.google.com/recovery](https://chromeos.google.com/recovery). The MrChromebox UEFI firmware supports ChromeOS recovery mode.

---

## After Installation

- **Connect to WiFi:** Click the system tray (bottom-right) and select your network.
- **Install more apps:** The Forge app store is coming in a future update. For now, use the terminal and `nix-env` or Flatpak.
- **System updates:** Stronk 1 does not auto-update. You control when updates happen.
- **Privacy:** No telemetry, no tracking, no ads. Your computer talks to the internet only when you tell it to.
