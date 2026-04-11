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

  # Squashfs compression — xz achieves ~10-15% better ratio than zstd for OS images
  isoImage.squashfsCompression = "xz -Xdict-size 100%";

  # ── Size optimization ────────────────────────────────────────────────

  # Don't include full documentation
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  # Limit firmware to what our target hardware needs (Intel WiFi + GPU + audio)
  hardware.enableAllFirmware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;

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
