# Stronk 1 — Pre-installed applications
# Step 5: Exactly 5 user-facing apps. Nothing more.
#
# 1. Web browser     — Configured via stronk.browser option (modules/browser.nix)
# 2. File manager    — COSMIC Files
# 3. Terminal        — COSMIC Terminal
# 4. System settings — COSMIC Settings
# 5. The Forge       — COSMIC-native app store
{ config, pkgs, lib, ... }:

{
  # ── Flatpak runtime for The Forge (app installs) ───────────────────
  services.flatpak.enable = true;

  # ── 1. Web browser — see modules/browser.nix (stronk.browser option)

  environment.systemPackages = [
    # ── 5. The Forge — COSMIC-native app store ───────────────────────
    (pkgs.callPackage ../forge {})
  ];

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
