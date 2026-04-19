# modules/system/core.nix
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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  # ══════════════════════════════════════════════════════════════════
  # SECURITY & PORTALS
  # ══════════════════════════════════════════════════════════════════

  security.rtkit.enable = true;  # Required for PipeWire
  security.polkit.enable = true; # Required for privilege escalation

  # XDG Portals: Critical for Niri to handle secrets and file dialogs
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.common.default = [ "gtk" ];
  };

  # ══════════════════════════════════════════════════════════════════
  # BASIC SERVICES
  # ══════════════════════════════════════════════════════════════════

  services.openssh.enable = true;
  services.dbus.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # STATE VERSION
  # ══════════════════════════════════════════════════════════════════

  system.stateVersion = "25.11";
}
