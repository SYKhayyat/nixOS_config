{ lib, pkgs, myConfig, desktopEnvironment, extraModules, unstable ? null }:

{
  configuration = { ... }: {
    _module.args.myConfig = myConfig // { inherit desktopEnvironment; };

    xdg.portal = {
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

    services.displayManager.sddm.enable = lib.mkForce true;
    services.displayManager.sddm.wayland.enable = true;

    services.displayManager.defaultSession = lib.mkForce (
      if desktopEnvironment == "plasma" then "plasma"
      else if desktopEnvironment == "hyprland" then "hyprland-uwsm"
      else if desktopEnvironment == "niri" then "niri-uwsm"
      else null
    );

    services.desktopManager.plasma6.enable = lib.mkForce (desktopEnvironment == "plasma");

    imports = extraModules;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupCommand = "true";
      extraSpecialArgs = {
        inherit myConfig;
        desktopEnvironment = desktopEnvironment;
        unstable = if unstable != null then unstable else pkgs;
      };
      users.${myConfig.username} = {
        imports = [ ../home/desktop.nix ];
      };
    };
  };
}
