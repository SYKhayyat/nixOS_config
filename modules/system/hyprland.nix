# modules/system/hyprland.nix
#
# The compositor, and nothing else. Everything else this file used to carry is
# in ./wayland.nix, which niri.nix imports too.
{ pkgs, ... }:

{
  imports = [ ./wayland.nix ];

  programs.hyprland.enable = true;

  # Register Hyprland with uwsm so SDDM offers a "Hyprland (uwsm)" session.
  programs.uwsm.waylandCompositors.hyprland = {
    prettyName = "Hyprland";
    comment = "Dynamic tiling compositor";
    binPath = "${pkgs.hyprland}/bin/Hyprland";
  };
}
