# hosts/desktop/configuration.nix
# Main desktop system configuration
# Imports all system modules and defines the user account

# hosts/desktop/configuration.nix
# hosts/desktop/configuration.nix
# Main desktop system configuration
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
    ../../modules/system/file-sync.nix   
  ];

  # ══════════════════════════════════════════════════════════════════
  # NIRI SPECIALISATION
  # This creates the "Niri Mode" that you switch to via 'to-niri'
  # ══════════════════════════════════════════════════════════════════
  specialisation.niri.configuration = {
    # Disable Plasma when in Niri mode to save resources and prevent conflicts
    services.desktopManager.plasma6.enable = lib.mkForce false;
    
    # Import the Niri system-level module
    imports = [ ../../modules/system/niri.nix ];

    # Label it so it shows up as a separate entry in your boot menu (GRUB/Systemd-boot)
    system.nixos.tags = [ "niri" ];
  };

  # ══════════════════════════════════════════════════════════════════
  # USER ACCOUNT
  # ══════════════════════════════════════════════════════════════════
  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"   # REQUIRED: For brightness control
      "input"   # REQUIRED: For specialized mouse/keyboard input
      "mlocate"
      "plocate"
    ];

    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # ══════════════════════════════════════════════════════════════════
  # SYSTEM PACKAGES
  # ══════════════════════════════════════════════════════════════════
  environment.systemPackages = with pkgs; [
    kdePackages.karousel  # Scrolling window manager for Plasma
    zenity                # Dialog boxes (Required for Otzaria)
  ];
}
