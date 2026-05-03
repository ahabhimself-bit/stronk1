# Stronk 1 — Privacy & security configuration
# Phase 0: Firewall, AppArmor, kernel hardening, zero telemetry
# Phase 1: Flatpak sandboxing policy, seccomp enforcement, per-app profiles
{ config, pkgs, lib, ... }:

{
  # ── nftables firewall — default-deny inbound (Step 6.2) ────────────

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    logReversePathDrops = true;
  };

  networking.nftables.enable = true;

  # ── Kernel hardening (Step 6.3) ────────────────────────────────────

  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.randomize_va_space" = 2;
    # User namespaces NOT restricted — Flatpak bubblewrap requires them
    "kernel.perf_event_paranoid" = 3;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv4.tcp_syncookies" = 1;
  };

  boot.kernelParams = [
    "page_alloc.shuffle=1"
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
  ];

  # ── AppArmor (Step 6.4) ───────────────────────────────────────────

  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;
    packages = [ pkgs.apparmor-profiles ];
  };

  # ── Firejail sandboxing (Step 6.1) ────────────────────────────────
  # Browser-specific Firejail profile is in modules/browser.nix

  programs.firejail.enable = true;

  # ── Flatpak sandboxing policy (Phase 1) ───────────────────────────
  # Deny dangerous permissions system-wide. Individual apps get only
  # what they need via XDG Desktop Portals (file chooser, screen share).
  # The Forge enforces this at submission time; this is defense-in-depth.

  systemd.tmpfiles.rules = let
    flatpakOverride = pkgs.writeText "flatpak-global-override" ''
      [Context]
      filesystems=!host;!home;!host-etc;!host-os;xdg-download;

      [Session Bus Policy]
      org.freedesktop.secrets=none
      org.gnome.keyring=none

      [Environment]
      GTK_USE_PORTAL=1
    '';
  in [
    "d /var/lib/flatpak/overrides 0755 root root -"
    "C+ /var/lib/flatpak/overrides/global 0644 root root - ${flatpakOverride}"
  ];

  # ── No telemetry, no tracking, no analytics (Steps 6.5-6.9) ───────

  system.autoUpgrade.enable = false;

  networking.networkmanager.settings = {
    connectivity = {
      enabled = "false";
    };
  };

  # Telemetry host blocks are in modules/browser.nix (browser-specific)
}
