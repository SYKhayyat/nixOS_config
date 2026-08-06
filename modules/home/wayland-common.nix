# modules/home/wayland-common.nix
#
# The Wayland session stack: bar, notifier, launcher, wallpaper, lock, file
# manager, clipboard, screenshots. Everything that is true of *a* Wayland
# session here rather than of one particular compositor.
#
# It used to be a function taking `xdgDesktop` because it was imported once per
# boot closure. There is one closure now, so it is a plain module, and the two
# session variables it existed to set are gone:
#
#   XDG_CURRENT_DESKTOP — uwsm sets this from the session's DesktopNames, and
#     SDDM sets it for Plasma. Pinning it in home.sessionVariables was only
#     possible when the closure knew which compositor it was for, and it would
#     now be a lie in two sessions out of three.
#   WAYLAND_DISPLAY = "wayland-1" — the compositor exports the real value. This
#     was a hardcoded guess sourced by every login shell, i.e. a guess with the
#     power to override the truth. It happened to be right.
#
# Notification/mount/bar daemons are intentionally NOT started here — each
# compositor config launches them via its own exec-once/spawn-at-startup so
# there is a single source of truth (avoids the old double-start of mako).
{ pkgs, ... }:

{
  imports = [
    ./waybar.nix
    ./yazi.nix
    ./lock.nix
  ];

  home.sessionVariables = {
    # Graphical prompt for sudo -A / ssh over Wayland
    SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;

  fonts.fontconfig.enable = true;

  # (pamixer, brightnessctl, fd, fzf, jq, playerctl, libsecret already come from
  # home/common.nix; hyprlock/hypridle from ./lock.nix; waybar from ./waybar.nix.)
  home.packages = with pkgs; [
    foot
    udiskie
    networkmanagerapplet
    cliphist
    grim
    slurp
    swappy
    libnotify
    wl-clipboard
    kdePackages.ksshaskpass

    # Notifier, launcher and wallpaper daemon. Both compositor configs spawn
    # these by name at startup and neither can start what it did not install —
    # so they belong to the session, not to a compositor.
    mako
    fuzzel
    swww

    # dolphin is bound to Mod+E in the Hyprland config and is yazi's `reveal`
    # opener, and was installed by the *niri* module. Plasma ships it
    # system-wide, which is why the gap only showed up in the one session that
    # forced Plasma off.
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.okular
  ];
}
