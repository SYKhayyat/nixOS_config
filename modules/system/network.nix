# modules/system/network.nix
#
# How this machine reaches the network, and the one port it answers on.
#
# These three stanzas were in ./core.nix, and moving them is what makes the
# `focus` specialisation possible at all. That closure is built with
# `inheritParentConfig = false` — it is not this system with things switched
# off, it is a different import list — so anything it does not want has to be
# in a file it does not import. While NetworkManager and sshd lived in core.nix
# they were unavoidable: core.nix is also where the boot loader, the user
# account and the locale are, and a closure cannot decline half a file.
#
# So this is the same move ../home/toolkit.nix made for packages and
# ./wayland.nix made for the compositor stack, applied to the network: state
# the fact in a module, and let the closure that does not want it simply not
# import it. `focus` therefore has no NetworkManager, no wpa_supplicant, no
# ModemManager and no sshd — not because it forced them off, but because
# nothing turned them on.
#
# `networking.hostName` deliberately stayed behind in core.nix. It is the name
# of the machine, which is true in every closure including the one with no
# network at all.
#
# ./study-offline.nix still forces all of this off, and still needs to: `study`
# is an ordinary inheriting specialisation, so it gets this file via
# hosts/desktop/configuration.nix and can only subtract with `mkForce`. That is
# the difference between the two modes in one sentence — `study` is the base
# system with the radios off, `focus` is a smaller system.
_:

{
  networking.networkmanager.enable = true;

  # 22 is sshd, below, and it is the only port this repo has an opinion about.
  #
  # There used to be 1714 and 1764 here too, on both protocols — the two
  # *endpoints* of the range KDE Connect uses. It picks freely inside
  # 1714-1764, so that opened two ports out of fifty-one and pairing worked
  # only if both ends happened to land on them. `programs.kdeconnect.enable` in
  # ./desktop.nix contributes the whole range to `allowedTCPPortRanges` and
  # `allowedUDPPortRanges` on its own, which is the shape you want: a feature
  # states its own requirements, and a second file transcribing two of the
  # fifty-one is how you get a firewall that is open and a phone that still
  # will not pair.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh.enable = true;
}
