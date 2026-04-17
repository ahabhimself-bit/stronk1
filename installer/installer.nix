# Stronk 1 — Installer module for the live USB image
# Packages the installer wizard and bundles the flake source for offline installs.
{ config, pkgs, lib, ... }:

let
  # Firmware flash guide (prints step-by-step instructions)
  stronk-firmware-guide = pkgs.writeShellApplication {
    name = "stronk-firmware-guide";
    text = builtins.readFile ./stronk-firmware-guide.sh;
  };

  # Package the installer script with all its runtime dependencies
  stronk-installer = pkgs.writeShellApplication {
    name = "stronk-installer";
    runtimeInputs = with pkgs; [
      zenity
      parted
      dosfstools      # mkfs.vfat
      e2fsprogs       # mkfs.ext4
      util-linux      # lsblk, mount, umount, findmnt
      coreutils
      gnugrep
      gnused
      gawk
      iputils         # ping (for network check)
      nixos-install-tools
    ];
    text = builtins.readFile ./stronk-install.sh;
  };

  # Bundle the flake source, excluding non-essential files
  flake-source = builtins.path {
    name = "stronk-flake-source";
    path = ../.;
    filter = path: type:
      let
        baseName = baseNameOf path;
      in
      !(baseName == ".git"
        || baseName == ".claude"
        || lib.hasSuffix ".docx" baseName
        || baseName == "Stronk1_TODO.md"
        || baseName == "result");
  };

  # Minimal firmware: only Intel WiFi + GPU for our target Chromebooks.
  # Full linux-firmware is ~500MB and includes AMD, Qualcomm, MediaTek, etc.
  # Our 3 targets all use Intel 7265 WiFi + Intel HD Graphics (i915).
  stronk-firmware = pkgs.runCommand "stronk-firmware" { } ''
    mkdir -p $out/lib/firmware/i915
    # Intel 7265 WiFi firmware
    cp ${pkgs.linux-firmware}/lib/firmware/iwlwifi-7265* $out/lib/firmware/
    # Intel i915 GPU firmware — only the generations we target:
    #   chv_* = Cherryview/Braswell (KEFKA/SETZER: N3060 HD 400)
    #   bxt_* = Broxton/Apollo Lake (SNAPPY: N3350 HD 500)
    # Full i915/ is ~80MB covering every Intel GPU ever; we need ~2MB.
    for pattern in chv bxt; do
      for f in ${pkgs.linux-firmware}/lib/firmware/i915/''${pattern}_*; do
        [ -f "$f" ] && cp "$f" $out/lib/firmware/i915/
      done
    done
  '';

in
{
  # Include the installer, firmware guide, and desktop entry
  environment.systemPackages = [
    stronk-installer
    stronk-firmware-guide
    # Desktop entry must be a package on XDG_DATA_DIRS, not in /etc/xdg/
    (pkgs.makeDesktopItem {
      name = "stronk-installer";
      desktopName = "Install Stronk 1";
      comment = "Install Stronk 1 to this computer's internal storage";
      exec = "stronk-installer";
      icon = "drive-harddisk";
      categories = [ "System" ];
    })
  ];

  # Copy the flake source into the live image at /etc/stronk-flake
  environment.etc."stronk-flake".source = flake-source;

  # Include only the firmware needed for target Chromebooks (Intel WiFi + GPU + SOF audio).
  # This replaces linux-firmware (~500MB) with ~50MB of Intel-specific files.
  hardware.enableRedistributableFirmware = false;
  hardware.firmware = [
    stronk-firmware
    pkgs.sof-firmware
  ];
}
