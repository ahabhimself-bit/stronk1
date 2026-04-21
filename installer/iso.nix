# Stronk 1 — ISO image build configuration
# Produces a bootable USB live image with the Stronk installer wizard.
{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    ./installer.nix
  ];

  # ISO label
  isoImage.isoName = "stronk1-${config.system.nixos.label}-x86_64.iso";
  isoImage.volumeID = "STRONK1";

  # Make it a live system — UEFI boot (MrChromebox firmware)
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;

  # Squashfs compression — xz with BCJ filter improves compression of x86 binaries
  isoImage.squashfsCompression = "xz -Xdict-size 100% -Xbcj x86";

  # ── Size optimization ────────────────────────────────────────────────

  # Don't include full documentation
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  # Limit firmware to what our target hardware needs (Intel WiFi + GPU + audio)
  hardware.enableAllFirmware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;

  stronk.isLiveISO = true;

  # Flatpak is not needed during live session — only after install to internal storage
  services.flatpak.enable = lib.mkForce false;

  # COSMIC's own portal is sufficient — drop the GTK fallback portal to save closure size
  xdg.portal.extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-cosmic ];

  # ── Disable services enabled by COSMIC module but not needed ─────────

  # No Bluetooth on target Chromebooks (Intel 7265 supports it, but not needed for installer)
  hardware.bluetooth.enable = lib.mkForce false;

  # No GNOME keyring — we don't use GNOME apps or need a secret store in the live session
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # No GVFS — no network mounts or trash in the live session
  services.gvfs.enable = lib.mkForce false;

  # No speech dispatcher — saves ~50MB of speech synthesis deps
  services.speechd.enable = lib.mkForce false;

  # No ModemManager — Chromebooks don't have cellular modems
  systemd.services.ModemManager.enable = lib.mkForce false;

  # Strip NM VPN plugins — not needed for WiFi-only installer
  networking.networkmanager.plugins = lib.mkForce [];

  # No default packages (nano, perl, strace, etc.) — saves ~100MB
  environment.defaultPackages = lib.mkForce [];

  # The live system should not try to mount internal storage filesystems.
  # Core.nix declares / and /boot with disk labels — override for live mode.
  fileSystems."/" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
  };
  # Can't delete a fileSystems entry, so mount a tiny tmpfs as a no-op
  fileSystems."/boot" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
    options = [ "size=1M" ];
  };
}
