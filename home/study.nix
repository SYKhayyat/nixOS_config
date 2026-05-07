{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ../modules/home/emacs
  ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Minimal packages for studying
  home.packages = with pkgs; [
    # YouTube frontend
    ytfzf

    # Clipboard
    wl-clipboard
  ];

  # SSH
  programs.ssh.enable = true;
    programs.ssh.enableDefaultConfig = false;

  # Git (for your notes sync)
    programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        email = "shaul@example.com";
      };
    };
  };

  # Emacs daemon
  services.emacs = {
    enable = true;
    defaultEditor = true;
  };

  # Fonts for the terminal
  fonts.fontconfig.enable = true;
}
