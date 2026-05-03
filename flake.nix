{
  description = "Stronk 1 — Your Computer. Actually Yours.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, fenix, ... }:
    let
      system = "x86_64-linux";

      forgeOverlay = final: prev: {
        the-forge = let
          fenixPkgs = fenix.packages.${system};
          rustPlatform = prev.makeRustPlatform {
            cargo = fenixPkgs.stable.cargo;
            rustc = fenixPkgs.stable.rustc;
          };
        in final.callPackage ./forge { inherit rustPlatform; };
      };

      commonModules = [
        ./modules/core.nix
        ./modules/desktop.nix
        ./modules/apps.nix
        ./modules/browser.nix
        ./modules/browser-choice.nix
        ./modules/security.nix
        ./modules/theme.nix
        ./modules/assertions.nix
      ];

      phase1Modules = [
        ./modules/compat.nix
      ];

      nixpkgsConfig = {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [ forgeOverlay ];
      };
    in
    {
      nixosConfigurations = {

        stronk-generic = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ];
        };

        stronk-kefka = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/kefka.nix ];
        };

        stronk-setzer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/setzer.nix ];
        };

        stronk-snappy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./hardware/snappy.nix ];
        };

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

      packages.${system} = {
        iso = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [ nixpkgsConfig ./installer/iso.nix ];
        }).config.system.build.isoImage;
      };

      checks.${system} = {
        integration = import ./tests/integration.nix {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ forgeOverlay ];
          };
          inherit commonModules;
        };
      };
    };
}
