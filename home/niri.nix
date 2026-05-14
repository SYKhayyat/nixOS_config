{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ../modules/home/emacs
    ../modules/home/niri
    ../modules/home/scripts.nix
  ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  systemd.user.sessionVariables = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_CURRENT_DESKTOP = "niri";
  };

  # Services bound to Niri session target (UWSM)
  services.mako.enable = true;
  systemd.user.services.mako.Install.WantedBy = [ "wayland-session@niri.target" ];

  services.udiskie.enable = true;
  systemd.user.services.udiskie.Install.WantedBy = [ "wayland-session@niri.target" ];

  # Packages
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    fzf
    foot
    wlogout
    udiskie
    networkmanagerapplet
    cliphist
    pamixer
    brightnessctl
    grim
    slurp
    swappy
    libnotify
  ];

  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        email = "shaul@example.com";
      };
    };
  };

  fonts.fontconfig.enable = true;
}
