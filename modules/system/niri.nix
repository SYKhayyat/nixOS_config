# modules/system/niri.nix
#
# The compositor, and nothing else. Everything else this file used to carry is
# in ./wayland.nix, which hyprland.nix imports too.
{ config, ... }:

{
  imports = [ ./wayland.nix ];

  programs.niri.enable = true;

  # Register niri with uwsm so SDDM offers a "Niri (UWSM)" session, beside the
  # plain "Niri" one that `programs.niri.enable` contributes through
  # `services.displayManager.sessionPackages`.
  #
  # `binPath` comes off `programs.niri.package` rather than `pkgs.niri`, which
  # is the same two-definitions problem this repo has already paid for with the
  # keymap and the palette: `pkgs.niri` is a *second* statement of which niri
  # this machine runs, and it agrees with the module's only by default. Set
  # `programs.niri.package` — to an overlay, a pin, a patched build — and the
  # greeter's uwsm entry would go on starting the old one, with nothing to say
  # so. See ./hyprland.nix, where the same line had a second and worse
  # consequence.
  programs.uwsm.waylandCompositors.niri = {
    prettyName = "Niri";
    comment = "Scrollable tiling compositor";
    binPath = "${config.programs.niri.package}/bin/niri";
    # `--session` is niri's "I am the main compositor instance" flag: import the
    # environment into systemd and D-Bus and run niri's D-Bus services. niri's
    # own help says to set it when started by a display manager, which is this.
    # uwsm manages the session *targets*; it does not export niri's D-Bus
    # services, so this is not the duplicate it looks like.
    extraArgs = [ "--session" ];
  };
}
