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

  # The one name the router refuses to give out.
  #
  # Every lookup here goes to `192.168.1.1`, and it answers `omnirush.ai` with
  # `208.91.112.55` — a Fortiguard SDNS sinkhole, the address that serves a
  # "blocked" page rather than the site. So `omnirush` opens 443 against a
  # machine that never answers one and dies with ETIMEDOUT, while Firefox,
  # switched to DNS-over-HTTPS, gets the real address and works. The browser
  # and the CLI were never asking the same resolver, which is why one could
  # reach it and the other could not.
  #
  # The resolver is the whole problem: `1.1.1.1`, `8.8.8.8` and `9.9.9.9` all
  # return the correct address over ordinary UDP 53, so nothing is hijacking
  # port 53 and no tunnel, DoH or DoT is needed to work around it. Firefox's
  # setting was a heavier version of this same line.
  #
  # This is a workaround, not a fix, and it is meant to be deleted. The address
  # belongs to Cloudflare, carries a 300 second TTL and will rotate out from
  # under it in time; when `omnirush doctor` next reports the manager
  # unreachable, fetch a fresh one with:
  #
  #   curl --doh-url https://1.1.1.1/dns-query -H 'accept: application/dns-json' \
  #        'https://1.1.1.1/dns-query?name=omnirush.ai&type=A'
  #
  # The wider fix — pointing the machine at a clean resolver, or letting
  # systemd-resolved do DNS-over-TLS — would work for every program on the box,
  # and that is the reason it was not taken: the sinkhole is this router's
  # filtering, and a one-host entry narrows the change to the one host that
  # needs it.
  #
  # It lives here rather than in ./core.nix for the reason the file gives
  # above: `focus` does not import this file, and `focus` has no network
  # stack to resolve against.
  networking.hosts."104.21.65.38" = [ "omnirush.ai" ];

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
