# Stronk 1 — Desktop environment configuration
# Step 4: COSMIC desktop, PipeWire audio, auto-login, fonts
{ config, pkgs, lib, ... }:

{
  # ── COSMIC Desktop (Steps 4.1, 4.2) ────────────────────────────────

  # COSMIC compositor + desktop shell
  # The nixos-cosmic flake module provides services.desktopManager.cosmic
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = false; # No greeter — auto-login

  # ── Auto-login to COSMIC session (Step 4.4) ────────────────────────

  # Use greetd for auto-login directly into COSMIC
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.cosmic-session}/bin/cosmic-session";
        user = "stronk";
      };
    };
  };

  # ── PipeWire audio (Step 4.5) ──────────────────────────────────────

  # Disable PulseAudio — PipeWire replaces it
  hardware.pulseaudio.enable = false;

  # Enable PipeWire + compatibility layers
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false; # x86-64 only, no 32-bit games in scope
    pulse.enable = true;       # PulseAudio compatibility
    wireplumber.enable = true; # Session manager
  };

  # Real-time scheduling for audio (avoids glitches)
  security.rtkit.enable = true;

  # ── Fonts (Step 4.6) ───────────────────────────────────────────────

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # System UI
      inter                    # Clean, modern UI font
      # Monospace
      jetbrains-mono           # Terminal / code font
      # Fallback / emoji
      noto-fonts
      noto-fonts-emoji
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Inter" "Noto Sans" ];
        monospace = [ "JetBrains Mono" "Noto Sans Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # ── Touchpad — ChromeOS-like feel (Step 8.3) ──────────────────
  # All target Chromebooks use Elan I2C touchpads (ELAN0000)

  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;              # Tap-to-click (ChromeOS default)
      naturalScrolling = true;     # Reverse/Australian scrolling (ChromeOS default)
      disableWhileTyping = true;   # Palm rejection while typing
      accelProfile = "adaptive";   # Closest to ChromeOS feel
      clickMethod = "clickfinger"; # Two-finger right-click (ChromeOS style)
    };
  };

  # ── Keyboard — Chrome top-row keys via keyd (Step 8.3) ───────
  # All target Chromebooks share the same Chrome keyboard layout.
  # Search key already sends Super_L — no remapping needed.
  # Top row: action keys by default, F-keys via Search modifier.

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        # Top-row action keys are the default (no remap needed).
        # Search + top row → F1-F10 for apps that need function keys.
      };
      settings.meta = {
        # Search (Super) + top row → F-keys
        back = "f1";
        forward = "f2";
        refresh = "f3";
        zoom = "f4";
        scale = "f5";
        brightnessdown = "f6";
        brightnessup = "f7";
        mute = "f8";
        volumedown = "f9";
        volumeup = "f10";
      };
    };
  };

  # ── Wayland environment ────────────────────────────────────────────

  # Ensure Wayland session variables are set
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";         # Electron/Chromium Wayland
    MOZ_ENABLE_WAYLAND = "1";     # Firefox Wayland
    QT_QPA_PLATFORM = "wayland";  # Qt Wayland
    SDL_VIDEODRIVER = "wayland";   # SDL Wayland
  };

  # XDG Desktop Portal — needed for screen sharing, file dialogs in sandboxed apps
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-cosmic
      xdg-desktop-portal-gtk # Fallback for GTK apps
    ];
    # Prefer COSMIC portal; fall back to GTK for apps that don't support it
    config.common.default = [ "cosmic" "gtk" ];
  };
}
