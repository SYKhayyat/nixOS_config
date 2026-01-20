# /etc/nixos/flake.nix
{
  description = "My First Flake!";

  inputs = {
    # Pin nixpkgs to a specific version for reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; # Or your desired version/channel
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # Or your system architecture
      modules = [
        ./configuration.nix # Your existing configuration file
        # Add hardware-configuration.nix if it's in the same directory
        ./hardware-configuration.nix
      ];
    };
  };
}

