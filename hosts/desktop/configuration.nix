# hosts/desktop/configuration.nix
# Main desktop system configuration
# Imports all system modules and defines the user account

{ config, lib, pkgs, inputs, myConfig, unstable, ... }:

{
  imports = [
    # Hardware (specific to this machine)
    ./hardware-configuration.nix

    # System modules
    ../../modules/system/core.nix
    ../../modules/system/desktop.nix
    ../../modules/system/development.nix
    ../../modules/system/services.nix
    ../../modules/system/cli-tools.nix
  ];

  # ══════════════════════════════════════════════════════════════════
  # USER ACCOUNT
  # ══════════════════════════════════════════════════════════════════

  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [
      "networkmanager"  # Manage network connections
      "wheel"           # Sudo access
      "mlocate"         # File search (locate)
      "plocate"         # File search (plocate)
    ];

    # Minimal packages here - most go in Home Manager
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # ══════════════════════════════════════════════════════════════════
  # DESKTOP-SPECIFIC SYSTEM PACKAGES
  # These require system-level installation
  # ══════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    # KDE tools
    kdePackages.karousel  # Scrolling window manager

    # Required for Otzaria
    zenity
  ];
}
