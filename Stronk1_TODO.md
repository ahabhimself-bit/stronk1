# Stronk 1 -- Master TODO List

**"Your Computer. Actually Yours."**
Generated from: Product Brief v1.0, PRD v1.0, High-Level Architecture v1.0

**Goal: A bootable USB that installs Stronk 1 onto a Chromebook -- desktop, browser, and all.**

---

# PART 1: BOOTABLE USB → CHROMEBOOK INSTALL (The Immediate Goal)

Everything below must be done, in order, before Stronk 1 can be loaded onto a USB and installed onto a Chromebook.

---

## Step 1: Decisions Before You Write Code

These block everything else. Make each decision, document it, move on.

- [x] **1.1** Target Chromebook models (all MrChromebox UEFI Full ROM supported, AUE expired June 2024):
  - **Primary:** Dell Chromebook 11 3180 (KEFKA) -- 4GB RAM, Braswell N3060, WP screw, Realtek ALC5650 audio
  - **Minimum tier:** HP Chromebook 11 G5 EE (SETZER) -- 2GB RAM, Braswell N3060, WP screw, Realtek ALC5650 audio
  - **Stretch:** HP Chromebook 11 G6 EE (SNAPPY) -- 4GB RAM, Apollo Lake N3350, battery disconnect WP, SOF audio
