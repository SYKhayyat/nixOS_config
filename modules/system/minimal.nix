{ config, lib, pkgs, ... }:

{
  # No X11, no desktop, no display manager
  services.xserver.enable = false;

  # Basic networking
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    tree
    ripgrep
    fd
    fzf
    unzip
    zip
    gnumake
    gcc
  ];

  # Enable man pages
  documentation.man.enable = true;

  # No firewall (recovery mode — you can enable later)
  networking.firewall.enable = false;
}
