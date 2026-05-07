{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ../modules/home/emacs
  ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Small fonts like Plasma
  gtk = {
    enable = true;
    font = {
      name = "Noto Sans";
      size = 9;
    };
  };

  home.packages = with pkgs; [
    git
    ripgrep
    fd
    fzf
    ytfzf
    yt-dlp
    mpv
    foot
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
