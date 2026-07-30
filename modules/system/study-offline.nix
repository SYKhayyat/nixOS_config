# modules/system/study-offline.nix
#
# Hard offline mode for exam/study sessions. The study specialisation inherits
# the full base system, so we must actively switch the radios and every
# network-facing service OFF here. Local tools (Emacs, seforim search, ollama)
# keep working — ollama needs no network.
{ config, lib, ... }:

{
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

  # Disable network-dependent services so nothing phones home — and so boot
  # doesn't stall waiting on network-online.target (the old file-sync hang).
  systemd.services.file-sync.enable = lib.mkForce false;
  services.onedrive.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
}
