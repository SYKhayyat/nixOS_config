# hosts/desktop/configuration.nix
#
# One machine, one system closure, three graphical sessions, one specialisation.
#
# It used to be four specialisations (minimal / niri / hyprland / study) built by
# lib/mk-specialization.nix. Three of them were answering questions that already
# had answers:
#
#   * `hyprland` and `niri` asked "which session should the display manager
#     start" — which is what a display manager is for. Both compositors install
#     cleanly alongside Plasma and register .desktop sessions via uwsm, so SDDM
#     lists them. Building a second and third full closure to pick one at the
#     bootloader cost a rebuild of all of them on every switch, a GC root each,
#     and a reboot instead of a logout to change your mind.
#   * `minimal` asked "how do I get to a shell when the desktop is wedged" —
#     which systemd-boot already answers with `configurationLimit = 10`
#     generations, any of which boots the system you had before you broke it.
#     It also was not minimal: a specialisation inherits, so force-disabling
#     xserver/sddm/plasma6 left pipewire, printing, flatpak, all 16 font
#     packages and the whole package drawer in place — the drawer that is now
#     split between base-tools.nix and home's toolkit.nix. If you want a guaranteed
#     TTY, press `e` at the boot menu and append `systemd.unit=multi-user.target`
#     — no closure, no rebuild, and it works on every generation, not just this
#     one.
#
# `study` stays, because it is the one case where the difference cannot coexist
# at runtime: the radios are off and the firewall denies everything.
{ pkgs, myConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/profile.nix
    ../../modules/system/hardware.nix
    ../../modules/system/network.nix # NetworkManager, the firewall, sshd
    ../../modules/system/base-tools.nix # what the MACHINE installs — see toolkit.nix
    ../../modules/system/development.nix
    ../../modules/system/data.nix # the first-boot data bootstrap
    ../../modules/system/services.nix
    ../../modules/system/appearance.nix # the ONE statement of how this looks
    ../../modules/system/desktop.nix # X + the keyboard, SDDM, Plasma 6, audio, printing, KDE Connect
    ../../modules/system/niri.nix # + wayland.nix
    ../../modules/system/hyprland.nix # + wayland.nix (same path, imported once)
    ../../modules/system/secrets.nix
  ];

  # Only the answer for a user who has never logged in — SDDM remembers the last
  # session you picked and offers it again.
  services.displayManager.defaultSession = "plasma";

  # Portals. plasma6, programs.niri and programs.hyprland each register their own
  # backend and their own per-desktop portals.conf through `xdg.portal.
  # configPackages`, so the only thing left to state here is the fallback for a
  # session that ships neither. The old hand-written per-specialisation
  # extraPortals list existed because only one desktop was ever present at a
  # time; with all three in one closure the upstream mechanism is the right one.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = [ "gtk" ];
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ── The user environment ────────────────────────────────────────────────
  # ONE import site, deliberately. See modules/system/profile.nix: a second
  # definition inside the specialisation would merge with this one, not replace
  # it, which is exactly how the old study mode ended up with the full desktop
  # profile bolted underneath it.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # This was `backupCommand = "true"`, and it is worth spelling out because it
    # reads like a boolean and is not one. The option takes a *command* to run
    # on each existing file that home-manager is about to replace, instead of
    # aborting the activation. `true` is the shell builtin that succeeds and
    # does nothing — so every colliding dotfile in $HOME was "backed up" by
    # doing nothing to it, and then overwritten. No copy, no warning, no
    # non-zero exit. The one activation in the machine's life that meets your
    # pre-Nix dotfiles is the one that silently destroys them.
    #
    # That also contradicted this repo's own stated position one directory over:
    # modules/home/emacs/default.nix goes to the trouble of *moving*
    # ~/.config/emacs/modules to modules.pre-flake-input rather than deleting
    # it, and argues at length that a hand-edit in there could be the only copy.
    # The same argument applies to every other file in $HOME, and this option
    # was the global answer that said otherwise.
    #
    # `backupFileExtension` keeps the file — `foo` becomes `foo.hm-bak` — and
    # is the option the collision is actually asking about. Activation still
    # does not abort. `overwriteBackup` is deliberately left off: a second
    # collision should stop and make you look, rather than eat the backup the
    # first one made.
    backupFileExtension = "hm-bak";
    # `unstable` used to be threaded through here as well — a second full
    # nixpkgs evaluation, reachable from every home module, with zero call sites
    # in the entire repo (Lamdan 3.1). It is gone from flake.nix; re-adding it is
    # the same four lines, on the day you have a package that needs it.
    extraSpecialArgs = { inherit myConfig; };
    users.${myConfig.username}.imports = [ ../../home/shaul.nix ];
  };

  # ── The two specialisations, and the two different mechanisms ────────────
  #
  # Both pass the test ../../modules/system/study-offline.nix states — they
  # turn off *state*, which is the thing a session at the greeter cannot do —
  # and they reach for opposite halves of the specialisation module because
  # they are opposite kinds of difference.
  #
  # `study` is THIS system with the radios off. It wants every package, every
  # font, Emacs, the seforim index and all three compositors; it wants the
  # network gone. Inheriting is exactly right, and the handful of `mkForce`s it
  # writes are all it needs.
  #
  # `focus` is a SMALLER system. Written the same way it would be fifteen
  # forces deep and would silently stop being true the next time
  # ./desktop.nix gained a service — the `lynx`-in-the-airgap failure, one
  # layer down. `inheritParentConfig = false` makes it a different import list
  # instead, so what it lacks it lacks by construction. See that file.
  specialisation.study.configuration = {
    imports = [ ../../modules/system/study-offline.nix ];
  };

  specialisation.focus = {
    inheritParentConfig = false;
    configuration = {
      imports = [ ../../modules/system/focus.nix ];
    };
  };
}
