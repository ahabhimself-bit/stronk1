#!/usr/bin/env bash
# Stronk 1 Installer — Guided installation to internal storage
# Wraps nixos-install with a zenity GUI wizard.
set -euo pipefail

FLAKE_SOURCE="/etc/stronk-flake"
MOUNT_POINT="/mnt"
LOG_FILE="/tmp/stronk-install.log"
INSTALL_ERROR_FILE="/tmp/stronk-install-error"

# ── Helpers ─────────────────────────────────────────────────────────────

die() {
  zenity --error --title="Installation Error" --text="$1" --width=400
  exit 1
}

log() {
  echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

# Return partition device path (handles nvme/mmcblk vs sd/vd naming)
get_part() {
  local disk="$1" num="$2"
  case "$disk" in
    /dev/nvme*|/dev/mmcblk*) echo "${disk}p${num}" ;;
    *) echo "${disk}${num}" ;;
  esac
}

# Detect Chromebook model from DMI board name (set by MrChromebox firmware)
detect_model() {
  local board
  board=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "unknown")
  case "${board,,}" in
    *kefka*)  echo "kefka"  ;;
    *setzer*) echo "setzer" ;;
    *snappy*) echo "snappy" ;;
    *)        echo "generic" ;;
  esac
}

# Check if network is reachable
has_network() {
  ping -c1 -W2 cache.nixos.org &>/dev/null
}

# ── Root check ──────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  exec pkexec "$0" "$@"
fi

log "Stronk 1 installer started"

# ── Firmware check (8.2) ───────────────────────────────────────────────
# Verify MrChromebox UEFI firmware is present on Chromebooks.
# Non-Chromebook x86-64 machines can proceed without it.

BIOS_VENDOR=$(cat /sys/class/dmi/id/bios_vendor 2>/dev/null || echo "unknown")
BOARD_NAME=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "unknown")
log "BIOS vendor: $BIOS_VENDOR, Board: $BOARD_NAME"

if [[ "${BIOS_VENDOR,,}" != *"coreboot"* ]]; then
  zenity --warning \
    --title="Firmware Notice" \
    --text="This computer does not appear to have MrChromebox UEFI firmware.\n\n<b>If this is a Chromebook:</b>\nYou must flash MrChromebox Full ROM firmware first.\nVisit mrchromebox.tech for instructions, or run\n<tt>stronk-firmware-guide</tt> in a terminal.\n\n<b>If this is a standard PC:</b>\nYou can safely continue — no firmware flash is needed." \
    --width=480 --height=280
fi

# ── Step 1: Welcome (9.3) ──────────────────────────────────────────────

zenity --info \
  --title="Stronk 1 Installer" \
  --text="Welcome to Stronk 1.\n\n<b>Your Computer. Actually Yours.</b>\n\nThis wizard will install Stronk 1 to your computer's internal storage.\n\nYou will need:\n  - A target disk (all data will be erased)\n  - About 10 minutes\n\nClick OK to continue." \
  --width=450 --height=280 \
  || exit 0

# ── Step 2: Disk selection (9.4) ───────────────────────────────────────

# Find the boot device so we can exclude it
BOOT_DEV=$(findmnt -n -o SOURCE / | sed 's/[0-9p]*$//' | xargs readlink -f 2>/dev/null || true)
log "Boot device: $BOOT_DEV"

# List candidate disks (exclude loop, sr, boot USB)
DISK_LIST=()
while IFS= read -r line; do
  dev=$(echo "$line" | awk '{print $1}')
  # Skip the boot device
  if [[ "$dev" == "$BOOT_DEV" ]]; then
    continue
  fi
  size=$(echo "$line" | awk '{print $2}')
  model=$(echo "$line" | awk '{$1=$2=""; print}' | xargs)
  [[ -z "$model" ]] && model="(unknown)"
  DISK_LIST+=("$dev" "$size" "$model")
done < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null | grep -E '^/dev/(sd|nvme|mmcblk|vd)' | grep -v loop)

