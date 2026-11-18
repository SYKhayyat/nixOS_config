# modules/system/sway.nix
#
# Sway: the i3-lineage compositor, beside Hyprland (../hyprland.nix). It
# splits into a *tree you control by hand* rather than an automatic dwindle:
# `splith`/`splitv` at any depth, `swap container with mark` for exchanging
# two windows outright, and a real scratchpad. This is where "make a grid and
# swap two cells" comes from, which is why it is here.
#
# The compositor, and nothing else. Everything a Wayland session needs that
# is not the compositor is in ./wayland.nix, which hyprland.nix imports too.
{ config, ... }:

{
  imports = [ ./wayland.nix ];

  programs.sway.enable = true;

  # XWayland, from sway's own module — the same half hyprland.nix sets by
  # hand in its wrapper.
  programs.sway.xwayland.enable = true;

  # No extraPackages. sway auto-configures its outputs on its own, which is
  # the same answer Hyprland's `preferred, auto` gives. `kanshi` is the thing
  # to add the day an external panel needs a profile the single-panel default
  # does not cover, and not before then.

  # Register sway with uwsm so SDDM offers "Sway (UWSM)" beside the plain
  # "Sway" that `programs.sway.enable` contributes. The uwsm one is the one
  # you want: proper systemd user scope and working portals. No new unit
  # work — the `X-RestartIfChanged=false` drop-ins in ./wayland.nix land on
  # the `wayland-wm@.service` *template*, so sway is covered by the same fix
  # Hyprland has.
  #
  # `binPath` comes off `programs.sway.package`, not `pkgs.sway`: `pkgs.sway`
  # would be a second statement of which sway this machine runs, agreeing with
  # the module's only by default.
  programs.uwsm.waylandCompositors.sway = {
    prettyName = "Sway";
    comment = "i3-compatible tiling compositor";
    binPath = "${config.programs.sway.package}/bin/sway";
  };
}
