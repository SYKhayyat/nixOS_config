# modules/home/wayland-common.nix
#
# Shared home-manager bits for every Wayland compositor session (niri, hyprland,
# study). Previously these were copy-pasted across home/niri.nix and
# home/study.nix. Import as a *function* so the compositor name is passed in:
#
#   imports = [ (import ../modules/home/wayland-common.nix { xdgDesktop = "niri"; }) ];
#
# Notification/mount/bar daemons are intentionally NOT started here — each
# compositor module launches them via its own exec-once/spawn-at-startup so
# there is a single source of truth (avoids the old double-start of mako/udiskie).
{ xdgDesktop }:
{ pkgs, lib, config, ... }:

{
  systemd.user.sessionVariables = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_CURRENT_DESKTOP = xdgDesktop;
  };

  home.sessionVariables = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_CURRENT_DESKTOP = xdgDesktop;
    # Graphical prompt for sudo -A / ssh over Wayland
    SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;

  fonts.fontconfig.enable = true;

  # Toolkit shared by all Wayland sessions. (pamixer, brightnessctl, fd, fzf,
  # jq, playerctl, libsecret already come from home/common.nix.)
  home.packages = with pkgs; [
    foot
    wlogout
    udiskie
    networkmanagerapplet
    cliphist
    grim
    slurp
    swappy
    libnotify
    wl-clipboard
    kdePackages.ksshaskpass
  ];
}
