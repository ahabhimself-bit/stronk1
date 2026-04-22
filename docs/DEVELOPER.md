# Stronk 1 ��� Developer Guide

Internal reference for building, testing, and contributing to Stronk 1.

---

## Prerequisites

- **Nix** with flakes enabled (Determinate Nix recommended)
- **x86_64-linux** for building ISOs (macOS can evaluate but not build)
- **Rust toolchain** for Forge client/backend development
- **PostgreSQL 16+** for Forge backend local development
- **MinIO** (or any S3-compatible store) for Forge backend storage

### Install Nix (macOS or Linux)

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Install Rust

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

---

## Project Layout

```
flake.nix                # Top-level Nix flake — all system configs
modules/
  core.nix               # Base system: user, locale, networking, systemd
  desktop.nix            # COSMIC desktop, PipeWire, fonts, touchpad/keyboard
  apps.nix               # Five pre-installed apps (Brave, Files, Terminal, Settings, Forge stub)
  security.nix           # Firewall (nftables), AppArmor, kernel hardening, Firejail
  theme.nix              # Stronk themes, wallpapers, os-release branding
  compat.nix             # Phase 1: Wine/Proton, DXVK/VKD3D, Bottles, gamemode
hardware/
  kefka.nix              # Dell Chromebook 11 3180 (Braswell, SOF audio)
  setzer.nix             # HP Chromebook 11 G5 EE (Braswell, SOF audio, 2GB)
  snappy.nix             # HP Chromebook 11 G6 EE (Apollo Lake, AVS audio)
installer/
  iso.nix                # Live ISO build config (squashfs, live overrides)
  installer.nix          # NixOS module: bundles installer script + flake source
  stronk-install.sh      # Zenity-based installer wizard
  stronk-firmware-guide.sh  # MrChromebox firmware flash procedure
forge/                   # COSMIC-native Forge client (Rust + libcosmic/Iced)
forge-backend/           # Forge backend API (Axum + PostgreSQL + S3)
assets/wallpapers/       # SVG wallpapers for light and dark themes
docs/
  INSTALL.md             # End-user installation guide
  DEVELOPER.md           # This file
```

---

## Building

### Evaluate configurations (works on macOS)

```sh
nix flake check --no-build
```

This evaluates all 7 NixOS configurations + the ISO derivation without building.

### Build the ISO (requires x86_64-linux)

```sh
nix build .#packages.x86_64-linux.iso --print-build-logs
```

The ISO appears at `result/iso/*.iso`. CI builds this on every push to `main`.

### Available NixOS configurations

| Config | Description |
|--------|-------------|
| `stronk-generic` | Generic x86-64 (Phase 0, no hardware-specific modules) |
| `stronk-kefka` | Dell Chromebook 11 3180 (Phase 0) |
| `stronk-setzer` | HP Chromebook 11 G5 EE (Phase 0) |
| `stronk-snappy` | HP Chromebook 11 G6 EE (Phase 0) |
| `stronk-kefka-full` | KEFKA + Phase 1 (Wine/Proton compat layer) |
| `stronk-setzer-full` | SETZER + Phase 1 |
| `stronk-snappy-full` | SNAPPY + Phase 1 |

---

## Forge Client Development

The Forge client is a COSMIC-native desktop app built with `libcosmic` (Iced toolkit).

```sh
cd forge
cargo build
```

The client depends on `libcosmic`, which requires Linux with Wayland headers. On macOS, `cargo check` works for type checking but `cargo build` will fail on native dependencies.

### Architecture

- `src/main.rs` — COSMIC `Application` impl, message handling, navigation
- `src/flathub.rs` — Flathub REST API client (search, popular, categories, app detail)
- `src/flatpak.rs` �� Local `flatpak` CLI wrapper (install, uninstall, update, permissions)
- `src/pages/` — UI pages: Browse, Installed, Updates, AppDetail

The client currently talks directly to Flathub's API. It will be extended to also query the Forge Backend for Stronk-curated apps.

---

## Forge Backend Development

The backend is a Rust service (Axum) that handles app submissions, security scanning, and serves the Forge catalog.

### Local setup

1. Start PostgreSQL:

```sh
# Using Docker:
docker run -d --name forge-pg -e POSTGRES_USER=forge -e POSTGRES_PASSWORD=forge -e POSTGRES_DB=forge -p 5432:5432 postgres:16

# Or use your system PostgreSQL and create the database:
createdb forge
```

2. Start MinIO (S3-compatible storage):

```sh
docker run -d --name forge-minio -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address :9001
# Default credentials: minioadmin/minioadmin
# Create the bucket via console at http://localhost:9001 or:
mc alias set local http://localhost:9000 minioadmin minioadmin
mc mb local/forge-packages
```

3. Run the backend:

```sh
cd forge-backend
S3_ACCESS_KEY=minioadmin S3_SECRET_KEY=minioadmin \
  DATABASE_URL=postgres://forge:forge@localhost/forge cargo run
```

