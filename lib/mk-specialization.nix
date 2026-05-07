{ lib, pkgs, myConfig, extraModules, unstable ? null, homeDesktopPath ? null, desktopEnvironment ? null }:

{
  configuration = { config, ... }: {
    _module.args.myConfig = myConfig // { inherit desktopEnvironment; };

    xdg.portal = lib.mkIf (desktopEnvironment != null) {
      enable = true;
      xdgOpenUsePortal = true;
      config.common.default = [ "gtk" ];
      extraPortals =
        if desktopEnvironment == "plasma" then [ pkgs.kdePackages.xdg-desktop-portal-kde ]
        else [
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-gnome
          pkgs.xdg-desktop-portal-hyprland
        ];
    };

    services.displayManager.sddm.enable = lib.mkForce (desktopEnvironment != null && desktopEnvironment != "lxqt");
    services.displayManager.sddm.wayland.enable = lib.mkForce (desktopEnvironment != null && desktopEnvironment != "lxqt");

    services.displayManager.defaultSession = lib.mkIf (desktopEnvironment != null) (lib.mkForce (
      if desktopEnvironment == "plasma" then "plasma"
      else if desktopEnvironment == "hyprland" then "hyprland-uwsm"
      else if desktopEnvironment == "niri" then "niri-uwsm"
      else if desktopEnvironment == "lxqt" then "lxqt-wayland"
      else null
    ));

    services.desktopManager.plasma6.enable = lib.mkForce (desktopEnvironment == "plasma");

    imports = extraModules;

    home-manager = lib.mkIf (homeDesktopPath != null) {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupCommand = "true";
      extraSpecialArgs = {
        inherit myConfig;
        desktopEnvironment = desktopEnvironment;
        unstable = if unstable != null then unstable else pkgs;
      };
      users.${myConfig.username} = {
        imports = [ homeDesktopPath ];
      };
    };
  };
}
