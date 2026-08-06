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
{ ... }:

{
  # ── Display server ───────────────────────────────────────────────────────
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us,il";
    options = "grp:lctrl_lalt_toggle,caps:escape";
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

  # ── Flatpak ──────────────────────────────────────────────────────────────
  # For apps outside nixpkgs. Portals are configured in
  # hosts/desktop/configuration.nix. Add the remote once:
  #   flatpak remote-add --if-not-exists flathub \
  #     https://dl.flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;
}
