#!/usr/bin/env bash
# Stronk 1 — MrChromebox Firmware Flash Guide
# Step 8.2: Documents the exact procedure for flashing UEFI Full ROM
# firmware on supported Chromebooks before installing Stronk 1.
#
# Supported models:
#   KEFKA  — Dell Chromebook 11 3180 (WP screw)
#   SETZER — HP Chromebook 11 G5 EE  (WP screw)
#   SNAPPY — HP Chromebook 11 G6 EE  (battery disconnect)

set -euo pipefail

cat <<'GUIDE'
================================================================
  Stronk 1 — MrChromebox Firmware Flash Guide
================================================================

This guide walks you through flashing MrChromebox UEFI Full ROM
firmware on your Chromebook. This replaces the ChromeOS firmware
with standard UEFI, allowing Stronk 1 (or any Linux) to boot.

This is a ONE-TIME procedure. Once flashed, your Chromebook
boots like a standard PC.

────────────────────────────────────────────────────────────────
 PREREQUISITES
────────────────────────────────────────────────────────────────

  - Your Chromebook must be powered on and running ChromeOS
  - You need physical access to open the back cover
  - A small Phillips screwdriver (#0 or #1)
  - Internet connection (to download the firmware)
  - 10-15 minutes

────────────────────────────────────────────────────────────────
 STEP 1: ENABLE DEVELOPER MODE
────────────────────────────────────────────────────────────────

  1. Power off your Chromebook completely.
  2. Hold  Esc + Refresh (F3)  and press  Power.
  3. At the recovery screen, press  Ctrl+D.
  4. Confirm by pressing  Enter.
  5. Wait for Developer Mode to enable (takes ~5 minutes).
     The Chromebook will reboot and wipe local data.
  6. At the "OS verification is OFF" screen, press  Ctrl+D
     to boot into ChromeOS Developer Mode.

────────────────────────────────────────────────────────────────
 STEP 2: DISABLE WRITE PROTECTION
────────────────────────────────────────────────────────────────

  The firmware flash chip is write-protected by hardware.
  You must disable it to flash new firmware.

  ** KEFKA (Dell Chromebook 11 3180) — WP Screw **
  ** SETZER (HP Chromebook 11 G5 EE) — WP Screw **

    1. Power off and unplug the Chromebook.
    2. Remove the bottom cover screws and lift the cover.
    3. Locate the write-protect screw. It is a silver screw
       on the motherboard that bridges two contacts.
       (Search "[model] wp screw location" for photos.)
    4. Remove the WP screw.
    5. Reassemble the cover.

  ** SNAPPY (HP Chromebook 11 G6 EE) — Battery Disconnect **

    1. Power off and unplug the Chromebook.
    2. Remove the bottom cover.
    3. Disconnect the battery cable from the motherboard.
    4. Connect the charger (powers the board without battery).
    5. Leave the battery disconnected during firmware flash.
    6. Reconnect the battery after flashing.

────────────────────────────────────────────────────────────────
 STEP 3: FLASH MRCHROMEBOX UEFI FULL ROM
────────────────────────────────────────────────────────────────

  1. Boot into ChromeOS (Developer Mode).
  2. Log in (or skip — Guest mode works).
  3. Open a terminal:  Ctrl+Alt+T  to open crosh.
  4. Type:  shell  and press Enter.
  5. Run the MrChromebox firmware utility:

       cd; curl -LO mrchromebox.tech/firmware-util.sh
       sudo bash firmware-util.sh

  6. Select option:  Install/Update UEFI (Full ROM) Firmware
  7. Confirm when prompted. The script will:
       - Back up the stock firmware (save this backup!)
       - Download and flash the UEFI Full ROM
  8. When complete, power off the Chromebook.

────────────────────────────────────────────────────────────────
 STEP 4: REASSEMBLE (if disassembled)
────────────────────────────────────────────────────────────────

  - KEFKA/SETZER: You may leave the WP screw out permanently
    (it is no longer needed).
  - SNAPPY: Reconnect the battery, reassemble the cover.

────────────────────────────────────────────────────────────────
 STEP 5: BOOT THE STRONK 1 USB
────────────────────────────────────────────────────────────────

  1. Insert the Stronk 1 USB drive.
  2. Power on the Chromebook.
  3. The MrChromebox firmware boots to UEFI — it should find
     the USB automatically.
  4. If it boots to the UEFI shell instead, press Esc to
     enter the boot menu and select the USB drive.
  5. Stronk 1 will boot to the desktop. Run the installer
     from the app launcher: "Install Stronk 1".

────────────────────────────────────────────────────────────────
 TROUBLESHOOTING
────────────────────────────────────────────────────────────────

  "Firmware flash fails"
    → Ensure write protection is fully disabled.
    → Ensure internet is connected.
    → Try running the script again.

  "Chromebook won't boot after flash"
    → The UEFI firmware may take a moment on first boot.
    → If nothing happens after 30 seconds, hold Power 10s
      to force-off and try again.

  "USB not detected"
    → Try a different USB port.
    → Re-write the ISO to the USB drive.
    → Enter UEFI setup (Esc at boot) and check boot order.

  "Want to go back to ChromeOS"
    → You can restore ChromeOS using a recovery USB from
      chromeos.google.com/recovery. The UEFI firmware
      supports ChromeOS recovery mode.

================================================================
  Ready? Insert your Stronk 1 USB and reboot!
================================================================
GUIDE
