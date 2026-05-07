{ config, lib, pkgs, ... }:

{
  # Minimal display manager
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.lxqt.enable = true;
  services.xserver.xkb = {
    layout = "us,il";
    options = "grp:win_space_toggle,caps:escape";
  };

  # No browser, just the essentials
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

  # Audio (needed for mpv)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # No networking restrictions, just no browser installed
  networking.networkmanager.enable = true;
}