- [x] **1.2** Desktop environment: **COSMIC** (Sway fallback if too heavy for 2GB tier. Benchmark by Week 4, final call Week 6.)
- [x] **1.3** Flatpak runtime base: **Freedesktop runtime** (lighter, sufficient for Stronk 1)
- [x] **1.4** Audio subsystem: **PipeWire** (modern, supports audio + screen sharing)
- [x] **1.5** Installer medium: **USB ISO**
- [x] **1.6** Browser default: **Brave** (Firefox available via The Forge)
- [x] **1.7** File manager: **COSMIC Files** (native Rust/Iced, consistent with COSMIC desktop, no GTK dependency mismatch)
- [x] **1.8** Open source license: **GPL v3** (copyleft -- prevents proprietary forks, aligns with COSMIC's license and project values)

---

## Step 2: Dev Environment & Project Scaffold

Set up the Nix Flakes project so you can build images locally.

- [x] **2.1** Install Nix with flakes enabled on your dev machine (Determinate Nix 3.17.3 / Nix 2.33.3)
- [x] **2.2** Initialize git repo for Stronk 1 source
- [x] **2.3** Create `flake.nix` -- top-level flake, system root
- [x] **2.4** Create `flake.lock` -- pin nixpkgs 24.11 + nixos-cosmic (lilyinstarlight/nixos-cosmic)
- [x] **2.5** Create directory structure:
  - [x] `modules/` -- NixOS module files
  - [x] `hardware/` -- per-device hardware configs
  - [x] `overlays/` -- Stronk-specific package overlays
  - [x] `installer/` -- ISO build config
- [x] **2.6** Verify flake evaluates (all 4 configs + ISO derivation evaluate cleanly on macOS; actual build requires x86_64-linux)

---

## Step 3: Minimal Bootable NixOS Image (x86-64)

Get a bare-bones NixOS booting from USB on generic x86-64 hardware first, before touching Chromebook-specific stuff.

- [x] **3.1** Create `modules/core.nix` -- minimal base packages, locale, filesystem layout, user account (no password / auto-login)
- [x] **3.2** Configure systemd minimal: `graphical.target` with minimal dependency chain
- [x] **3.3** Disable all unnecessary systemd services declaratively (remote logging, network FS, printer discovery, etc.)
- [x] **3.4** Configure journald: volatile storage, 50MB cap
- [x] **3.5** Configure networking: NetworkManager or systemd-networkd for WiFi + Ethernet
- [ ] **3.6** Build a bootable ISO image from the flake ⚠️ **BLOCKED — requires x86_64-linux build host**
- [ ] **3.7** Write ISO to USB drive ⚠️ **BLOCKED — requires 3.6**
- [ ] **3.8** Boot the USB on any x86-64 machine -- verify you reach a TTY login ⚠️ **BLOCKED — requires 3.7**
- [ ] **3.9** Verify image size (target: under 800MB) ⚠️ **BLOCKED — requires 3.6**

---

## Step 4: Desktop Environment

Get a graphical desktop running on the bootable image.

- [x] **4.1** Create `modules/desktop.nix` -- display server + shell config
- [x] **4.2** If COSMIC: add COSMIC compositor + COSMIC desktop packages to Nix config
- [N/A] **4.3** If Sway: add Sway + waybar + wofi (or custom launcher) to Nix config *(COSMIC chosen — Sway fallback deferred to Week 4 benchmark)*
- [x] **4.4** Configure auto-login to desktop session (no login screen / no account needed)
- [x] **4.5** Configure PipeWire for audio
- [x] **4.6** Configure basic fonts (system UI font, monospace font)
- [ ] **4.7** Rebuild ISO, write to USB, boot -- verify you reach a graphical desktop ⚠️ **BLOCKED — requires x86_64-linux build host**
- [ ] **4.8** Verify idle RAM is under 500MB ⚠️ **BLOCKED — requires 4.7**
- [ ] **4.9** Verify boot to desktop time (target: under 15 seconds, measured from UEFI handoff) ⚠️ **BLOCKED — requires 4.7**

---

## Step 5: Pre-Installed Apps (Exactly 5)

Add the five apps that ship with Stronk 1. Nothing more.

- [x] **5.1** Web browser -- Brave (Nix package, Firejail-sandboxed)
- [x] **5.2** File manager -- COSMIC Files (included with COSMIC desktop, local-first, no cloud prompts)
- [x] **5.3** Terminal emulator -- COSMIC Terminal (included with COSMIC desktop)
- [x] **5.4** System settings -- COSMIC Settings (included with COSMIC desktop)
- [x] **5.5** The Forge client -- Stub app (zenity dialog placeholder, .desktop entry)
- [ ] **5.6** Verify: exactly 5 user-facing apps in the app launcher, nothing else ⚠️ **BLOCKED — requires build**
- [ ] **5.7** Rebuild ISO, write to USB, boot -- verify all 5 apps launch and work ⚠️ **BLOCKED — requires x86_64-linux build host**
- [ ] **5.8** Verify file manager opens in <=1 second ⚠️ **BLOCKED — requires 5.7**
- [ ] **5.9** Verify terminal opens in <=500ms ⚠️ **BLOCKED — requires 5.7**

---

## Step 6: Privacy & Security Baseline

Lock down the image so it meets the core Stronk promises.

- [x] **6.1** Create `modules/security.nix` -- Firejail, AppArmor, kernel hardening, firewall
- [x] **6.2** Configure nftables firewall: default-deny inbound, no listening services
- [x] **6.3** Enable kernel hardening: restricted user namespaces, restricted dmesg, ASLR, stack protector
- [x] **6.4** Enable AppArmor with default profiles
- [ ] **6.5** Verify: zero outbound network connections on boot (monitor with `ss -tulnp` and `tcpdump` for 10 minutes on fresh boot with no user action) ⚠️ **BLOCKED — requires build**
- [ ] **6.6** Verify: no telemetry endpoints, no analytics libraries in the package set ⚠️ **BLOCKED — requires build**
- [ ] **6.7** Verify: no mandatory account creation anywhere in the boot flow ⚠️ **BLOCKED — requires build**
- [ ] **6.8** Verify: no advertisements in any UI surface ⚠️ **BLOCKED — requires build**
- [ ] **6.9** Verify: no automatic/forced updates -- system is silent unless user asks ⚠️ **BLOCKED — requires build**

---

## Step 7: Theming & Polish

Make it look like Stronk, not stock NixOS.

- [x] **7.1** Create Stronk Light theme (default) — COSMIC ThemeBuilder configs deployed via `stronk-cosmic-themes` package (accent #3B82F6, clean near-white backgrounds). Visual verification pending build.
- [x] **7.2** Create Stronk Dark theme — Deep navy backgrounds, same blue accent. Visual verification pending build.
- [x] **7.3** Create Stronk High Contrast theme (WCAG 2.1 AA) — Delegates to COSMIC's built-in HighContrast accessibility mode (already WCAG 2.1 AA compliant); Stronk accent/semantic colors carry over automatically.
- [x] **7.4** Custom wallpaper(s) — SVG wallpapers for light (near-white gradient) and dark (deep navy) themes in `assets/wallpapers/`, deployed via `stronk-wallpapers` package, COSMIC background config set in `stronk-cosmic-themes`. Visual verification pending build.
- [x] **7.5** Stronk branding in system settings "About" page (os-release configured in modules/theme.nix)
- [ ] **7.6** App launcher styling consistent with Stronk theme ⚠️ **BLOCKED — requires COSMIC running**
- [x] **7.7** Notification system: only user-relevant events, zero promotional content (enforced by app selection — no promo-capable apps)
- [ ] **7.8** Rebuild ISO, boot, verify visual polish ⚠️ **BLOCKED — requires x86_64-linux build host**

---

## Step 8: Chromebook Hardware Support

Make the image work specifically on your target Chromebook(s).

- [x] **8.1** Research your target Chromebook(s): CPU, GPU, WiFi chip, touchpad, display, keyboard layout, audio codec
  - All 3 targets: Elan I2C touchpad (ELAN0000), 1366x768 11.6" TN (1x scaling), Chrome keyboard with Search=Super_L
  - KEFKA/SETZER: Braswell N3060, Intel 7265 WiFi, Realtek RT5650 audio (SOF driver, dsp_driver=3, acpid for jack)
  - SNAPPY: Apollo Lake N3350, Intel 7265 WiFi, DA7219+MAX98357A audio (AVS driver, dsp_driver=4, headphone support but less stable)
- [x] **8.2** Flash MrChromebox UEFI Full ROM firmware on target Chromebook (document the exact steps)
  - Firmware guide: `installer/stronk-firmware-guide.sh` (prints step-by-step procedure)
  - Installer detects missing MrChromebox firmware via DMI bios_vendor check
  - Covers: Developer Mode → WP disable (screw or battery) → firmware utility → USB boot
- [x] **8.3** Create `hardware/<model>.nix` for all three target Chromebooks:
  - [x] Kernel modules for WiFi, GPU, audio, touchpad (elan_i2c, i2c_designware, pinctrl_cherryview, snd_sof)
  - [x] Display scaling for Chromebook screen resolution (1x, no scaling needed at 1366x768)
  - [x] Touchpad configuration (tap-to-click, natural scrolling, clickfinger — in desktop.nix shared module)
  - [x] Keyboard mapping (keyd: Search=Super, Search+toprow=F1-F10 — in desktop.nix shared module)
  - [x] Power management / battery optimization (thermald + TLP per model)
  - [x] Audio routing (KEFKA/SETZER: SOF+acpid for jack detection; SNAPPY: AVS for headphone support)
- [ ] **8.4** Rebuild ISO with Chromebook hardware profile included
- [ ] **8.5** Boot USB on Chromebook -- verify desktop loads
- [ ] **8.6** Verify WiFi connects
- [ ] **8.7** Verify audio works (speakers + headphone jack)
- [ ] **8.8** Verify touchpad gestures work
- [ ] **8.9** Verify keyboard special keys work (brightness, volume, Search)
- [ ] **8.10** Verify display scaling looks correct
- [ ] **8.11** Verify battery status shows and power management works
- [ ] **8.12** Measure boot time on Chromebook (target: under 15 seconds)
- [ ] **8.13** Measure idle RAM on Chromebook (target: under 500MB)

---

## Step 9: Installer

Build the installer that writes Stronk 1 from the USB to the Chromebook's internal storage.

- [x] **9.1** Research NixOS installer options: calamares, custom script, nixos-install based
  - **Decision:** Custom shell script + zenity GUI wrapping `nixos-install`. Zenity is already a dependency (The Forge stub), adds zero weight. Calamares rejected (heavy Qt dep, overkill). COSMIC-native Iced installer planned for Phase 1.
- [x] **9.2** Create `installer/` module with install wizard config
  - `installer/installer.nix` — NixOS module: packages installer, bundles flake source, adds desktop entry, includes firmware for offline installs
  - `installer/iso.nix` — Updated: imports installer.nix, squashfs compression, live system overrides
- [x] **9.3** Installer Step: Welcome screen with Stronk branding
- [x] **9.4** Installer Step: Disk selection and partitioning (guided, simple -- "Install to this drive")
  - Auto-excludes boot USB, detects partition naming (nvme/mmcblk/sd), GPT + 512MB EFI + ext4 root
- [x] **9.5** Installer Step: Browser choice (Brave vs Firefox)
  - Brave default (offline). Firefox offered if network detected, warns if no network.
- [x] **9.6** Installer Step: Locale / timezone selection
  - Common timezones listed first, full list below
- [x] **9.7** Installer Step: Install progress bar
  - zenity progress dialog, logs to /tmp/stronk-install.log, error handling with user-visible messages
- [x] **9.8** Installer Step: "Installation complete -- remove USB and reboot"
- [ ] **9.9** Build installer ISO ⚠️ **BLOCKED — requires x86_64-linux build host**
- [ ] **9.10** Test: boot USB on Chromebook, run installer, reboot into installed Stronk 1
- [ ] **9.11** Verify: installed system boots to desktop without USB
- [ ] **9.12** Verify: all 5 apps work on the installed system
- [ ] **9.13** Verify: WiFi, audio, touchpad, keyboard all work on installed system
- [ ] **9.14** Verify: no data loss, installer correctly partitions drive
- [ ] **9.15** Time the full install process (target: under 30 minutes including firmware flash)

---

## Step 10: Final Validation

Run through everything end-to-end before declaring the USB image done.

- [ ] **10.1** Fresh Chromebook → firmware flash → USB boot → install → reboot → desktop (full flow, start to finish)
- [ ] **10.2** Performance check: boot < 15s, idle RAM < 500MB, image < 800MB
- [ ] **10.3** Privacy check: zero outbound connections for 10 min on fresh boot, zero telemetry
- [ ] **10.4** App check: browser, file manager, terminal, settings, Forge stub all launch
- [ ] **10.5** Hardware check: WiFi, audio, touchpad, keyboard, display, battery all functional
- [ ] **10.6** Security check: firewall active, AppArmor active, no listening services
- [ ] **10.7** Usability check: have a non-technical person attempt the install with written instructions
- [x] **10.8** Document the full installation guide (firmware flash + USB boot + install steps) — `docs/INSTALL.md`
- [ ] **10.9** Tag the repo: `v0.1.0-alpha` -- first bootable Chromebook image

---

# PART 2: ALPHA → DAILY DRIVER (Phase 1, Weeks 6-14)

Once the USB install works, these make it something you can actually use every day.

---

## Windows Compatibility Layer
- [ ] Create `modules/compat.nix` -- Proton/Wine, DXVK/VKD3D
- [ ] Integrate Proton + Wine transparently (no manual Wine config for supported apps)
- [ ] Set up Wine 11.x with esync/fshack/fsync patches
- [ ] Integrate DXVK (DX9/10/11 → Vulkan) and VKD3D-Proton (DX12 → Vulkan)
- [ ] ProtonDB Gold/Platinum Steam games launch without user intervention
- [ ] Package Bottles (Flatpak Wine prefix manager) for The Forge
- [ ] Build initial compatibility database (Works / Partial / Broken)
- [ ] Test and document 20+ common apps (Steam games, Office, Discord, Zoom, Slack)

## The Forge Client (Functional)
- [ ] Build COSMIC-native Forge client in Rust/Iced
- [ ] Browse, search, install, update, uninstall Flatpak apps
- [ ] One-click install flow
- [ ] App update notification and user-approved update flow
- [ ] Category browsing: Apps, Themes, Hardware Profiles, Workflows, Compatibility Packs
- [ ] Search with filtering and sorting

## The Forge Backend (Initial)
- [ ] Set up REST API + PostgreSQL + S3-compatible storage
- [ ] Automated security scanning pipeline (ClamAV + custom static analysis)
- [ ] Enforce: no `filesystem=host` or `filesystem=home` in submissions
- [ ] Display permissions prominently before install

## System Settings (Complete)
- [ ] Every setting reachable within 2 clicks from root
- [ ] Display, Network, Sound, Appearance, Keyboard/Touchpad, Updates, About, Storage

## Chromebook Optimizations
- [ ] Battery life >= 90% of ChromeOS under equivalent workload
- [ ] Display scaling correct on all target models
- [ ] Touchpad gestures matching ChromeOS latency
- [ ] Keyboard shortcuts correct at first boot
- [ ] Hardware profiles for all target models

## Security Hardening
- [ ] Firejail + AppArmor sandboxing for all user-installed apps
- [ ] Bubblewrap namespace isolation for Flatpak apps
- [ ] Seccomp syscall filtering
- [ ] XDG Desktop Portals for sandboxed host access
- [ ] AppArmor profiles for each pre-installed app

## Build Pipeline
- [ ] Set up CI (GitHub Actions or Hydra) for automated builds
- [ ] CI gate: image < 800MB
- [ ] CI gate: boot < 15s
- [ ] CI gate: idle RAM < 500MB
- [ ] CI gate: zero outbound connections at idle
- [ ] CI gate: exactly 5 pre-installed apps
- [ ] CI gate: security scan
- [ ] Integration tests: desktop launches, apps open, settings accessible

## Benchmarks & Docs
- [ ] Publish benchmarks: Stronk 1 vs Windows 11 vs macOS vs ChromeOS
- [ ] Internal developer daily-driver documentation

---

# PART 3: PUBLIC ALPHA (Phase 2, Weeks 14-24)

Target: 10,000 installs. Open source. Community.

---

## Public Release
- [ ] Publish codebase on GitHub
- [ ] Project website with downloads and install guide
- [ ] Getting-started docs, contributing guide, issue tracker

## The Forge Forum & Community
- [ ] Community forums (categories, threads, moderation)
- [ ] Developer publishing flow (submission → listing in 24 hours)
- [ ] Ratings and reviews (1-5 stars + text)
- [ ] Seed Forge with core utility apps
- [ ] Community moderation tools

## Hardware Compatibility Database
- [ ] Public, searchable, community-editable
- [ ] Windows app entries, Chromebook model entries, peripheral entries
- [ ] Community contribution workflow

## Internationalization & Accessibility
- [ ] Multi-language UI support
- [ ] Input methods for non-Latin scripts
- [ ] Screen reader support, keyboard navigation, font scaling, reduce-motion

## Extended Desktop
- [ ] Tiling window management (optional, not default)
- [ ] Workspace polish, multi-monitor, drag-and-drop

## Expanded Hardware
- [ ] More Chromebook models, ARM64 testing, general x86-64 laptops
- [ ] Community hardware profiles via The Forge

---

# PART 4: BETA (Phase 3, Weeks 24-40)

Target: 50,000 installs. Security audit. Press launch.

---

## Polish & Performance
- [ ] Full UI polish pass
- [ ] Performance profiling and optimization
- [ ] Memory leak audit
- [ ] Fix all P0/P1 community-reported bugs

## Security Audit
- [ ] Commission external audit by recognized firm
- [ ] Resolve critical and high findings
- [ ] Publish audit summary
- [ ] Transparent system audit log in settings

## Windows Compatibility Polish
- [ ] Test and document Office, Discord, Zoom, Slack status
- [ ] Document apps that won't work (DRM-heavy, enterprise)
- [ ] 100+ tested apps in compatibility database

## Chromebook Certification & Partnerships
- [ ] Define "Stronk Certified" criteria
- [ ] Certify initial models
- [ ] Partner outreach to refurbishers

## Press & Marketing
- [ ] Press kit, demo video, social media
- [ ] Outreach to 5+ major tech outlets
- [ ] Community ambassador program

## v1.0 Feature Freeze
- [ ] Lock features, regression test, documentation freeze

---

# PART 5: v1.0 STABLE (Phase 4, Months 10-14)

Target: 100,000 installs. Institutional pilots. First Forge revenue.

---

## Stable Release
- [ ] Tag and release v1.0
- [ ] Stable channel with security patches within 48 hours
- [ ] All P0 and P1 requirements verified

## Institutional Pilots
- [ ] Admin console for managed installs
- [ ] Support contracts, compliance logging
- [ ] 3+ school/library/org pilots

## Chromebook Refurbishment Partnerships
- [ ] Partners selling Chromebooks with Stronk pre-installed
- [ ] Pre-install image distribution, QA process

## The Forge Commerce
- [ ] Payment processing (5% commission)
- [ ] Developer payouts (95% to devs)
- [ ] 200+ developers, 500+ listings, first revenue

## Hearth OS Readiness (P2)
- [ ] Architecture supports AI shell layer without OS rebuild
- [ ] Ollama/llama.cpp, Whisper STT, Piper TTS installable via Forge
- [ ] COSMIC layer-shell protocol verified for shell replacement
- [ ] SQLite + ChromaDB installable for Jarvis memory engine

---

# PART 6: POST-v1.0 (Year 2+)

- [ ] Stronk Hardware -- purpose-built laptop or mini-PC
- [ ] Optional cloud services (backup, remote access)
- [ ] Hearth OS development (Jarvis AI shell)
- [ ] Scale institutional program
- [ ] Scale refurbishment partnerships

---

## Quick Reference: Performance Gates (Every Build)

| Metric | Target |
|--------|--------|
| Base image size | < 800MB |
| Cold boot to desktop | < 15 seconds |
| Idle RAM | < 500MB |
| Outbound connections at idle | Zero |
| Pre-installed apps | Exactly 5 |
| Telemetry | Zero |
| Mandatory accounts | Zero |
| Ads | Zero, forever |

## Quick Reference: Priority Key

| Priority | Meaning |
|----------|---------|
| **P0** | Must have. Does not ship without it. |
| **P1** | Should have for v1.0. May defer if necessary. |
| **P2** | Nice to have. Can defer post-v1.0. |
