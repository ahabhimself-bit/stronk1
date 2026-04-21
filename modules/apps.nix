# Stronk 1 — Pre-installed applications
# Step 5: Exactly 5 user-facing apps. Nothing more.
#
# 1. Web browser     — Brave (Firefox available via installer choice)
# 2. File manager    — COSMIC Files
# 3. Terminal        — COSMIC Terminal
# 4. System settings — COSMIC Settings
# 5. The Forge       — Stub app (placeholder)
{ config, pkgs, lib, ... }:

{
  # ── Allow Brave (proprietary) — required for default browser ──────────
  # Brave is unfree; this is the only unfree package we ship.
  # If the installer swaps to Firefox, this setting is harmless.
  nixpkgs.config.allowUnfree = true;

  # ── Flatpak runtime for The Forge (future app installs) ────────────
  services.flatpak.enable = true;

  # ── 1. Web browser — Brave (Step 5.1) ──────────────────────────────
  # INSTALLER_BROWSER: brave
  # The installer sed-replaces the browser block below when Firefox is chosen.

  environment.systemPackages = with pkgs; [
    brave # Privacy-focused Chromium fork

    # ── 5. The Forge — Stub app (Step 5.5) ───────────────────────────
    # Placeholder that opens an about page. Replaced with Rust/Iced client in Phase 1.
    (writeShellApplication {
      name = "the-forge";
      runtimeInputs = [ zenity ];
      text = ''
        zenity --info \
          --title="The Forge" \
          --text="The Forge app store is coming soon.\n\nDiscover apps, themes, and more — all curated for Stronk." \
          --width=400 --height=200
      '';
    })
    (makeDesktopItem {
      name = "the-forge";
      desktopName = "The Forge";
      comment = "Discover apps, themes, and more for Stronk";
      exec = "the-forge";
      icon = "system-software-install";
      categories = [ "System" "PackageManager" ];
    })
  ];

  # Set Brave as default browser
  # INSTALLER_MIME: brave-browser.desktop
  xdg.mime.defaultApplications = {
    "text/html" = "brave-browser.desktop";
    "x-scheme-handler/http" = "brave-browser.desktop";
    "x-scheme-handler/https" = "brave-browser.desktop";
  };

  # ── 2. File manager — COSMIC Files (Step 5.2) ─────────────────────
  # COSMIC Files is included with services.desktopManager.cosmic
  # No cloud storage prompts — it's a local-first file manager

  # ── 3. Terminal — COSMIC Terminal (Step 5.3) ───────────────────────
  # COSMIC Terminal is included with services.desktopManager.cosmic

  # ── 4. System settings — COSMIC Settings (Step 5.4) ───────────────
  # COSMIC Settings is included with services.desktopManager.cosmic

  # ── Hide extra COSMIC apps from launcher (Step 5.6) ───────────────
  # COSMIC ships additional apps we don't want visible. Only 5 user-facing
  # apps should appear: Brave, COSMIC Files, COSMIC Terminal, COSMIC Settings, The Forge.
  # Override .desktop files with NoDisplay=true so they remain installed but hidden.
  environment.etc = lib.listToAttrs (map (id: {
    name = "xdg/applications/${id}.desktop";
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=${id}
      NoDisplay=true
    '';
  }) [
    "com.system76.CosmicStore"
    "com.system76.CosmicTextEditor"
    "com.system76.CosmicEdit"
  ]);
}
