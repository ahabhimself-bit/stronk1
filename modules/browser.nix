# Stronk 1 — Browser configuration
# Declares stronk.browser option ("brave" or "firefox") and wires up:
#   - Package installation
#   - MIME default associations
#   - Firejail sandboxing profile
#   - Telemetry host blocks
# The installer sets stronk.browser in /etc/nixos/modules/browser-choice.nix
# instead of sed-replacing config files.
{ config, pkgs, lib, ... }:

let
  cfg = config.stronk;
  isBrave = cfg.browser == "brave";
in
{
  options.stronk.browser = lib.mkOption {
    type = lib.types.enum [ "brave" "firefox" ];
    default = "brave";
    description = "Default web browser for Stronk 1.";
  };

  config = {
    environment.systemPackages = [
      (if isBrave then pkgs.brave else pkgs.firefox)
    ];

    xdg.mime.defaultApplications =
      let desktop = if isBrave then "brave-browser.desktop" else "firefox.desktop";
      in {
        "text/html" = desktop;
        "x-scheme-handler/http" = desktop;
        "x-scheme-handler/https" = desktop;
      };

    programs.firejail.wrappedBinaries = if isBrave then {
      brave = {
        executable = "${pkgs.brave}/bin/brave";
        profile = "${pkgs.firejail}/etc/firejail/chromium-browser.profile";
        extraArgs = [ "--seccomp" "--noroot" "--caps.drop=all" ];
      };
    } else {
      firefox = {
        executable = "${pkgs.firefox}/bin/firefox";
        profile = "${pkgs.firejail}/etc/firejail/firefox.profile";
        extraArgs = [ "--seccomp" "--noroot" "--caps.drop=all" ];
      };
    };

    networking.extraHosts = if isBrave then ''
      0.0.0.0 telemetry.brave.com
      0.0.0.0 laptop-updates.brave.com
      0.0.0.0 variations.brave.com
    '' else ''
      0.0.0.0 telemetry.mozilla.org
      0.0.0.0 incoming.telemetry.mozilla.org
      0.0.0.0 normandy.cdn.mozilla.net
    '';
  };
}
