# modules/system/study-offline.nix
#
# Hard offline mode for exam/study sessions, and the only specialisation left.
# It earns that status: every option below is state that genuinely cannot
# coexist with the base system at runtime. The radios are off, the firewall
# denies everything, and the sync daemons are stopped — you cannot express
# "networking is off" as a session you pick at the greeter.
#
# The specialisation inherits the full base system, so everything here is an
# active switch-off rather than an omission. Local tools (Emacs, seforim
# search, ollama) keep working — none of them need the network.
{ lib, ... }:

{
  # Tell the home profile which closure it is in. See modules/system/profile.nix.
  shaulos.study = true;

  # No networking at all.
  networking.networkmanager.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;

  # Deny everything at the firewall as a backstop.
  networking.firewall = {
    enable = lib.mkForce true;
    allowedTCPPorts = lib.mkForce [ ];
    allowedUDPPorts = lib.mkForce [ ];
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
  services.onedrive.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;

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
