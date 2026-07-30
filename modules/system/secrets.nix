# modules/system/secrets.nix
#
# sops-nix wiring. This module is INERT until secrets/secrets.yaml exists, so a
# fresh checkout of the flake still evaluates. Once you create the encrypted
# file (see secrets/README.md), uncomment the secret(s) you want and rebuild.
{ config, lib, ... }:

let
  secretsFile = ../../secrets/secrets.yaml;
  hasSecrets = builtins.pathExists secretsFile;
in
{
  sops = lib.mkIf hasSecrets {
    defaultSopsFile = secretsFile;
    # The host age key, derived from the machine's ssh host key by default,
    # or place one at this path (see secrets/README.md).
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = false;

    # ── Example secrets (uncomment after adding them to secrets.yaml) ──────
    #
    # A GitHub token so Nix doesn't hit the anonymous API rate limit. Rendered
    # to a file that core.nix already `!include`s (/etc/nix/tokens.conf).
    # secrets."nix-access-tokens" = {
    #   path = "/etc/nix/tokens.conf";
    #   mode = "0440";
    #   group = "wheel";
    # };
    #
    # rclone remote config for the file-sync service.
    # secrets."rclone.conf" = {
    #   path = "${config.users.users.shaul.home}/.config/rclone/rclone.conf";
    #   owner = "shaul";
    # };
  };
}
