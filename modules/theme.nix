# Stronk 1 — Theming & branding
# Step 7: Stronk themes, wallpaper, branding, notification policy
{ config, pkgs, lib, ... }:

let
  # ── Stronk brand palette (sRGB 0.0–1.0) ──────────────────────────
  #
  # Accent: trust blue (#3B82F6) — privacy, reliability, calm
  # The same accent is used in both Light and Dark themes for brand
  # consistency. COSMIC derives button, link, and focus colors from it.

  accent       = "Some((red: 0.231, green: 0.510, blue: 0.965))";  # #3B82F6
  success      = "Some((red: 0.133, green: 0.773, blue: 0.369))";  # #22C55E
  warning      = "Some((red: 0.961, green: 0.620, blue: 0.043))";  # #F59E0B
  destructive  = "Some((red: 0.937, green: 0.267, blue: 0.267))";  # #EF4444

  # ── COSMIC theme package ──────────────────────────────────────────
  #
  # COSMIC reads system defaults from $XDG_DATA_DIRS/cosmic/.
  # Each ThemeBuilder field is a separate file in a versioned directory.
  # We override only the fields that define Stronk branding; COSMIC
  # fills in everything else from its built-in palette.

  # ── Stronk wallpaper package ───────────────────────────────────────
  #
  # SVG wallpapers for light and dark modes. COSMIC's background config
  # points to these paths under $XDG_DATA_DIRS/stronk/wallpapers/.

  stronk-wallpapers = pkgs.runCommand "stronk-wallpapers" {
    src = ../assets/wallpapers;
  } ''
    mkdir -p $out/share/stronk/wallpapers
    cp $src/stronk-light.svg $out/share/stronk/wallpapers/
    cp $src/stronk-dark.svg  $out/share/stronk/wallpapers/
  '';

  stronk-cosmic-themes = pkgs.runCommand "stronk-cosmic-themes" { } ''
    # ── Stronk Light (default theme) ──────────────────────────────
    light=$out/share/cosmic/com.system76.CosmicTheme.Light.Builder/v1
    mkdir -p "$light"

    # Brand accent + semantic colors
    echo '${accent}'      > "$light/accent"
    echo '${success}'     > "$light/success"
    echo '${warning}'     > "$light/warning"
    echo '${destructive}' > "$light/destructive"

    # Backgrounds: clean near-white with subtle blue undertone
    echo 'Some((red: 0.973, green: 0.980, blue: 0.988, alpha: 1.0))' > "$light/bg_color"
    echo 'Some((red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))'       > "$light/primary_container_bg"
    echo 'Some((red: 0.945, green: 0.961, blue: 0.976, alpha: 1.0))' > "$light/secondary_container_bg"

    # Subtle blue tint on neutral surfaces (panels, buttons)
    echo 'Some((red: 0.200, green: 0.400, blue: 0.700))' > "$light/neutral_tint"

    # No frosted glass — saves GPU on low-end Chromebooks
    echo 'false' > "$light/is_frosted"

    # ── Stronk Dark ───────────────────────────────────────────────
    dark=$out/share/cosmic/com.system76.CosmicTheme.Dark.Builder/v1
    mkdir -p "$dark"

    # Same brand colors
    echo '${accent}'      > "$dark/accent"
    echo '${success}'     > "$dark/success"
    echo '${warning}'     > "$dark/warning"
    echo '${destructive}' > "$dark/destructive"

    # Backgrounds: deep navy, not pure black (easier on the eyes)
    echo 'Some((red: 0.059, green: 0.090, blue: 0.165, alpha: 1.0))' > "$dark/bg_color"
    echo 'Some((red: 0.118, green: 0.161, blue: 0.231, alpha: 1.0))' > "$dark/primary_container_bg"
    echo 'Some((red: 0.200, green: 0.255, blue: 0.333, alpha: 1.0))' > "$dark/secondary_container_bg"

    # Same blue tint for brand consistency
    echo 'Some((red: 0.200, green: 0.400, blue: 0.700))' > "$dark/neutral_tint"

    echo 'false' > "$dark/is_frosted"

    # ── Theme mode: light by default ──────────────────────────────
    mode=$out/share/cosmic/com.system76.CosmicTheme.Mode/v1
    mkdir -p "$mode"
    echo 'false' > "$mode/is_dark"
    echo 'false' > "$mode/auto_switch"

    # ── Default wallpaper (COSMIC background config) ──────────────
    # COSMIC reads com.system76.CosmicBackground for wallpaper state.
    # Point to Stronk wallpaper; users can override in Settings.
    bg=$out/share/cosmic/com.system76.CosmicBackground/v1
    mkdir -p "$bg"
    cat > "$bg/all" <<'WALL'
[
  {
    "output": "all",
    "source": "Path(\"/run/current-system/sw/share/stronk/wallpapers/stronk-light.svg\")",
    "filter_by_theme": true,
    "rotation_frequency": 0,
    "filter_method": "Lanczos",
    "scaling_mode": "Zoom"
  }
]
WALL
  '';

in
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

  # ── COSMIC theme defaults (Steps 7.1–7.3) ────────────────────────
  #
  # Stronk Light (default): clean near-white, blue accent, high readability
  # Stronk Dark: deep navy backgrounds, same blue accent
  # Stronk High Contrast: COSMIC's built-in HighContrast mode already
  #   meets WCAG 2.1 AA (4.5:1 normal text, 3:1 large text). Users
  #   toggle it in Settings → Accessibility. Our accent/semantic colors
  #   carry over automatically.

  environment.systemPackages = [
    stronk-cosmic-themes  # Deploys theme + wallpaper configs to $XDG_DATA_DIRS/cosmic/
    stronk-wallpapers     # SVG wallpapers in $XDG_DATA_DIRS/stronk/wallpapers/
    # COSMIC ships cosmic-icons; no separate GTK icon theme needed
  ];

  # ── Notification policy (Step 7.7) ─────────────────────────────────
  # COSMIC handles notifications natively.
  # Stronk policy: only user-relevant events, zero promotional content.
  # Enforced by: no apps that send promos, no store with notification spam,
  # Brave configured with notifications off by default.

  # ── GTK theme fallback (for non-COSMIC GTK apps like Brave) ───────

  environment.etc."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-application-prefer-dark-theme=0
    gtk-icon-theme-name=Adwaita
    gtk-font-name=Inter 10
  '';
}
