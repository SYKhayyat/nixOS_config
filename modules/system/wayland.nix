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
{ lib, pkgs, ... }:

{
  # Session manager for the tiling compositors. Plasma does not use it; SDDM
  # lists both the plain and the -uwsm session for niri/hyprland and the uwsm
  # one is the one you want (proper systemd user scope, working portals).
  programs.uwsm.enable = true;

  # ── Why `just switch` threw you back to the greeter under niri/Hyprland ──
  #
  # The symptom is that a rebuild "reboots" the machine in the two tiling
  # sessions and never in Plasma. It is not a reboot and it is not a crash: the
  # graphical session is torn down and `display-manager.service` — which is
  # `Restart=always` — brings SDDM straight back, which from the chair is
  # indistinguishable from one.
  #
  # Three facts, and the bug is entirely in how they compose:
  #
  #   1. `switch-to-configuration` restarts *user* units, not only system ones.
  #      It builds `units_to_stop` / `units_to_restart` for the per-user systemd
  #      manager and drives them over D-Bus, then runs home-manager activation.
  #
  #   2. Under uwsm the compositor IS a user unit. `programs.uwsm` ships its
  #      units through `systemd.packages`, so they land in /etc/systemd/user and
  #      NixOS owns them — including `wayland-wm@Hyprland.service`, which is the
  #      running Hyprland. Plasma is not a user unit at all: SDDM execs
  #      `startplasma-wayland` into a session scope that switch-to-configuration
  #      never looks at. That asymmetry is the whole reason this is a
  #      two-sessions-out-of-three bug.
  #
  #   3. Restarting any of these four does not restart a component, it ends the
  #      session. Every one of them carries
  #
  #          OnSuccess=wayland-session-shutdown.target
  #          OnSuccessJobMode=replace-irreversibly
  #          OnFailure=wayland-session-shutdown.target
  #          OnFailureJobMode=replace-irreversibly
  #
  #      and `wayland-wm@.service` additionally has
  #      `PropagatesStopTo=graphical-session.target` while
  #      `wayland-session@.target` has `BindsTo=graphical-session.target`. So
  #      stopping the compositor propagates a stop to the graphical session and
  #      fires an *irreversible* shutdown job that nothing later in the switch
  #      can cancel.
  #
  #      `wayland-wm-env@.service` is the worst of them and is worth naming: it
  #      is `Type=oneshot` + `RemainAfterExit=yes` + `RefuseManualStop=yes`, so
  #      a restart request does not merely restart it — systemd refuses, the
  #      job fails, and the failure fires the same irreversible teardown. Its
  #      `ExecStopPost` is `uwsm aux cleanup-env`, which erases the session
  #      environment on the way out.
  #
  # The trigger is the unit *files* changing, i.e. whenever the uwsm store path
  # moves — a `just update`, or any nixpkgs bump that rebuilds it. Not every
  # rebuild, which is exactly why this reads as intermittent.
  #
  # The fix is the one NixOS already applies to itself for the same reason:
  #
  #     systemd.services."user@".restartIfChanged = false;
  #     systemd.services.systemd-user-sessions.restartIfChanged = false;
  #       # Restart kills all active sessions.
  #
  # `restartIfChanged = false` emits `X-RestartIfChanged=false`, which
  # switch-to-configuration honours for user units through the same code path it
  # uses for system ones, and it resolves a running `foo@bar.service` back to
  # the `foo@.service` template before checking. `overrideStrategy = "asDropin"`
  # is required because these units come from a package rather than from this
  # config: it emits a drop-in beside the unit instead of a whole replacement
  # file, and switch-to-configuration merges `<unit>.d/*.conf` when it reads
  # them.
  #
  # What this gives up is nothing you want: a session already running keeps the
  # units it started with, and the new ones apply at the next login — which is
  # the only moment a compositor's unit definition can honestly change anyway.
  # `wayland-wm-app-daemon.service` is deliberately NOT in this list; it is
  # merely `PartOf=graphical-session.target`, so restarting it is safe and
  # picking up a new one mid-session is correct.
  #
  # One template covers both compositors: uwsm names the instance after the
  # binary, so this is `wayland-wm@Hyprland.service` and `wayland-wm@niri.service`
  # — verified by running `uwsm start -n -o` against each binPath, which reports
  # "Selected compositor ID: Hyprland" / "niri" and the matching unit subdirs.
  # A drop-in on the template applies to every instance, so niri and Hyprland
  # get identical treatment and neither can drift from the other.
  #
  # ── Why `systemd.user.units` and raw text, not `systemd.user.services` ───
  #
  # The obvious spelling is `systemd.user.services.<n>.restartIfChanged = false`,
  # and it emits the right `X-RestartIfChanged=false` — along with three lines
  # you did not ask for. nixos/lib/systemd-lib.nix builds every generated
  # service's environment as
  #
  #     env = cfg.globalEnvironment // def.environment;
  #
  # so the drop-in also carries `Environment="PATH=…"` (coreutils, findutils,
  # gnugrep, gnused, systemd — five entries), plus LOCALE_ARCHIVE and TZDIR.
  # In a drop-in that is not additive in the way it looks: `wayland-wm@.service`
  # gets its real environment from `EnvironmentFile=-%t/uwsm/env_session.conf`,
  # which `wayland-wm-env@.service` writes, and systemd applies `Environment=`
  # *over* `EnvironmentFile=`. So the fix for the rebuild would have handed the
  # compositor — and therefore every program any keybind spawns — a five-entry
  # PATH. Trading a session that dies on `just update` for one where `Mod+D`
  # cannot find fuzzel is not a trade.
  #
  # `systemd.user.units` is the layer below: `text` is the drop-in, verbatim,
  # and nothing is merged into it.
  systemd.user.units =
    lib.genAttrs
      [
        "wayland-wm@.service"
        "wayland-wm-env@.service"
        "wayland-session-bindpid@.service"
        "wayland-session-waitenv.service"
      ]
      (_: {
        overrideStrategy = "asDropin";
        text = ''
          [Service]
          X-RestartIfChanged=false
        '';
      });

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
