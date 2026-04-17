# Stronk 1 — Privacy & security configuration
# Step 6: Firewall, AppArmor, kernel hardening, zero telemetry
{ config, pkgs, lib, ... }:

{
  # ── nftables firewall — default-deny inbound (Step 6.2) ────────────

  networking.firewall = {
    enable = true;
    # Default-deny inbound, allow outbound
    allowedTCPPorts = [ ]; # No listening services
    allowedUDPPorts = [ ]; # No listening services
    # Log denied packets (for debugging, can disable later)
    logReversePathDrops = true;
  };

  # Use nftables backend
  networking.nftables.enable = true;

  # ── Kernel hardening (Step 6.3) ────────────────────────────────────

  boot.kernel.sysctl = {
    # Restrict kernel pointer exposure
    "kernel.kptr_restrict" = 2;
    # Restrict dmesg to root
    "kernel.dmesg_restrict" = 1;
    # Enable ASLR (full randomization)
    "kernel.randomize_va_space" = 2;
    # NOTE: user namespaces are NOT restricted because Flatpak's bubblewrap
    # sandbox requires them. Flatpak apps are sandboxed via bubblewrap instead.
    # (kernel.unprivileged_userns_clone is also Debian-specific, not mainline.)
    # Restrict perf events
    "kernel.perf_event_paranoid" = 3;
    # Restrict ptrace
    "kernel.yama.ptrace_scope" = 1;
    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    # Disable IP forwarding
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
  };

  # Kernel boot parameters for hardening
  boot.kernelParams = [
    "page_alloc.shuffle=1"    # Page allocator randomization
    "slab_nomerge"            # Prevent slab merging
    "init_on_alloc=1"         # Zero memory on allocation
    "init_on_free=1"          # Zero memory on free
  ];

  # ── AppArmor (Step 6.4) ───────────────────────────────────────────

  security.apparmor = {
    enable = true;
    # Kill processes that violate their AppArmor profile
    killUnconfinedConfinables = false; # Don't kill — just log for now
  };

  # ── Firejail sandboxing (Step 6.1) ────────────────────────────────

  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      brave = {
        executable = "${pkgs.brave}/bin/brave";
        profile = "${pkgs.firejail}/etc/firejail/chromium-browser.profile";
      };
    };
  };

  # ── No telemetry, no tracking, no analytics (Steps 6.5-6.9) ───────

  # Disable automatic updates — user-initiated only
  system.autoUpgrade.enable = false;

  # Ensure no services phone home
  # NetworkManager: disable connectivity check (pings connectivity servers)
  networking.networkmanager.settings = {
    connectivity = {
      enabled = "false";
    };
  };

  # Block browser telemetry domains via /etc/hosts
  # Installer swaps these to Firefox equivalents when Firefox is chosen
  networking.extraHosts = ''
    # Stronk 1: Block telemetry endpoints (Brave — swapped by installer for Firefox)
    0.0.0.0 telemetry.brave.com
    0.0.0.0 laptop-updates.brave.com
    0.0.0.0 variations.brave.com
  '';

  # Audit tools (tcpdump, apparmor-utils) can be installed later for verification.
  # They are not shipped in the base image to minimize closure size.
}
