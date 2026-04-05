# modules/system/niri.nix
{ pkgs, ... }: {
  programs.niri.enable = true;

  # Performance and Wayland Essentials
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

  # System-level utilities for Niri
  environment.systemPackages = with pkgs; [
    wayland-utils
    wl-clipboard
    libsecret     # Keyring support
    gnome-keyring
  ];

  # Enable Polkit for GUI sudo prompts
  security.polkit.enable = true;
  
  # Ensure Hebrew and other fonts are available to Wayland apps
  fonts.fontconfig.enable = true;
}}
