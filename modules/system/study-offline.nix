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

  # `programs.firefox.enable = true` in modules/system/cli-tools.nix is the
  # NixOS option, which puts firefox in environment.systemPackages — and this
  # specialisation inherits it. The home-side `mkForce false` never touched it,
  # so "offline airgap, no browsers" had a browser on $PATH. The firewall means
  # it could not have reached anything; that is not the feature. The feature is
  # that the thing you open out of habit is not there.
  programs.firefox.enable = lib.mkForce false;
}
