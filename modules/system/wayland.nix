# modules/system/wayland.nix
#
# Everything a Wayland session on this machine needs that is NOT the compositor.
#
# These 22 lines used to be copy-pasted, byte for byte, into niri.nix and
# hyprland.nix. That was invisible while the two were mutually exclusive boot
# closures — you could never see them side by side — and it is the reason the
# two sessions drifted apart in every direction nobody was looking.
#
# Imported by modules/system/niri.nix and modules/system/hyprland.nix rather
# than by the host, so each compositor module still stands alone. The module
# system keys imports by path, so importing both costs exactly one copy.
{ pkgs, ... }:

{
  # Session manager for the tiling compositors. Plasma does not use it; SDDM
  # lists both the plain and the -uwsm session for niri/hyprland and the uwsm
  # one is the one you want (proper systemd user scope, working portals).
  programs.uwsm.enable = true;

  # Backlight without a setuid helper (programs.light is gone in 26.05).
  hardware.acpilight.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;

  # Authentication & secrets
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  # gnome-keyring and GTK need gcr on the bus to draw password prompts.
  services.dbus.packages = [ pkgs.gcr ];

  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    wayland-utils
    wl-clipboard
    libsecret
    polkit_gnome
    networkmanagerapplet
  ];

  fonts.fontconfig.enable = true;
}
