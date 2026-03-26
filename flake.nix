# ~/nixos-config/flake.nix

# ~/nixos-config/flake.nix

{
  description = "Shaul's NixOS Configuration";

  inputs = {
    # Main NixOS packages (stable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Unstable packages (for bleeding-edge software when needed)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager for user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Emacs overlay (latest Emacs packages)
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
    emacs-overlay, 
    ... 
  }@inputs:
  let
    system = "x86_64-linux";

    # Shared configuration values
    myConfig = {
      username = "shaul";
      fullName = "Shaul Khayyat";
      hostname = "nixos";
      homeDir = "/home/shaul";
      timezone = "America/New_York";
      locale = "en_US.UTF-8";
      seforimPath = "/home/shaul/Documents/seforim";
    };

    # Unstable packages
    unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

  in {
    nixosConfigurations = {

      # ════════════════════════════════════════════════════════════
      # DESKTOP PROFILE
      # ════════════════════════════════════════════════════════════

      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs myConfig unstable;
        };
        modules = [
          # Nixpkgs configuration
          {
            nixpkgs.overlays = [ emacs-overlay.overlays.default ];
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.android_sdk.accept_license = true;
          }

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

      # ════════════════════════════════════════════════════════════
      # MINIMAL PROFILE
      # ════════════════════════════════════════════════════════════

      minimal = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs myConfig; };
        modules = [
          {
            nixpkgs.config.allowUnfree = true;
          }
          ./hosts/minimal/configuration.nix
        ];
      };

    };

    # ════════════════════════════════════════════════════════════
    # DEVELOPMENT SHELL
    # ════════════════════════════════════════════════════════════

    devShells.${system}.default = let
      pkgs = import nixpkgs { inherit system; };
    in pkgs.mkShell {
      packages = with pkgs; [
        nil
        nixpkgs-fmt
        statix
        deadnix
      ];

      shellHook = ''
        echo ""
        echo "══════════════════════════════════════════════════════"
        echo "  NixOS Configuration Development Shell"
        echo "══════════════════════════════════════════════════════"
        echo ""
        echo "  Rebuild:"
        echo "    sudo nixos-rebuild switch --flake .#desktop"
        echo "    sudo nixos-rebuild switch --flake .#minimal"
        echo ""
      '';
    };

    # Formatter for 'nix fmt'
    formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
  };
}
