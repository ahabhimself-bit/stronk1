# Stronk 1

**Your Computer. Actually Yours.**

A privacy-first Linux OS for decommissioned Chromebooks, built on NixOS and the COSMIC desktop.

## What is Stronk?

Stronk turns expired Chromebooks into fast, private, fully functional computers. No telemetry. No ads. No mandatory accounts. No bloat. Just five apps, a clean desktop, and your data stays on your machine.

## Target Hardware

| Model | Codename | CPU | RAM | Status |
|-------|----------|-----|-----|--------|
| Dell Chromebook 11 3180 | KEFKA | Intel N3060 | 4GB | Primary |
| HP Chromebook 11 G5 EE | SETZER | Intel N3060 | 2GB | Minimum tier |
| HP Chromebook 11 G6 EE | SNAPPY | Intel N3350 | 4GB | Stretch |

All models require [MrChromebox](https://mrchromebox.tech) UEFI Full ROM firmware.

## What Ships

- **Brave** browser (Firefox available at install)
- **COSMIC Files** file manager
- **COSMIC Terminal**
- **COSMIC Settings**
- **The Forge** app store (stub — coming in Phase 1)

That's it. Five apps. Everything else installs through The Forge.

## Performance Targets

| Metric | Target |
|--------|--------|
| Base image size | < 800 MB |
| Cold boot to desktop | < 15 seconds |
| Idle RAM | < 500 MB |
| Outbound connections at idle | Zero |
| Telemetry | Zero |
| Mandatory accounts | Zero |
| Ads | Zero, forever |

## Building

Requires Nix with flakes enabled.

```bash
# Evaluate all configurations
nix flake check --no-build

# Build the ISO (requires x86_64-linux)
nix build .#packages.x86_64-linux.iso
```

The ISO is also built automatically on every push via GitHub Actions.

## Installing

See [docs/INSTALL.md](docs/INSTALL.md) for the full guide: firmware flash, USB boot, and installation.

## Project Structure

```
flake.nix            # Top-level flake
modules/
  core.nix           # Base system, user, networking, systemd
  desktop.nix        # COSMIC desktop, PipeWire, fonts, input
  apps.nix           # Five pre-installed apps
  security.nix       # Firewall, AppArmor, kernel hardening
  theme.nix          # Branding, GTK fallback, os-release
hardware/
  kefka.nix          # Dell Chromebook 11 3180
  setzer.nix         # HP Chromebook 11 G5 EE
  snappy.nix         # HP Chromebook 11 G6 EE
installer/
  iso.nix            # Live ISO build config
  installer.nix      # Installer module (packages script + flake source)
  stronk-install.sh  # Installer wizard (zenity + nixos-install)
  stronk-firmware-guide.sh  # Firmware flash instructions
```

## License

[GPL v3](LICENSE)
