# modules/system/niri.nix
#
# The compositor, and nothing else. Everything else this file used to carry is
# in ./wayland.nix, which hyprland.nix imports too.
{ pkgs, ... }:

{
  imports = [ ./wayland.nix ];

  programs.niri.enable = true;

  # Register niri with uwsm so SDDM offers a "Niri (uwsm)" session.
  programs.uwsm.waylandCompositors.niri = {
    prettyName = "Niri";
    comment = "Scrollable tiling compositor";
    binPath = "${pkgs.niri}/bin/niri";
    extraArgs = [ "--session" ];
  };
}
