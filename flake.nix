# /etc/nixos/flake.nix
{
  description = "My NixOS system configuration";

  inputs = {
    # Pin nixpkgs to a specific version for reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      packages.${system} = {
        otzaria = nixpkgs.legacyPackages.${system}.callPackage ./otzaria/package.nix { };
        default = self.packages.${system}.otzaria;
      };

      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };
    };
}
