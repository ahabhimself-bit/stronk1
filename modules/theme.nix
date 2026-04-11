# Stronk 1 — Theming & branding
# Step 7: Stronk themes, wallpaper, branding, notification policy
{ config, pkgs, lib, ... }:

{
  # ── Stronk branding in system info (Step 7.5) ─────────────────────

  environment.etc."os-release".text = lib.mkForce ''
    NAME="Stronk 1"
    PRETTY_NAME="Stronk 1"
    ID=stronk
    ID_LIKE=nixos
    VERSION_ID="0.1.0-alpha"
    VERSION="0.1.0-alpha (Phase 0)"
    HOME_URL="https://stronk.computer"
    DOCUMENTATION_URL="https://stronk.computer/docs"
    BUG_REPORT_URL="https://github.com/ahabhimself-bit/stronk1/issues"
    LOGO="stronk-logo"
  '';

  # ── COSMIC theme configuration (Steps 7.1-7.3) ────────────────────
  # COSMIC uses a TOML-based theme system.
  # Themes are applied via cosmic-settings or config files in
  # ~/.config/cosmic/. System defaults go here, user can override.
  #
  # Stronk Light (default): clean, high-contrast, accessible
  # Stronk Dark: reduced eye strain, same accessibility
  # Stronk High Contrast: WCAG 2.1 AA compliant
  #
  # Theme colors will be defined once we can test COSMIC interactively.
  # For now, we configure COSMIC to use its built-in light theme as default.

  # ── Wallpaper (Step 7.4) ───────────────────────────────────────────
  # Custom wallpaper will be added as an asset.
  # For now, create a placeholder directory for branding assets.

  environment.etc."stronk/branding/README".text = ''
    Stronk 1 branding assets directory.
    Place wallpapers, icons, and theme files here.
  '';

  # ── Notification policy (Step 7.7) ─────────────────────────────────
  # COSMIC handles notifications natively.
  # Stronk policy: only user-relevant events, zero promotional content.
  # This is enforced by:
  # 1. No apps that send promotional notifications
  # 2. No app store that allows notification spam
  # 3. Brave configured with notifications off by default

  # ── GTK theme fallback (for non-COSMIC GTK apps) ──────────────────

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme  # Fallback icons for GTK apps
  ];

  # Set GTK theme defaults for non-COSMIC apps
  environment.etc."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-application-prefer-dark-theme=0
    gtk-icon-theme-name=Adwaita
    gtk-font-name=Inter 10
  '';
}
