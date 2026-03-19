# modules/system/core.nix
# Core system settings: boot, networking, localization, Nix configuration

{ config, lib, pkgs, myConfig, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # BOOT
  # ══════════════════════════════════════════════════════════════════

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ══════════════════════════════════════════════════════════════════
  # NETWORKING
  # ══════════════════════════════════════════════════════════════════

  networking.hostName = myConfig.hostname;
  networking.networkmanager.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # LOCALIZATION
  # ══════════════════════════════════════════════════════════════════

  time.timeZone = myConfig.timezone;

  i18n.defaultLocale = myConfig.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = myConfig.locale;
    LC_IDENTIFICATION = myConfig.locale;
    LC_MEASUREMENT = myConfig.locale;
    LC_MONETARY = myConfig.locale;
    LC_NAME = myConfig.locale;
    LC_NUMERIC = myConfig.locale;
    LC_PAPER = myConfig.locale;
    LC_TELEPHONE = myConfig.locale;
    LC_TIME = myConfig.locale;
  };

  # ══════════════════════════════════════════════════════════════════
  # NIX SETTINGS
  # ══════════════════════════════════════════════════════════════════

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" myConfig.username ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Allow unfree packages (required for some software)
  nixpkgs.config.allowUnfree = true;

  # ══════════════════════════════════════════════════════════════════
  # SECURITY
  # ══════════════════════════════════════════════════════════════════

  security.rtkit.enable = true;  # Required for PipeWire

  # ══════════════════════════════════════════════════════════════════
  # BASIC SERVICES
  # ══════════════════════════════════════════════════════════════════

  services.openssh.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # STATE VERSION
  # Do not change this after initial installation
  # ══════════════════════════════════════════════════════════════════

  system.stateVersion = "25.11";
}
