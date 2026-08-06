# modules/system/desktop.nix
#
# The graphical stack that is not a compositor: the X server (for XWayland and
# the handful of X-only apps), the greeter, Plasma, sound, printing, Flatpak.
#
# What it no longer carries: sixteen font packages, `stylix.targets.qt.enable =
# false` and `OSFONTDIR`. Those are all answers to "how does this machine look",
# and that question has one file now — ./appearance.nix. The stylix line in
# particular was doing real damage from in here: it disabled the target that
# computes the Qt theme from `plasma6.enable`, four lines below the module that
# sets `plasma6.enable`, while ./core.nix wrote the target's output out by hand.
{ myConfig, ... }:

{
  # ── Display server ───────────────────────────────────────────────────────
  # This is the keyboard for XWayland, for SDDM, and for the handful of X-only
  # apps — i.e. everything that is not one of the two compositor configs.
  #
  # The two strings used to be written out here *and* in modules/home/keys.nix,
  # which is the file that exists because the keymap had five hand-written
  # copies. It had a sixth, one directory over, in the other module system —
  # and nothing would have said a word when they drifted: you would simply have
  # had one Hebrew toggle in niri and Hyprland and a different one at the
  # greeter, which is a bug you diagnose by logging out.
  #
  # A home-manager module and a NixOS module cannot read each other's config,
  # so the shared statement lives in `myConfig` (flake.nix), which both sides
  # already receive. Same reason `seforimPath` is there.
  services.xserver.enable = true;
  services.xserver.xkb = {
    inherit (myConfig.keyboard) layout;
    options = myConfig.keyboard.optionString;
  };

  # ── Greeter ──────────────────────────────────────────────────────────────
  # Was declared here *and* in ./core.nix — both saying `enable = true`, so the
  # module system merged two identical definitions and never said a word. It is
  # part of the graphical stack, so it is here, once. This is the greeter that
  # lists Plasma, Niri (uwsm) and Hyprland (uwsm); there are no compositor
  # specialisations any more, and this is where they went.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # ── Plasma 6 ─────────────────────────────────────────────────────────────
  # Present in every session, not only the Plasma one — one closure serves all
  # three. That is also what makes the Qt theming derivable: stylix keys on
  # `plasma6.enable`, and it is unconditionally true here.
  services.desktopManager.plasma6.enable = true;

  # ── Audio ────────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false; # PipeWire replaces it

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Printing ─────────────────────────────────────────────────────────────
  services.printing.enable = true;

  # ── KDE Connect ──────────────────────────────────────────────────────────
  # Phone pairing. ./core.nix used to open TCP and UDP 1714 and 1764 by hand,
  # and those are the two *endpoints* of the range KDE Connect uses — it picks
  # freely inside 1714-1764, so pairing worked only if both ends happened to
  # land on exactly those two. Two ports out of fifty-one, transcribed instead
  # of derived: this repo's oldest bug, in its smallest possible form.
  #
  # This module contributes the whole range to `allowedTCPPortRanges` and
  # `allowedUDPPortRanges` itself, and installs the app that Plasma's indicator
  # talks to. No file in this repo names a KDE Connect port any more.
  programs.kdeconnect.enable = true;

  # ── Flatpak ──────────────────────────────────────────────────────────────
  # For apps outside nixpkgs. Portals are configured in
  # hosts/desktop/configuration.nix. Add the remote once:
  #   flatpak remote-add --if-not-exists flathub \
  #     https://dl.flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;
}
