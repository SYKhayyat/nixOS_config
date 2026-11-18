# modules/system/network.nix
#
# NetworkManager, DNS, the firewall, sshd — one feature, one file, so `focus`
# can decline the whole stack by not importing it.
_:

{
  networking.networkmanager.enable = true;

  # A resolver, not a host entry.
  #
  # This file used to pin 104.21.65.38 (Cloudflare, 300 s TTL) to omnirush.ai
  # in /etc/hosts, because the router's Fortiguard sinkhole answered with a
  # blocked-page address. That entry applied to every program, went stale on a
  # schedule nobody controls, and kept overriding a working answer after the
  # router was fixed. 1.1.1.1 and 9.9.9.9 return the correct record over
  # ordinary UDP 53, so the resolver is the layer that fixes it for everything.
  networking.nameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];

  networking.firewall = {
    enable = true;
    # Nothing listens. Port 22 was here for sshd, which is off below.
    allowedTCPPorts = [ ];
  };

  # sshd is off on purpose. This laptop joins untrusted networks and carries
  # the notes, keys and tokens; it is not a remote host. If that changes, turn
  # it back on keys-only — never with PasswordAuthentication, and never with
  # PermitRootLogin enabled.
  services.openssh.enable = false;
}
