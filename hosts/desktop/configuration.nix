{ config, lib, pkgs, myConfig, ... }:

let
  mkSpecialization = import ../../lib/mk-specialization.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/desktop.nix
    ../../modules/system/cli-tools.nix
    ../../modules/system/development.nix
    ../../modules/system/file-sync.nix
    ../../modules/system/services.nix
  ];

  # Default for the main system
  services.displayManager.defaultSession = "plasma";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupCommand = "true";
    extraSpecialArgs = {
      inherit myConfig;
      desktopEnvironment = "plasma";
      unstable = pkgs;
    };
    users.${myConfig.username} = {
      imports = [ ../../home/desktop.nix ];
    };
  };

  specialisation = {
    niri = mkSpecialization {
      inherit lib pkgs myConfig;
      desktopEnvironment = "niri";
      extraModules = [ ../../modules/system/niri.nix ];
    };

    hyprland = mkSpecialization {
      inherit lib pkgs myConfig;
      desktopEnvironment = "hyprland";
      extraModules = [ ../../modules/system/hyprland.nix ];
    };
  };
}
