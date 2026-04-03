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
      git             # git init for flake eval
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

  # Include hardware firmware in the live image so nixos-install can
  # find them locally (enables offline installs for all target models)
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
  ];
}
