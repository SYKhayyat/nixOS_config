{
  description = "Shaul's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, stylix, plasma-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      myConfig = {
        username = "shaul";
        fullName = "Shaul";
        hostname = "desktop";
        homeDir = "/home/shaul";
        timezone = "America/New_York";
        locale = "en_US.UTF-8";
        seforimPath = "/home/shaul/Documents/seforim";
      };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs myConfig; };
        modules = [
          ./hosts/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          {
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
        ];
      };
    };
}
