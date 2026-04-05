# hosts/desktop/configuration.nix
# Main desktop system configuration
# Imports all system modules and defines the user account

# hosts/desktop/configuration.nix
{ config, lib, pkgs, myConfig, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/desktop.nix # Default: KDE Plasma
    ../../modules/system/development.nix
    ../../modules/system/services.nix
    ../../modules/system/cli-tools.nix
    ../../modules/system/file-sync.nix   
  ];

  # ══════════════════════════════════════════════════════════════════
  # NIRI SPECIALISATION
  # ══════════════════════════════════════════════════════════════════
  specialisation.niri.configuration = {
    # 1. Disable Plasma components
    services.desktopManager.plasma6.enable = lib.mkForce false;
    
    # 2. Enable Niri and Wayland modules
    imports = [ ../../modules/system/niri.nix ];

    # 3. Custom system label for boot menu
    system.nixos.tags = [ "niri" ];
  };

  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [ "networkmanager" "wheel" "video" "input" "mlocate" "plocate" ];
    packages = with pkgs; [ kdePackages.kate ];
  };

  # Keep system-level tools
  environment.systemPackages = with pkgs; [
    kdePackages.karousel
    zenity
  ];
}
