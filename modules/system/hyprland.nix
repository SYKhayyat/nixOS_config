# modules/system/hyprland.nix
#
# The compositor, and nothing else. Everything else this file used to carry is
# in ./wayland.nix, which niri.nix imports too.
{ lib, ... }:

{
  imports = [ ./wayland.nix ];

  programs.hyprland.enable = true;

  # The setcap wrapper carries CAP_SYS_NICE, but NixOS's default wrapper
  # permissions (`u+rx,g+x,o+x`) leave it unreadable by anyone but root — a
  # hardening choice for capability-carrying binaries. uwsm refuses to launch
  # a compositor whose binPath it cannot *read* ("Path ... is not readable!"
  # and the session drops back to SDDM), so restore the historical a+rx.
  # Reading the binary grants nothing; executing it is what confers
  # capabilities, and o+x was already there.
  security.wrappers.Hyprland.permissions = lib.mkOverride 900 "a+rx";

  # Register Hyprland with uwsm so SDDM offers a "Hyprland (UWSM)" session.
  # `programs.hyprland.withUWSM` is not the option to use here: all it does is
  # switch `programs.uwsm.enable` on, and uwsm's own module says the
  # `waylandCompositors` entry is still required — it is what generates the
  # wayland-session desktop file. ./wayland.nix already enables uwsm for both
  # compositors, so this is the whole registration.
  #
  # ── binPath is /run/wrappers, and that is the fix ────────────────────────
  #
  # This said `${pkgs.hyprland}/bin/Hyprland`, the raw store binary. NixOS's
  # own Hyprland module does this, four lines from where it enables the thing:
  #
  #     security.wrappers.Hyprland = {
  #       owner = "root"; group = "root";
  #       capabilities = "cap_sys_nice+ep";
  #       source = lib.getExe cfg.package;
  #     };
  #
  # Hyprland asks the kernel for SCHED_RR on startup and needs CAP_SYS_NICE to
  # get it. The capability lives on the setcap wrapper at
  # /run/wrappers/bin/Hyprland, not on the store path — a store path cannot
  # carry file capabilities at all, since /nix/store is a read-only,
  # deduplicated filesystem. So the "Hyprland (UWSM)" session was starting the
  # one copy of the binary that cannot have the permission the module exists to
  # grant, and Hyprland dropped to normal scheduling priority with a line in a
  # log nobody reads. The plain "Hyprland" session, which SDDM also lists,
  # resolves through $PATH and got the wrapper — so the two entries in the same
  # greeter menu did not start the same thing.
  #
  # uwsm's own option documentation makes the general version of this point:
  # use a /run path rather than `lib.getExe pkgs.<compositor>`, so that what
  # uwsm launches is what the system installed. /run/wrappers/bin is the
  # stronger form of that for Hyprland specifically, and it is first on the
  # default PATH for the same reason.
  programs.uwsm.waylandCompositors.hyprland = {
    prettyName = "Hyprland";
    comment = "Dynamic tiling compositor";
    binPath = "/run/wrappers/bin/Hyprland";
  };
}
