{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ../modules/home/emacs
    ../modules/home/niri
  ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
    ripgrep
    fd
    fzf
    ytfzf
    yt-dlp
    mpv
    foot
    yazi
    ranger
    zathura
    kdePackages.kate
    wl-clipboard
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
