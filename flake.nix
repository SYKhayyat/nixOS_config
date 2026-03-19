# flake.nix
# Master configuration - defines inputs and system profiles

{
  description = "Shaul's NixOS Configuration";

  inputs = {
    # ══════════════════════════════════════════════════════════════
    # PACKAGE SOURCES
    # ══════════════════════════════════════════════════════════════

    # Main NixOS packages (stable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Unstable packages (for bleeding-edge software when needed)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ══════════════════════════════════════════════════════════════
    # HOME MANAGER
    # ══════════════════════════════════════════════════════════════

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ══════════════════════════════════════════════════════════════
    # LIX (Your preferred Nix implementation)
    # ══════════════════════════════════════════════════════════════

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ══════════════════════════════════════════════════════════════
    # EMACS OVERLAY (Latest Emacs packages)
    # ══════════════════════════════════════════════════════════════

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    lix-module,
    emacs-overlay,
    ...
  }@inputs:
  let
    system = "x86_64-linux";

    # ══════════════════════════════════════════════════════════════
    # SHARED CONFIGURATION VALUES
    # Edit these to match your setup
    # ══════════════════════════════════════════════════════════════

    myConfig = {
      username = "shaul";
      fullName = "Shaul Khayyat";
      hostname = "nixos";
      homeDir = "/home/shaul";
      timezone = "America/New_York";
      locale = "en_US.UTF-8";
      seforimPath = "/home/shaul/Documents/seforim";
    };

    # ══════════════════════════════════════════════════════════════
    # PACKAGE SETS WITH OVERLAYS
    # ══════════════════════════════════════════════════════════════

    pkgsForSystem = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.android_sdk.accept_license = true;
      overlays = [
        emacs-overlay.overlays.default
      ];
    };

    unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

  in {
    # ══════════════════════════════════════════════════════════════
    # NIXOS SYSTEM CONFIGURATIONS (Profiles)
    # ══════════════════════════════════════════════════════════════

    nixosConfigurations = {

      # ────────────────────────────────────────────────────────────
      # DESKTOP PROFILE
      # Your full-featured daily driver
      # Switch to this with: sudo nixos-rebuild switch --flake .#desktop
      # ────────────────────────────────────────────────────────────

      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs myConfig unstable;
          pkgs = pkgsForSystem;
        };
        modules = [
          # Lix Nix implementation
          lix-module.nixosModules.default

          # System configuration
          ./hosts/desktop/configuration.nix

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              users.${myConfig.username} = import ./home/desktop.nix;
              extraSpecialArgs = { inherit inputs myConfig unstable; };
            };
          }
        ];
      };

      # ────────────────────────────────────────────────────────────
      # MINIMAL PROFILE
      # Lightweight system for recovery or testing
      # Switch to this with: sudo nixos-rebuild switch --flake .#minimal
      # ────────────────────────────────────────────────────────────

      minimal = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs myConfig; };
        modules = [
          ./hosts/minimal/configuration.nix
        ];
      };

    };

    # ══════════════════════════════════════════════════════════════
    # DEVELOPMENT SHELL
    # Enter with: nix develop
    # ══════════════════════════════════════════════════════════════

    devShells.${system}.default = pkgsForSystem.mkShell {
      packages = with pkgsForSystem; [
        nil           # Nix language server
        nixpkgs-fmt   # Nix formatter
        statix        # Nix linter
        deadnix       # Find dead code
      ];

      shellHook = ''
        echo ""
        echo "══════════════════════════════════════════════════════"
        echo "  NixOS Configuration Development Shell"
        echo "══════════════════════════════════════════════════════"
        echo ""
        echo "  Commands:"
        echo "    nix fmt           Format all .nix files"
        echo "    statix check .    Lint configuration"
        echo "    deadnix .         Find unused code"
        echo ""
        echo "  Rebuild:"
        echo "    sudo nixos-rebuild switch --flake .#desktop"
        echo "    sudo nixos-rebuild switch --flake .#minimal"
        echo ""
      '';
    };

    # Formatter for 'nix fmt'
    formatter.${system} = pkgsForSystem.nixpkgs-fmt;
  };
}
