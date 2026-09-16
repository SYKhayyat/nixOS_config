# Secrets (sops-nix)

Encrypted secrets live here as `secrets.yaml`. It is safe to commit **once
encrypted** — sops keeps values encrypted, keys in plaintext. The system module
`modules/system/secrets.nix` stays inert until `secrets.yaml` exists.

## One-time setup on the machine

1. Install the tools (already in the dev shell): `nix develop` gives you `sops`
   and `age`. Or run the steps below with `nix shell nixpkgs#sops nixpkgs#age`.

2. Derive an **age key from the host SSH key** (so the machine can decrypt at
   boot with no extra secret material):

   ```sh
   sudo mkdir -p /var/lib/sops-nix
   sudo sh -c 'ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /var/lib/sops-nix/key.txt'
   # public key to put in .sops.yaml:
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. Paste that `age1…` public key into `.sops.yaml` (replace the placeholder).

4. Create and edit the encrypted file:

   ```sh
   sops secrets/secrets.yaml
   ```

   Add keys such as:

   ```yaml
   nix-access-tokens: |
     access-tokens = github.com=ghp_xxxxxxxxxxxxxxxxxxxx
   rclone.conf: |
     [unified]
     type = drive
     ...
   ```

5. Uncomment the matching `sops.secrets."…"` block in
   `modules/system/secrets.nix`, then `just switch`.

## Notes

- Never commit a plaintext secret. `.gitignore` blocks `*.plain`, `tokens.conf`,
  and `rclone.conf` as a backstop.
- To rotate: edit with `sops secrets/secrets.yaml`; to re-key after changing
  recipients: `sops updatekeys secrets/secrets.yaml`.
