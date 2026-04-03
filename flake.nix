{
  description = "Stronk 1 — Your Computer. Actually Yours.";

  inputs = {
    # Pin to NixOS 24.11 stable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # COSMIC desktop packages
    nixos-cosmic = {
      url = "github:liber-tas/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-cosmic, ... }:
    let
      system = "x86_64-linux";

      # Common modules shared by all configurations
      commonModules = [
        nixos-cosmic.nixosModules.default
        ./modules/core.nix
        ./modules/desktop.nix
        ./modules/apps.nix
        ./modules/security.nix
        ./modules/theme.nix
      ];
    in
    {
      # NixOS system configurations
      nixosConfigurations = {

        # Generic x86-64 image (for testing on any UEFI machine)
        stronk-generic = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules;
        };

        # Dell Chromebook 11 3180 (KEFKA) — primary target
        stronk-kefka = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./hardware/kefka.nix
          ];
        };

        # HP Chromebook 11 G5 EE (SETZER) — minimum tier (2GB)
        stronk-setzer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./hardware/setzer.nix
          ];
        };

        # HP Chromebook 11 G6 EE (SNAPPY) — stretch target
        stronk-snappy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./hardware/snappy.nix
          ];
        };
      };

      # ISO image builder — includes installer module
      packages.${system} = {
        iso = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./installer/iso.nix
          ];
        }).config.system.build.isoImage;
      };
    };
}
