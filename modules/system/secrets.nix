# modules/system/secrets.nix
#
# sops-nix wiring. Everything here is gated on secrets/secrets.yaml existing,
# so a fresh checkout of the flake still evaluates without it. On this machine
# that file is present and the GitHub token is live; adding another secret is
# an entry in secrets.yaml plus its block below — see secrets/README.md.
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

    # ── Live: the Nix GitHub token ─────────────────────────────────────────
    #
    # secrets/secrets.yaml holds it, and this renders it to the file core.nix
    # `!include`s, so Nix stops hitting the anonymous GitHub API rate limit.
    # Check it after a switch with `ls -l /run/secrets/nix-access-tokens`; a
    # missing host age key at /var/lib/sops-nix/key.txt shows up as that file
    # not existing, not as a build error.
    secrets."nix-access-tokens" = {
      path = "/etc/nix/tokens.conf";
      mode = "0440";
      group = "wheel";
    };

    # ── Commented: the rclone remote for the data bootstrap ────────────────
    #
    # With this uncommented the bootstrap (modules/system/data.nix) needs no
    # interactive `rclone config` on a fresh machine — which is the whole point
    # of it being a bootstrap.
    # secrets."rclone.conf" = {
    #   path = "${config.users.users.shaul.home}/.config/rclone/rclone.conf";
    #   owner = "shaul";
    # };
  };
}
