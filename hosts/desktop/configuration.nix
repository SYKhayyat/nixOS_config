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
{ pkgs, unstable, myConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
    ../../modules/system/profile.nix
    ../../modules/system/hardware.nix
    ../../modules/system/base-tools.nix # what the MACHINE installs — see toolkit.nix
    ../../modules/system/development.nix
    ../../modules/system/data.nix # OneDrive + the first-boot data bootstrap
    ../../modules/system/services.nix
    ../../modules/system/desktop.nix # X, SDDM, Plasma 6, audio, printing, fonts
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
    backupCommand = "true";
    extraSpecialArgs = { inherit myConfig unstable; };
    users.${myConfig.username}.imports = [ ../../home/shaul.nix ];
  };

  specialisation.study.configuration = {
    imports = [ ../../modules/system/study-offline.nix ];
  };
}