The server starts on `http://localhost:3000`. Migrations run automatically on startup.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgres://forge:forge@localhost/forge` | PostgreSQL connection string |
| `LISTEN_ADDR` | `0.0.0.0:3000` | HTTP listen address |
| `S3_ENDPOINT` | `http://localhost:9000` | S3-compatible endpoint |
| `S3_BUCKET` | `forge-packages` | Storage bucket name |
| `S3_REGION` | `us-east-1` | S3 region |
| `S3_ACCESS_KEY` | *(required)* | S3 access key |
| `S3_SECRET_KEY` | *(required)* | S3 secret key |
| `CLAMAV_ADDR` | `localhost:3310` | ClamAV daemon TCP address |
| `ALLOWED_ORIGINS` | `http://localhost:3000` | Comma-separated CORS allowed origins |
| `RUST_LOG` | `forge_backend=info` | Log level (tracing filter) |

### API endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check (tests DB connection) |
| `GET` | `/api/v1/apps` | List approved apps (query: `category`, `search`, `page`, `per_page`) |
| `GET` | `/api/v1/apps/{id}` | App detail with full metadata and permissions |
| `POST` | `/api/v1/apps/{id}/download` | Get download URL (increments download count) |
| `POST` | `/api/v1/submissions` | Submit a new app (multipart: `metadata` JSON + `bundle` file) |
| `GET` | `/api/v1/submissions/{id}/status` | Check submission scan status |

### Submission flow

1. Developer uploads a Flatpak bundle via `POST /api/v1/submissions` (multipart form with JSON metadata + `.flatpak` file)
2. Backend stores the submission in PostgreSQL with status `pending`
3. Background task: status → `scanning`, ClamAV scans the bundle, permissions are extracted and checked
4. If ClamAV is clean AND no forbidden permissions (`filesystem=host`, `filesystem=home`, `filesystem=host-etc`, `filesystem=host-os`): status → `approved`, bundle uploaded to S3
5. If any check fails: status → `rejected`, scan report stored for developer review

### Security scanning

The scanner (`src/scanner.rs`) enforces two checks:

**ClamAV** — Scans the `.flatpak` bundle for malware via TCP connection to the `clamd` daemon. Install ClamAV for local testing:

```sh
# macOS
brew install clamav
# Linux
sudo apt install clamav-daemon  # Debian/Ubuntu
sudo systemctl start clamav-daemon
```

**Permission policy** — Static analysis of Flatpak metadata. Automatically rejects:
- `filesystem=host` — full host filesystem access
- `filesystem=home` — full home directory access
- `filesystem=host-etc` — host /etc access
- `filesystem=host-os` — host /usr access

Flags for manual review:
- `filesystem=/` — root filesystem access
- `device=all` — all device access

Safe permissions pass without issue (e.g., `filesystem=xdg-download`, `share=network`, `socket=wayland`).

---

## CI Pipeline

GitHub Actions runs on every push and PR to `main`:

1. **Evaluate** — `nix flake check` evaluates all 7 configs + ISO derivation
2. **Build** — `nix build .#packages.x86_64-linux.iso` builds the full ISO
3. **Upload** — ISO artifact uploaded (14-day retention, pushes only)
4. **Size check** — Warns if ISO exceeds 800MB (current floor: ~1.1GB with COSMIC + Brave)

---

## Hardware Testing Checklist

When testing on a physical Chromebook, verify:

- [ ] Boot to COSMIC desktop from USB
- [ ] WiFi connects to WPA2 network
- [ ] Audio: speakers and headphone jack (plug/unplug detection)
- [ ] Touchpad: tap-to-click, two-finger scroll, three-finger gestures
- [ ] Keyboard: volume/brightness keys, Search=Super mapping, F1-F10 via Search+top-row
- [ ] Display: no scaling artifacts at 1366x768
- [ ] Battery: status indicator accurate, suspend/resume works
- [ ] Installer: runs to completion, installed system boots without USB
- [ ] All 5 apps launch from the app launcher
- [ ] No unexpected outbound connections (`ss -tulnp`, `tcpdump`)

---

## Architecture Decisions

Key decisions documented for consistency:

- **NixOS** over Debian/Fedora — declarative, reproducible, atomic upgrades
- **COSMIC desktop** over GNOME/Sway — native Rust, modern Wayland, lightweight
- **Flatpak** for third-party apps — sandboxed by default, portal-mediated host access
- **Firejail + AppArmor** for pre-installed apps — defense in depth
- **GPL v3** — copyleft, prevents proprietary forks
- **No telemetry, ever** — enforced by app selection and network policy
- **Axum** for Forge backend — async Rust, consistent with Forge client tech stack
- **PostgreSQL + S3** for Forge storage — standard, self-hostable, no vendor lock-in
