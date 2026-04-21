{
  description = "Stronk 1 — Your Computer. Actually Yours.";

  inputs = {
    # NixOS 25.05 — includes COSMIC desktop natively
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

      # Common modules shared by all configurations (Phase 0 base)
      commonModules = [
        ./modules/core.nix
        ./modules/desktop.nix
        ./modules/apps.nix
        ./modules/security.nix
        ./modules/theme.nix
        ./modules/assertions.nix
      ];

      # Phase 1 additions (daily-driver features)
      phase1Modules = [
        ./modules/compat.nix
      ];

      # Brave is the only unfree package — set at flake level so
      # modules stay clean for nixosTest (which uses external pkgs)
      nixpkgsConfig = { nixpkgs.config.allowUnfree = true; };
    in
    {
      # NixOS system configurations
      nixosConfigurations = {

        # ── Phase 0: Bootable USB image ──────────────────────────────

        # Generic x86-64 image (for testing on any UEFI machine)
        stronk-generic = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ];
        };

        # Dell Chromebook 11 3180 (KEFKA) — primary target
        stronk-kefka = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/kefka.nix ];
        };

        # HP Chromebook 11 G5 EE (SETZER) — minimum tier (2GB)
        stronk-setzer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/setzer.nix ];
        };

        # HP Chromebook 11 G6 EE (SNAPPY) — stretch target
        stronk-snappy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/snappy.nix ];
        };

        # ── Phase 1: Daily-driver builds (includes Windows compat) ───

        stronk-kefka-full = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ phase1Modules ++ [ nixpkgsConfig ./hardware/kefka.nix ];
        };

        stronk-setzer-full = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ phase1Modules ++ [ nixpkgsConfig ./hardware/setzer.nix ];
        };

        stronk-snappy-full = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ phase1Modules ++ [ nixpkgsConfig ./hardware/snappy.nix ];
        };
      };

      # ISO image builder — includes installer module
      packages.${system} = {
        iso = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./installer/iso.nix ];
        }).config.system.build.isoImage;
      };

      # Integration tests — run in QEMU VMs, no hardware needed
      checks.${system} = {
        integration = import ./tests/integration.nix {
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
          inherit commonModules;
        };
      };
    };
}
