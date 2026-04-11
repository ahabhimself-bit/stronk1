# Stronk 1 — Core system configuration
# Steps 3.1-3.5: Minimal base, systemd, disabled services, journald, networking
{ config, pkgs, lib, ... }:

{
  # System identity
  system.stateVersion = "24.11";
  networking.hostName = "stronk";

  # ── Boot — UEFI (MrChromebox Full ROM) ──────────────────────────────

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest LTS kernel for best Chromebook hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── Locale ──────────────────────────────────────────────────────────

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  time.timeZone = "UTC"; # Installer will set user's timezone

  # ── Filesystem ──────────────────────────────────────────────────────

  fileSystems."/" = {
    device = "/dev/disk/by-label/stronk-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/STRONK-BOOT";
    fsType = "vfat";
  };

  # ── User account — single user, auto-login, no password ────────────

  users.users.stronk = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
    initialPassword = "";
    description = "Stronk User";
    home = "/home/stronk";
  };

  # Passwordless sudo
  security.sudo.wheelNeedsPassword = false;

  # ── Networking — NetworkManager for WiFi + Ethernet (Step 3.5) ─────

  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # ── Nix settings ───────────────────────────────────────────────────

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Default to no unfree packages — GPL v3 project
  # apps.nix overrides this for Brave browser
  nixpkgs.config.allowUnfree = lib.mkDefault false;

  # ── Minimal base packages ──────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    coreutils
    util-linux
    usbutils
    pciutils
    iw              # WiFi diagnostics
    lshw            # Hardware listing
  ];

  # ── systemd — minimal dependency chain (Step 3.2) ──────────────────

  # Boot directly to graphical target
  systemd.targets.graphical.enable = true;

  # ── Disable unnecessary services (Step 3.3) ────────────────────────

  services.avahi.enable = false;          # No mDNS/printer discovery
  services.printing.enable = false;       # No CUPS
  services.openssh.enable = false;        # No SSH server
  services.xserver.enable = lib.mkDefault false; # Prefer Wayland; COSMIC module may override

  # Limit supported filesystems (squashfs added for live ISO boot)
  boot.supportedFilesystems = lib.mkDefault [ "ext4" "vfat" "ntfs" "squashfs" ];

  # Disable unused systemd services
  systemd.services."systemd-rfkill".enable = lib.mkDefault true; # Keep — needed for WiFi toggle
  systemd.services."ModemManager".enable = lib.mkDefault false;

  # ── Journald — volatile storage, 50MB cap (Step 3.4) ──────────────

  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=50M
    RuntimeMaxFileSize=10M
  '';
}
