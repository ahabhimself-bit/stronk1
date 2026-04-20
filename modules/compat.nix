# Stronk 1 — Windows compatibility layer
# Part 2: Wine/Proton, DXVK, VKD3D-Proton for running Windows apps on Stronk
#
# NOT included in the Phase 0 ISO (adds ~1GB). Add to commonModules in flake.nix
# when Phase 1 begins, or enable per-config for daily-driver builds.
{ config, pkgs, lib, ... }:

{
  # ── 32-bit support — required for most Windows apps ────────────────

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver       # VA-API (Braswell/Apollo Lake)
      intel-vaapi-driver       # Older VA-API fallback
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-vaapi-driver
    ];
  };

  # 32-bit audio via PipeWire (Wine apps need it)
  services.pipewire.alsa.support32Bit = lib.mkForce true;

  # ── Wine Staging — esync/fsync patches for better game perf ────────

  environment.systemPackages = with pkgs; [
    wineWowPackages.staging    # 32+64-bit Wine with staging patches (esync, fsync)
    winetricks                 # Installs vcredist, dotnet, dxvk, vkd3d per-prefix
    vulkan-tools               # vulkaninfo — useful for debugging GPU caps
  ];

  # ── Vulkan — required by DXVK and VKD3D-Proton ────────────────────
  # DXVK (DX9/10/11 → Vulkan) and VKD3D-Proton (DX12 → Vulkan) are
  # installed per-prefix via winetricks or Bottles, not system-wide.
  # The system just needs working Vulkan drivers (mesa ANV on Intel).

  environment.sessionVariables = {
    WINEESYNC = "1";
    WINEFSYNC = "1";
  };

  # ── Bottles — Wine prefix manager (via Flatpak) ───────────────────
  # Bottles provides a GUI for creating/managing Wine prefixes, installing
  # DXVK/VKD3D per-app, and running Windows apps without manual config.
  # Install via: flatpak install flathub com.usebottles.bottles
  # (The Forge will handle this once functional; Flatpak is already enabled in apps.nix)

  # ── Gamemode — optional performance optimization ───────────────────

  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 10;
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
    };
  };

  # ── Kernel tweaks for Wine/gaming ──────────────────────────────────

  boot.kernel.sysctl = {
    # Raise file descriptor limit for esync
    "fs.file-max" = 524288;
  };

  # Raise per-user nofile limit for esync
  security.pam.loginLimits = [
    { domain = "*"; type = "hard"; item = "nofile"; value = "524288"; }
    { domain = "*"; type = "soft"; item = "nofile"; value = "524288"; }
  ];
}
