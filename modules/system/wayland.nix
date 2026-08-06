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

  # There was an `environment.systemPackages` here and every entry in it was
  # already accounted for somewhere else. `wl-clipboard` and
  # `networkmanagerapplet` are in ../home/wayland-common.nix, which is where the
  # things a session spawns belong. `libsecret` and `wayland-utils` are tools
  # you type, so they are in ../home/toolkit.nix. And `polkit_gnome` never
  # needed a list at all: ../home/keys.nix starts the agent by store path, so it
  # is in the closure whether or not anything puts it on $PATH — which nothing
  # should, because it is a libexec helper you never invoke by name.
  #
  # The gcr line above is the counter-example and the reason this file still
  # exists: it puts a package on the *bus*, not on a path, and only the system
  # can do that.

  fonts.fontconfig.enable = true;

  # Run natively on Wayland rather than through XWayland. These three were in
  # core.nix beside the scaling and Qt-theme variables, which is how a fact
  # about *this* — a Wayland session — came to be filed under "the machine".
  # The scaling half went to ./appearance.nix; this half is the session's.
  #
  # Every session on this box is Wayland (SDDM runs with `wayland.enable`), so
  # although this module is imported by the two compositor modules it applies to
  # the Plasma session too — which is what you want, and what makes it safe to
  # state once here rather than per compositor.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Chromium/Electron
    MOZ_ENABLE_WAYLAND = "1"; # Firefox
    QT_WAYLAND_RECONNECT = "1"; # survive a compositor restart
  };
}
