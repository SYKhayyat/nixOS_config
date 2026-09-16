# modules/system/study-offline.nix
#
# Hard offline mode for exam/study sessions. One of two specialisations, and
# the older of them — ./focus.nix is the other, and the two are different
# shapes on purpose: `study` is this system with the radios off, `focus` is a
# smaller system. See that file's header for why it does not inherit.
#
# This one earns its status the way ./focus.nix's header states the test:
# every option below is state that genuinely cannot coexist with the base
# system at runtime. The radios are off, the firewall denies everything, and
# the sync daemons are stopped — you cannot express "networking is off" as a
# session you pick at the greeter.
#
# The specialisation inherits the full base system, so everything here is an
# active switch-off rather than an omission. Local tools (Emacs, ollama) keep
# working — neither needs the network.
#
# `seforim search` used to be named in that sentence. It is not any more:
# modules/home/emacs/default.nix sets EMACS_MODULE_GROUPS = "essentials", so
# the seforim commands are not loaded in any closure. See the header there.
{ lib, ... }:

{
  # Tell the home profile which closure it is in. See modules/system/profile.nix.
  shaulos.study = true;

  # No networking at all.
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;

  # ── And the DHCP client the two lines above bring back ──────────────────
  #
  # This is the same bug ./focus.nix:126-142 documents at length, arriving
  # here by the other route, and it shipped in this file for as long as the
  # airgap has existed.
  #
  # `networking.useDHCP` defaults to **true**, and it is not NetworkManager
  # that implements it. nixpkgs' network-manager module sets it false inside
  # `mkIf cfg.enable` — so the base system is not offering a lease because
  # NetworkManager is on, and the moment the force above turns NetworkManager
  # off that definition goes with it and the nixpkgs default of true wins. The
  # closure evaluates, builds and boots with an enabled `dhcpcd.service`
  # soliciting a lease on every interface.
  #
  # The firewall below does not cover it and cannot: those four lists are an
  # *inbound* claim, and dhcpcd's initial DISCOVER goes out over a raw
  # AF_PACKET socket that never traverses the INPUT chain. The radios really
  # are off, so this only ever bit on a wired link — which is precisely why a
  # laptop used on wifi would never show it.
  #
  # ./focus.nix's line is the general rule; this is its second call site.
  # `mkForce` rather than a plain assignment for the reason the section at the
  # bottom of this file gives: in an inheriting specialisation every
  # subtraction is spelled as a force, and this one must beat whatever the
  # parent's networking modules decide.
  networking.useDHCP = lib.mkForce false;

  # Deny everything at the firewall as a backstop — all four lists, not the two
  # obvious ones.
  #
  # `programs.kdeconnect.enable` in ./desktop.nix contributes to
  # `allowedTCPPortRanges` and `allowedUDPPortRanges`, which the singular
  # `allowedTCPPorts`/`allowedUDPPorts` forces do not touch. With only those
  # two, "the firewall denies everything" would have quietly become false and a
  # 51-port range would have stayed open in the airgap, with nothing printed.
  #
  # A backstop that enumerates which *modules* to undo is not a backstop; it is
  # a list you have to remember to extend, which is the same fault the package
  # rule exists to kill. These forces are written in terms of the firewall's own
  # surface instead, so a feature added later cannot punch through it.
  networking.firewall = {
    enable = lib.mkForce true;
    allowedTCPPorts = lib.mkForce [ ];
    allowedUDPPorts = lib.mkForce [ ];
    allowedTCPPortRanges = lib.mkForce [ ];
    allowedUDPPortRanges = lib.mkForce [ ];
  };

  # Kill the radios.
  hardware.bluetooth.enable = lib.mkForce false;

  # Disable network-dependent services so nothing phones home.
  #
  # The boot stall this comment used to also claim credit for was never fixed
  # here — it was fixed in modules/system/data.nix by taking the bootstrap off
  # the boot path entirely. It was `wantedBy = multi-user.target` with
  # `after = network-online.target`, so every boot of the *normal* system waited
  # on the network for it; the airgap only ever hid that from this one closure.
  #
  # The timer is the part that matters now — nothing else starts the service —
  # but both are named so `systemctl start` is off too.
  systemd.timers.shaulos-data-bootstrap.enable = lib.mkForce false;
  systemd.services.shaulos-data-bootstrap.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  #
  # `services.onedrive.enable = lib.mkForce false` used to sit here. The base
  # system no longer enables it, so there is nothing to undo: it had never been
  # authenticated on any machine, which made it a hedge that this file paid
  # rent on. One fewer force to remember is the whole point of the section
  # below.

  # ── What is NOT here any more, and why that is the fix ──────────────────
  #
  # There used to be a `programs.firefox.enable = lib.mkForce false;` on this
  # line. It was undoing `programs.firefox.enable = true` in
  # modules/system/cli-tools.nix, which put firefox into
  # environment.systemPackages, which this specialisation inherits.
  #
  # It worked, and it was the wrong shape, and the proof is that `lynx` sat two
  # words away on line 31 of that same file and nobody wrote a second mkForce
  # for it. So "offline airgap, no browsers" shipped with a browser on $PATH.
  #
  # A specialisation can only ever *add* — inheriting is the whole mechanism —
  # so every subtraction it wants has to be spelled as a force, and a list of
  # forces is a list you have to remember to extend. The packages moved to
  # modules/home/toolkit.nix instead, where the flag this file sets subtracts
  # them by construction and browsers are one named group you can read.
  #
  # What is left below is the shape a specialisation is actually good at:
  # turning off *state*. Every line is a service or a radio, not a package.
}
