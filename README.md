# ShaulOS — NixOS configuration

A single-host NixOS flake for the machine `desktop` (`nixosConfigurations.desktop`,
`x86_64-linux`). The base system boots **KDE Plasma**; four boot-time
**specialisations** swap in alternative desktop sessions, a literate Emacs
environment, and an offline "study" mode. Theming is driven by
[stylix](https://github.com/nix-community/stylix), Plasma by
[plasma-manager](https://github.com/nix-community/plasma-manager), the user
environment by [home-manager](https://github.com/nix-community/home-manager),
and secrets by [sops-nix](https://github.com/Mic92/sops-nix).

## Requirements

- Nix with **flakes** and `nix-command` enabled
  (`experimental-features = nix-command flakes`).
- Pinned to **NixOS 26.05 "Yarara"** (`nixos-26.05`, `home-manager`
  `release-26.05`, `stylix` `release-26.05`). A second `nixpkgs-unstable` input
  is exposed to modules as the `unstable` arg for per-package bleeding edge.
- The Nix implementation is **Lix** (`nix.package = pkgs.lixPackageSets.stable.lix`).
- A NixOS host. The rebuild alias and secrets assume the flake is checked out at
  `/home/shaul/nixOS_config-specializations` (see `myConfig.flakePath` in
  `flake.nix`); change it there if you clone elsewhere.

## Layout

```
flake.nix                     # inputs, myConfig, outputs (host + fmt/check/devShell)
hosts/desktop/                # host entrypoint + hardware-configuration.nix + specialisations
lib/mk-specialization.nix     # factory that builds each specialisation
home/
  common.nix                  # shell (zsh/p10k), git, aliases — imported by ALL sessions
  desktop.nix / niri.nix / study.nix
modules/
  system/                     # NixOS modules (core, hardware, dev, services, secrets, ...)
  home/                       # home-manager modules
    wayland-common.nix        # shared toolkit for niri/hyprland/study
    palette.nix               # single source of truth for ricing colors
    emacs/  niri/  hyprland/  waybar.nix  yazi.nix  ...
secrets/                      # sops-nix encrypted secrets (see below)
```

## Specialisations

Specialisations are defined in `hosts/desktop/configuration.nix` and built by
`lib/mk-specialization.nix`. The base system boots **KDE Plasma**; the others
appear in the systemd-boot menu:

| Name       | Session            | Home profile       | Notes                     |
|------------|--------------------|--------------------|---------------------------|
| *(base)*   | Plasma             | `home/desktop.nix` | default                   |
| `hyprland` | Hyprland (uwsm)    | `home/desktop.nix` | full desktop + Hyprland   |
| `niri`     | Niri (uwsm)        | `home/niri.nix`    | scrollable tiling         |
| `study`    | Hyprland (uwsm)    | `home/study.nix`   | offline airgap, no browsers |
| `minimal`  | none (TTY)         | —                  | recovery mode             |

## Everyday commands

The `justfile` wraps the real `nixos-rebuild` / `nix` invocations (run `just`
or `just --list` to see them all):

```sh
just switch          # sudo nixos-rebuild switch --flake .#desktop
just test            # sudo nixos-rebuild test  --flake .#desktop  (no boot entry)
just build           # nixos-rebuild build --flake .#desktop  (build only, no activation)
just specialisations # list specialisations available for next boot
just update          # nix flake update
just fmt             # nix fmt (nixfmt-rfc-style)
just check           # nix flake check — statix + deadnix, AND the Emacs modules
just check-emacs     # module consistency only (~1s, no Emacs needed)
just verify-emacs    # tangle + byte-compile every module against the real packages
just gc              # nix-collect-garbage --delete-older-than 14d
just bundle          # dump all *.nix into combined.txt (e.g. to paste)
```

Shell aliases (from `home/common.nix`): `nrs` (switch), `nrt` (test),
`nfu` (flake update) — these use `myConfig.flakePath` so they work regardless of
the current directory.

`nix develop` provides a dev shell with `nixfmt-rfc-style`, `statix`, `deadnix`,
`nil`, `just`, `nh`, plus `sops`/`age` for secrets.

## Secrets (sops-nix)

Encrypted secrets live in `secrets/secrets.yaml` and are safe to commit **once
encrypted** — sops keeps values encrypted with keys in plaintext. The module
`modules/system/secrets.nix` stays inert until `secrets.yaml` exists.

One-time setup on the machine (full walkthrough in `secrets/README.md`):

1. Derive an age key from the host SSH key so the box can decrypt at boot with no
   extra secret material, and print the matching public key:
   ```sh
   sudo mkdir -p /var/lib/sops-nix
   sudo sh -c 'ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /var/lib/sops-nix/key.txt'
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Paste that `age1…` public key into `.sops.yaml` (replace the placeholder).
3. Create/edit the encrypted file with `sops secrets/secrets.yaml`, uncomment the
   matching `sops.secrets."…"` block in `modules/system/secrets.nix`, then
   `just switch`. Re-key after changing recipients with
   `sops updatekeys secrets/secrets.yaml`.

`.gitignore` blocks `secrets/*.plain`, `tokens.conf`, and `rclone.conf` as a
backstop — never commit a plaintext secret.

## First-boot setup

Some data is provisioned outside Nix:

- **rclone** (Google Drive sync) — run `rclone config`, name the remote `unified`.
  See `modules/system/file-sync.nix` for the full walkthrough.
- **Emacs literate modules** live in `~/.config/emacs/modules/*.org` and are
  tangled on startup. Keep them in the repo (see `modules/home/emacs/modules`) so
  a fresh install is reproducible.

See `CHANGES.md` for the last overhaul and its post-install checklist.
