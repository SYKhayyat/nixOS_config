{ config, lib, pkgs, ... }:

{
  # Display server with Wayland LXQt session
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.lxqt.enable = true;
  services.xserver.xkb = lib.mkForce {
    layout = "us,il";
    options = "grp:win_space_toggle,caps:escape";
  };

  # Default to Wayland session
  services.displayManager.defaultSession = "lxqt-wayland";

  # No browser, just essentials
  environment.systemPackages = with pkgs; [
    # Wayland session for LXQt
    lxqt.lxqt-wayland-session

    # Terminal
    foot

    # Basic utilities
    git wget curl htop tree unzip zip

    # Search tools
    ripgrep ripgrep-all fd fzf plocate

    # Media (for ytfzf)
    yt-dlp mpv

    # Document viewer
    kdePackages.okular

    # Office
    libreoffice-qt-fresh

    # Fonts
    noto-fonts
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Audio (needed for mpv)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # No firewall restrictions
  networking.networkmanager.enable = true;

  # Font configuration
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };
}
