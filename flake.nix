# /etc/nixos/flake.nix
{
  description = "My First Flake!";

  inputs = {
    # Pin nixpkgs to a specific version for reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05"; # Or your desired version/channel
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      otzaria = pkgs.callPackage ./otzaria/package.nix { };
      default = self.packages.${system}.otzaria;
    };

    nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix # Your existing configuration file
        # Add hardware-configuration.nix if it's in the same directory
        ./hardware-configuration.nix
      ];
    };
  };
}