if [[ ${#DISK_LIST[@]} -eq 0 ]]; then
  die "No suitable installation disks found.\n\nMake sure the target disk is connected and is not the USB you booted from."
fi

SELECTED_DISK=$(zenity --list \
  --title="Select Installation Disk" \
  --text="Choose the disk to install Stronk 1 onto.\n\n<b>WARNING: ALL DATA on the selected disk will be erased.</b>" \
  --column="Device" --column="Size" --column="Model" \
  --width=550 --height=350 \
  "${DISK_LIST[@]}") \
  || exit 0

if [[ -z "$SELECTED_DISK" ]]; then
  die "No disk selected."
fi

log "Selected disk: $SELECTED_DISK"

# ── Step 3: Detect Chromebook model ────────────────────────────────────

AUTO_MODEL=$(detect_model)
log "Auto-detected model: $AUTO_MODEL"

MODEL=$(zenity --list \
  --title="Hardware Profile" \
  --text="Select your Chromebook model.\n\nDetected: <b>${AUTO_MODEL}</b>" \
  --radiolist \
  --column="" --column="Profile" --column="Description" \
  "$([ "$AUTO_MODEL" = "kefka" ]  && echo TRUE || echo FALSE)" "kefka"   "Dell Chromebook 11 3180 (4GB, Braswell)" \
  "$([ "$AUTO_MODEL" = "setzer" ] && echo TRUE || echo FALSE)" "setzer"  "HP Chromebook 11 G5 EE (2GB, Braswell)" \
  "$([ "$AUTO_MODEL" = "snappy" ] && echo TRUE || echo FALSE)" "snappy"  "HP Chromebook 11 G6 EE (4GB, Apollo Lake)" \
  "$([ "$AUTO_MODEL" = "generic" ] && echo TRUE || echo FALSE)" "generic" "Other / Generic x86-64" \
  --width=500 --height=320) \
  || exit 0

log "Selected model: $MODEL"

# ── Step 4: Browser choice (9.5) ───────────────────────────────────────

FIREFOX_LABEL="Firefox (requires internet connection)"
if has_network; then
  FIREFOX_LABEL="Firefox"
fi

BROWSER=$(zenity --list \
  --title="Choose Your Browser" \
  --text="Select your default web browser." \
  --radiolist \
  --column="" --column="Browser" --column="Description" \
  TRUE  "brave"   "Brave -- Privacy-focused, blocks ads and trackers by default" \
  FALSE "firefox" "$FIREFOX_LABEL -- Open source, highly customizable" \
  --width=520 --height=260) \
  || exit 0

[[ -z "$BROWSER" ]] && BROWSER="brave"

# If Firefox selected but no network, warn
if [[ "$BROWSER" == "firefox" ]] && ! has_network; then
  zenity --question \
    --title="Network Required" \
    --text="Firefox is not cached on this USB and requires an internet connection to install.\n\nYou are not currently connected to the internet.\n\nInstall with Brave instead, or connect to WiFi and retry?" \
    --ok-label="Use Brave" \
    --cancel-label="Cancel" \
    --width=420 \
    && BROWSER="brave" \
    || exit 0
fi

log "Selected browser: $BROWSER"

# ── Step 5: Timezone selection (9.6) ───────────────────────────────────

# Build timezone list grouped by common choices first
COMMON_TZ=(
  "America/New_York"
  "America/Chicago"
  "America/Denver"
  "America/Los_Angeles"
  "America/Anchorage"
  "Pacific/Honolulu"
  "America/Toronto"
  "America/Vancouver"
  "Europe/London"
  "Europe/Paris"
  "Europe/Berlin"
  "Europe/Moscow"
  "Asia/Tokyo"
  "Asia/Shanghai"
  "Asia/Kolkata"
  "Australia/Sydney"
  "Pacific/Auckland"
)

# Build the zenity list entries
TZ_ENTRIES=()
for tz in "${COMMON_TZ[@]}"; do
  TZ_ENTRIES+=("$tz")
done

# Add separator and full list
while IFS= read -r tz; do
  # Skip if already in common list
  # shellcheck disable=SC2076
  if [[ ! " ${COMMON_TZ[*]} " =~ " ${tz} " ]]; then
    TZ_ENTRIES+=("$tz")
  fi
done < <(timedatectl list-timezones 2>/dev/null || awk '/^Z/{print $2}' /usr/share/zoneinfo/tzdata.zi 2>/dev/null || echo "UTC")

TIMEZONE=$(zenity --list \
  --title="Select Timezone" \
  --text="Choose your timezone.\n\nCommon timezones are listed first." \
  --column="Timezone" \
  --width=400 --height=450 \
  "${TZ_ENTRIES[@]}") \
  || exit 0

[[ -z "$TIMEZONE" ]] && TIMEZONE="UTC"
log "Selected timezone: $TIMEZONE"

# ── Step 6: Confirmation (9.7) ─────────────────────────────────────────

DISK_SIZE=$(lsblk -dno SIZE "$SELECTED_DISK" 2>/dev/null || echo "unknown")

zenity --question \
  --title="Ready to Install" \
  --text="<b>Review your choices:</b>\n\n  Disk: $SELECTED_DISK ($DISK_SIZE)\n  Hardware: $MODEL\n  Browser: $BROWSER\n  Timezone: $TIMEZONE\n\n<b>WARNING: ALL DATA on $SELECTED_DISK will be permanently erased.</b>\n\nProceed with installation?" \
  --ok-label="Install" \
  --cancel-label="Cancel" \
  --width=450 --height=300 \
  || exit 0

log "User confirmed installation"

# ── Step 7: Installation (9.7) ─────────────────────────────────────────

# Error function for use inside the install subshell.
# Writes to a file instead of showing a dialog (avoids double-dialog with zenity --progress).
install_fail() {
  log "INSTALL ERROR: $1"
  echo "$1" > "$INSTALL_ERROR_FILE"
  exit 1
}

rm -f "$INSTALL_ERROR_FILE"

(
  # Redirect stderr to log; stdout goes to zenity progress via pipe
  exec 2>>"$LOG_FILE"

  echo "5"
  echo "# Unmounting target disk..."
  # Unmount any existing mounts on the target disk
  umount -R "$MOUNT_POINT" 2>/dev/null || true
  for part in "${SELECTED_DISK}"*; do
    umount "$part" 2>/dev/null || true
  done

  # Verify target disk has at least 4GB (needed for NixOS install)
  DISK_BYTES=$(lsblk -bdno SIZE "$SELECTED_DISK" 2>/dev/null || echo 0)
  if [[ "$DISK_BYTES" -lt 4294967296 ]]; then
    install_fail "Target disk is smaller than 4GB. Stronk 1 requires at least 4GB of disk space."
  fi

  echo "10"
  echo "# Partitioning $SELECTED_DISK..."
  log "Partitioning $SELECTED_DISK"
  if ! parted -s "$SELECTED_DISK" mklabel gpt; then
    install_fail "Failed to create partition table on $SELECTED_DISK"
  fi
  if ! parted -s "$SELECTED_DISK" mkpart ESP fat32 1MiB 512MiB; then
    install_fail "Failed to create EFI partition on $SELECTED_DISK"
  fi
  parted -s "$SELECTED_DISK" set 1 boot on
  if ! parted -s "$SELECTED_DISK" mkpart primary ext4 512MiB 100%; then
    install_fail "Failed to create root partition on $SELECTED_DISK"
  fi

  EFI_PART=$(get_part "$SELECTED_DISK" 1)
  ROOT_PART=$(get_part "$SELECTED_DISK" 2)

  echo "20"
  echo "# Formatting partitions..."
  log "Formatting EFI: $EFI_PART"
  mkfs.vfat -F32 -n STRONK-BOOT "$EFI_PART"
  log "Formatting root: $ROOT_PART"
  mkfs.ext4 -F -L stronk-root "$ROOT_PART"

  echo "30"
  echo "# Mounting filesystems..."
  mount "$ROOT_PART" "$MOUNT_POINT"
  mkdir -p "$MOUNT_POINT/boot"
  mount "$EFI_PART" "$MOUNT_POINT/boot"

  echo "40"
  echo "# Copying system configuration..."
  log "Copying flake source to $MOUNT_POINT/etc/nixos"
  mkdir -p "$MOUNT_POINT/etc/nixos"
  cp -r "$FLAKE_SOURCE"/* "$MOUNT_POINT/etc/nixos/"

  # Apply user choices to the copied configuration
  log "Applying user choices: timezone=$TIMEZONE, browser=$BROWSER"

  # Set timezone (escape sed metacharacters in timezone string)
  TIMEZONE_ESCAPED=$(printf '%s\n' "$TIMEZONE" | sed 's/[&/\]/\\&/g')
  sed -i "s|time.timeZone = \"UTC\";|time.timeZone = \"$TIMEZONE_ESCAPED\";|" \
    "$MOUNT_POINT/etc/nixos/modules/core.nix"

  # Browser choice: if Firefox, swap Brave for Firefox in apps.nix and security.nix
  if [[ "$BROWSER" == "firefox" ]]; then
    log "Switching browser to Firefox"
    APPS="$MOUNT_POINT/etc/nixos/modules/apps.nix"
    SEC="$MOUNT_POINT/etc/nixos/modules/security.nix"

    # apps.nix: replace browser package and marker
    sed -i 's/# INSTALLER_BROWSER: brave/# INSTALLER_BROWSER: firefox/' "$APPS"
    sed -i 's/brave # Privacy-focused Chromium fork/firefox # Open source browser/' "$APPS"
    # apps.nix: replace MIME associations
    sed -i 's/# INSTALLER_MIME: brave-browser.desktop/# INSTALLER_MIME: firefox.desktop/' "$APPS"
    sed -i 's/brave-browser\.desktop/firefox.desktop/g' "$APPS"

    # Validate browser swap succeeded
    if ! grep -q 'firefox # Open source browser' "$APPS"; then
      install_fail "Failed to switch browser to Firefox in apps.nix"
    fi

    # security.nix: replace Firejail profile
    sed -i 's|brave = {|firefox = {|' "$SEC"
    # shellcheck disable=SC2016
    sed -i 's|\${pkgs.brave}/bin/brave|\${pkgs.firefox}/bin/firefox|' "$SEC"
    sed -i 's|chromium-browser.profile|firefox.profile|' "$SEC"

    # Validate Firejail browser swap succeeded
    if ! grep -q 'firefox = {' "$SEC"; then
      install_fail "Failed to switch Firejail profile to Firefox in security.nix"
    fi

    # security.nix: swap Brave telemetry blocks for Firefox ones
    sed -i 's|0.0.0.0 telemetry.brave.com|0.0.0.0 telemetry.mozilla.org|' "$SEC"
    sed -i 's|0.0.0.0 laptop-updates.brave.com|0.0.0.0 incoming.telemetry.mozilla.org|' "$SEC"
    sed -i 's|0.0.0.0 variations.brave.com|0.0.0.0 normandy.cdn.mozilla.net|' "$SEC"

    log "Browser switch to Firefox completed and validated"
  fi

  # Re-check network if Firefox was selected (it requires download during install)
  if [[ "$BROWSER" == "firefox" ]] && ! has_network; then
    install_fail "Network connection lost. Firefox requires internet to install.\n\nPlease reconnect and retry, or restart the installer to choose Brave."
  fi

  echo "50"
  echo "# Installing Stronk 1 (this may take several minutes)..."
  log "Running nixos-install --flake path:$MOUNT_POINT/etc/nixos#stronk-$MODEL"
  nixos-install \
    --flake "path:$MOUNT_POINT/etc/nixos#stronk-$MODEL" \
    --no-root-passwd \
    --no-channel-copy \
    2>&1 | tee -a "$LOG_FILE"

  echo "90"
  echo "# Finalizing installation..."
  log "Unmounting filesystems"
  umount -R "$MOUNT_POINT"

  echo "100"
  echo "# Installation complete!"
  log "Installation complete"

) | zenity --progress \
  --title="Installing Stronk 1" \
  --text="Preparing..." \
  --percentage=0 \
  --auto-close \
  --no-cancel \
  --width=450 \
  || {
    log "Installation failed — see $LOG_FILE"
    # Show specific error if available, otherwise generic message
    ERROR_MSG="Installation failed. Check the log at:\n$LOG_FILE\n\nYou can open a terminal to investigate."
    if [[ -f "$INSTALL_ERROR_FILE" ]]; then
      ERROR_MSG=$(cat "$INSTALL_ERROR_FILE")
      rm -f "$INSTALL_ERROR_FILE"
    fi
    zenity --error \
      --title="Installation Failed" \
      --text="$ERROR_MSG" \
      --width=400
    umount -R "$MOUNT_POINT" 2>/dev/null || true
    exit 1
  }

# ── Step 8: Completion (9.8) ───────────────────────────────────────────

zenity --info \
  --title="Installation Complete" \
  --text="<b>Stronk 1 has been installed.</b>\n\nTo start using Stronk 1:\n\n  1. Remove the USB drive\n  2. Reboot your computer\n\nYour computer will boot directly into Stronk 1." \
  --width=400 --height=220

log "User dismissed completion dialog"
