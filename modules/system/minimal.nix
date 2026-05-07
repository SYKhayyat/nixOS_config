{ config, lib, pkgs, ... }:

{
  # Force‑override all desktop‑related options from the base config
  services.xserver.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;

  # Networking: keep enabled but disable firewall (recovery mode)
  networking.firewall.enable = lib.mkForce false;

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
    emacs
  ];

  # Enable man pages
  documentation.man.enable = true;
}
