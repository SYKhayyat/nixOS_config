# ShaulOS — NixOS configuration

A single-host NixOS flake for the machine `desktop` (`nixosConfigurations.desktop`,
`x86_64-linux`). One system closure offers three graphical sessions — **KDE
Plasma**, **Niri** and **Hyprland** — which you pick at the SDDM greeter, plus a
single boot-time **specialisation** (`study`) for hard-offline work. Theming is driven by
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
hosts/desktop/                # host entrypoint + hardware-configuration.nix
home/
  common.nix                  # shell (zsh), git, aliases, session scripts
  shaul.nix                   # THE home profile — one file, every session
modules/
  system/                     # NixOS modules (core, hardware, dev, services, secrets, ...)
    profile.nix               # the `shaulos.study` flag the home profile reads
    desktop.nix               # X, SDDM, Plasma 6, audio, printing, fonts
    wayland.nix               # everything a Wayland session needs that isn't a compositor
    niri.nix  hyprland.nix    # the compositors, four lines each
    study-offline.nix         # the one specialisation
  home/                       # home-manager modules
    wayland-common.nix        # bar/launcher/notifier/lock/file-manager for any Wayland session
    lock.nix                  # hyprlock + hypridle, both compositors
    palette.nix               # single source of truth for ricing colors
    emacs/default.nix         # packages + daemon only — the config is a flake input
    niri/  hyprland/          # just the compositor config files
    waybar.nix  yazi.nix  scripts.nix  foot.nix  p10k.nix
secrets/                      # sops-nix encrypted secrets (see below)
```

The Emacs *configuration* is not in this repo. It lives at
[SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config) and comes in
as a pinned flake input — it is ~3× the size of this whole Nix config, runs on
Windows and macOS as well, and has its own CI. `modules/home/emacs/default.nix`
keeps only what this *machine* provides: the package set, `services.emacs`, and
`recoll.conf`.

## Sessions

Pick these at the SDDM greeter — one system closure has all three, and SDDM
remembers the last one you used:

| Session          | Config                                          |
|------------------|-------------------------------------------------|
| **Plasma**       | `plasma-manager` in `home/shaul.nix` (default)  |
| **Niri (uwsm)**  | `modules/home/niri/default.nix` (KDL)           |
| **Hyprland (uwsm)** | `modules/home/hyprland/default.nix`          |

Prefer the `(uwsm)` entries for the tiling compositors: they get a proper
systemd user scope and working portals. Nothing needs a rebuild or a reboot to
switch — log out, pick another.

## The one specialisation

| Name    | What it changes                                             |
|---------|-------------------------------------------------------------|
| `study` | NetworkManager, wireless, Bluetooth, sshd, onedrive and rclone off; firewall deny-all; no browsers; the study toolchain instead of the desktop app suite |

Pick it in the systemd-boot menu. It is a specialisation and the sessions are
not, and the line between them is whether the difference can coexist with the
base system at runtime. "Which compositor" can — that is what a display manager
is for. "The radios are off" cannot.

`study` sets `shaulos.study = true` (declared in `modules/system/profile.nix`),
which `home/shaul.nix` reads via `osConfig`. That flag exists so there is
exactly **one** place that says which home profile to import: `home-manager.
users.<name>` is a submodule, so a second `imports = [ … ]` inside a
specialisation *merges* with the parent's rather than replacing it.

**Lost your desktop?** Reboot and pick an older generation — systemd-boot keeps
ten (`configurationLimit`). For a guaranteed TTY on any generation, press `e` at
the boot menu and append `systemd.unit=multi-user.target`. That is what the old
`minimal` specialisation was for, minus a whole system closure.

## Everyday commands

The `justfile` wraps the real `nixos-rebuild` / `nix` invocations (run `just`
or `just --list` to see them all):

```sh
just switch          # sudo nixos-rebuild switch --flake .#desktop
just test            # sudo nixos-rebuild test  --flake .#desktop  (no boot entry)
just build           # nixos-rebuild build --flake .#desktop  (build only, no activation)
just specialisations # list specialisations available for next boot (just `study`)
just update          # nix flake update
just update-emacs    # bump the emacs-config input only
just emacs-dev PATH  # rebuild against a local emacs-config checkout
just fmt             # nix fmt (nixfmt-rfc-style)
just check           # nix flake check (statix + deadnix; builds the Emacs config)
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
- **Emacs** needs nothing provisioned. The configuration lives in its own repo,
  [SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config), and
  arrives as the `emacs-config` flake input already tangled — so
  `~/.config/emacs/modules` is a read-only store symlink pinned in `flake.lock`,
  not a directory that drifts. Bump it with `just update-emacs`.

  > On the first switch after the split, home-manager will move your existing
  > writable `~/.config/emacs/modules` to `modules.pre-flake-input` rather than
  > clobber it. Diff that against the repo before deleting it — under the old
  > scheme a hand-edit in there could silently have become your live config.

See `CHANGES.md` for the last overhaul and its post-install checklist.
