# hosts/minimal/configuration.nix
# Minimal system for recovery or testing
# Switch to this with: sudo nixos-rebuild switch --flake .#minimal

{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    # Use the same hardware config as desktop
    ../desktop/hardware-configuration.nix
  ];

  # ══════════════════════════════════════════════════════════════════
  # BOOT
  # ══════════════════════════════════════════════════════════════════

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ══════════════════════════════════════════════════════════════════
  # NETWORKING
  # ══════════════════════════════════════════════════════════════════

  networking.hostName = "${myConfig.hostname}-minimal";
  networking.networkmanager.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # LOCALIZATION
  # ══════════════════════════════════════════════════════════════════

  time.timeZone = myConfig.timezone;
  i18n.defaultLocale = myConfig.locale;

  # ══════════════════════════════════════════════════════════════════
  # NIX SETTINGS
  # ══════════════════════════════════════════════════════════════════

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ══════════════════════════════════════════════════════════════════
  # USER
  # ══════════════════════════════════════════════════════════════════

  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # ══════════════════════════════════════════════════════════════════
  # MINIMAL PACKAGES
  # ══════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    tree
  ];

  # ══════════════════════════════════════════════════════════════════
  # SERVICES
  # ══════════════════════════════════════════════════════════════════

  services.openssh.enable = true;

  # Basic display (optional - remove if you want TTY only)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # STATE VERSION
  # ══════════════════════════════════════════════════════════════════

  system.stateVersion = "25.11";
}
