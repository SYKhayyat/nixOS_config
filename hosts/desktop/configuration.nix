{ config, lib, pkgs, myConfig, ... }:

let
  mkSpecialization = import ../../lib/mk-specialization.nix;
  homeDesktopPath = ../../home/desktop.nix;
  homeNiriPath = ../../home/niri.nix;
  homeStudyPath = ../../home/study.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/cli-tools.nix
    ../../modules/system/development.nix
    ../../modules/system/file-sync.nix
    ../../modules/system/services.nix
    ../../modules/system/desktop.nix
  ];

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
      imports = [ homeDesktopPath ];
    };
  };

  specialisation = {
    minimal = mkSpecialization {
      inherit lib pkgs myConfig;
      extraModules = [
        ../../modules/system/minimal.nix
      ];
      homeDesktopPath = null;
    };

    niri = mkSpecialization {
      inherit lib pkgs myConfig;
      desktopEnvironment = "niri";
      extraModules = [
        ../../modules/system/niri.nix
      ];
      homeDesktopPath = homeNiriPath;
    };

    hyprland = mkSpecialization {
      inherit lib pkgs myConfig;
      desktopEnvironment = "hyprland";
      extraModules = [
        ../../modules/system/desktop.nix
        ../../modules/system/hyprland.nix
      ];
      homeDesktopPath = homeDesktopPath;
    };

        study = mkSpecialization {
      inherit lib pkgs myConfig;
      desktopEnvironment = "hyprland";
      extraModules = [
        ../../modules/system/hyprland.nix
        ../../modules/system/study-offline.nix
      ];
      homeDesktopPath = homeStudyPath;
    };
  };
}
