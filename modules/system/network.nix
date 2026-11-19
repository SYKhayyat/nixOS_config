# modules/system/network.nix
#
# NetworkManager, DNS, the firewall, sshd — one feature, one file, so `focus`
# can decline the whole stack by not importing it.
{ myConfig, ... }:

{
  networking.networkmanager.enable = true;

  # Keep Wi-Fi powered up always. NetworkManager's default `wifi.powersave`
  # lets the adapter sleep on idle, which drops the connection while you walk
  # away. 2 = disable powersave (0 = use default, 1 = enable, 2 = disable).
  environment.etc."NetworkManager/conf.d/no-wifi-powersave.conf".text = ''
    [connection]
    wifi.powersave = 2
  '';

  # ── The Touro enterprise profile, declared here rather than in /etc ─────
  #
  # These settings used to live as an ad-hoc keyfile in
  # /etc/NetworkManager/system-connections, which this repo does not manage.
  # That file had absorbed a password that no longer matched, and nm-connection-
  # editor silently refused to open its Security tab so it could never be
  # corrected. Declaring it means every activation recreates a known-good
  # profile: PEAP/GTC, the right identity and domain, user permissions.
  #
  # Deliberately NO password here. It is an enterprise credential you enter at
  # connect time (or store once in NM's own secret agent); putting it in this
  # repo, even via sops, would make a personal password part of a config
  # checkout. The Security tab now opens because there is no stale secret to
  # block it.
  networking.networkmanager.ensureProfiles.profiles."Touro University" = {
    connection = {
      id = "Touro University";
      type = "wifi";
      interface-name = "wlo1";
      autoconnect = true;
      permissions = "user:${myConfig.username}";
    };
    wifi = {
      ssid = "Touro University";
      mode = "infrastructure";
    };
    "wifi-security".key-mgmt = "wpa-eap";
    "802-1x" = {
      eap = "peap";
      identity = "skhayyat2";
      anonymous-identity = "anonymous";
      phase2-auth = "gtc";
      domain-suffix-match = "touro.edu";
    };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

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
