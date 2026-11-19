# modules/system/network.nix
#
# NetworkManager, DNS, the firewall, sshd — one feature, one file, so `focus`
# can decline the whole stack by not importing it.
_:

{
  networking.networkmanager.enable = true;

  # Keep Wi-Fi powered up always. NetworkManager's default `wifi.powersave`
  # lets the adapter sleep on idle, which drops the connection while you walk
  # away. 2 = disable powersave (0 = use default, 1 = enable, 2 = disable).
  environment.etc."NetworkManager/conf.d/no-wifi-powersave.conf".text = ''
    [connection]
    wifi.powersave = 2
  '';

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
