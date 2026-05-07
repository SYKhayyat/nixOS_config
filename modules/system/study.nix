{ config, lib, pkgs, ... }:

{
  # Display Server (Wayland)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
services.displayManager.defaultSession = lib.mkForce "plasmawayland";
  services.desktopManager.plasma6.enable = true;

  # Keyboard
  services.xserver.xkb = lib.mkForce {
    layout = "us,il";
    options = "grp:win_space_toggle,caps:escape";
  };

  # Exclude browser integration and other unnecessary apps
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    plasma-browser-integration
  ];

  environment.systemPackages = with pkgs; [
    # Terminal
    foot

    # Basic utilities
    git wget curl htop tree unzip zip

    # Search tools
    ripgrep ripgrep-all fd fzf plocate

    # Media (for ytfzf)
    yt-dlp mpv

    # Document viewer
    okular

    # Office
    libreoffice-qt-fresh
  ];

  # Fonts matching your main Plasma config
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      dejavu_fonts
      jetbrains-mono
      fira-code
      source-code-pro
      source-serif
      source-sans
      libertinus
      nerd-fonts.symbols-only
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      hinting.enable = true;
      antialias = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };

  # Audio (needed for mpv)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  networking.networkmanager.enable = true;
}
