# Stronk 1 — Build-time assertions (CI gates)
# These assertions cause Nix evaluation to FAIL if invariants are violated.
# The CI "evaluate" step catches violations without needing hardware.
{ config, pkgs, lib, ... }:

{
  assertions = [
    # ── Security baseline ────────────────────────────────────────────
    {
      assertion = config.networking.firewall.enable;
      message = "Stronk requires firewall enabled (networking.firewall.enable)";
    }
    {
      assertion = config.security.apparmor.enable;
      message = "Stronk requires AppArmor enabled (security.apparmor.enable)";
    }
    {
      assertion = config.networking.nftables.enable;
      message = "Stronk requires nftables backend (networking.nftables.enable)";
    }
    {
      assertion = config.networking.firewall.allowedTCPPorts == [];
      message = "Stronk ships with zero open TCP ports";
    }
    {
      assertion = config.networking.firewall.allowedUDPPorts == [];
      message = "Stronk ships with zero open UDP ports";
    }
    {
      assertion = !config.services.pulseaudio.enable;
      message = "Stronk uses PipeWire, not PulseAudio";
    }
    {
      assertion = config.services.pipewire.enable;
      message = "Stronk requires PipeWire for audio";
    }
    {
      assertion = !config.system.autoUpgrade.enable;
      message = "Stronk does not auto-upgrade — user controls updates";
    }
    {
      assertion = config.programs.firejail.enable;
      message = "Stronk requires Firejail for browser sandboxing";
    }
    {
      assertion = config.services.flatpak.enable;
      message = "Stronk requires Flatpak for The Forge app installs";
    }

    # ── Privacy baseline ─────────────────────────────────────────────
    {
      assertion = config.boot.kernel.sysctl."kernel.dmesg_restrict" == 1;
      message = "Stronk requires restricted dmesg";
    }
    {
      assertion = config.boot.kernel.sysctl."kernel.kptr_restrict" == 2;
      message = "Stronk requires kernel pointer restriction";
    }
    {
      assertion = config.boot.kernel.sysctl."net.ipv4.ip_forward" == 0;
      message = "Stronk must not forward packets";
    }

    # ── Desktop baseline ─────────────────────────────────────────────
    {
      assertion = config.services.desktopManager.cosmic.enable;
      message = "Stronk requires COSMIC desktop";
    }
    {
      assertion = !config.services.desktopManager.cosmic.xwayland.enable;
      message = "Stronk is Wayland-only — XWayland must be disabled";
    }
    {
      assertion = config.services.pipewire.wireplumber.enable;
      message = "Stronk requires WirePlumber session manager";
    }
  ];
}
