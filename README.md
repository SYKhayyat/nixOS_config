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
  `release-26.05`, `stylix` `release-26.05`). One nixpkgs — a second
  `nixpkgs-unstable` input used to be threaded in as the `unstable` arg for
  per-package bleeding edge, and had zero call sites in the whole repo.
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
    core.nix                  # the machine: Nix, boot, network, locale, the user
    appearance.nix            # the ONE statement of how this machine looks
    base-tools.nix            # what the MACHINE installs — the repair set, and nothing else
    profile.nix               # the `shaulos.study` flag the home profile reads
    data.nix                  # the one-time ~/Documents bootstrap
    desktop.nix               # X, SDDM, Plasma 6, audio, printing, KDE Connect, Flatpak
    wayland.nix               # everything a Wayland session needs that isn't a compositor
    niri.nix  hyprland.nix    # the compositors, four lines each
    study-offline.nix         # the one specialisation
  home/                       # home-manager modules
    toolkit.nix               # what YOU install — every program you type, and what study removes
    wayland-common.nix        # bar/launcher/notifier/lock/file-manager for any Wayland session
    lock.nix                  # hyprlock + hypridle, both compositors
    palette.nix               # the stylix scheme, rendered per config-file syntax
    keys.nix                  # the shared keymap + autostart, rendered per compositor
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
| `study` | NetworkManager, wireless, Bluetooth, sshd and the data bootstrap off; firewall deny-all; no browsers, no downloaders, no creative or media suite |

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

## Where a package goes

A specialisation can only ever **add** — inheriting the parent is the whole
mechanism. So anything in `environment.systemPackages` is present in `study` and
there is no expression that removes it, and every subtraction `study` wants has
to be spelled as a `lib.mkForce` you remembered to write.

That is not a style point. `programs.firefox.enable = true` used to live in
`modules/system/cli-tools.nix`, and `study-offline.nix` carried a `mkForce
false` to undo it. `lynx` sat two words away on line 31 of the same file and got
no such line — so *"offline airgap, no browsers"* shipped with a browser on
`$PATH`. Fixing the package rather than the drawer leaves the drawer.

So there is a rule now, and the two files that state it are
`modules/system/base-tools.nix` and `modules/home/toolkit.nix`:

| Where | What belongs there |
|---|---|
| `environment.systemPackages` (`base-tools.nix`) | Only what must work when home-manager is **broken, absent, or not yours**: `git`, `vim`, `curl`, `wget`, `htop`, `tree`, `unzip`/`zip`, plus `nh` and `home-manager` — the tools you repair a bad generation with, in a TTY, possibly *because* the home profile is what failed. Plus the spell-check stack, which is argued in the file: `DICPATH` has to be PAM-set to reach GUI apps. |
| `home.packages` (`toolkit.nix`) | Everything a person types. This is where `study` can reach it. |
| `home.packages` (the owning module) | A package that exists because one module needs it: the session stack in `wayland-common.nix`, Emacs's shell-outs in `emacs/default.nix`, the shell in `home/common.nix`. The test is *"would you still want it if you uninstalled Emacs?"* — if yes, it is a tool and it belongs in `toolkit.nix`. |
| nowhere | A program a script calls by store path (`${pkgs.grim}/bin/grim`) is in the closure already. List it only if you also want to type its name. `polkit_gnome` is the clean case: `keys.nix` starts the agent by path, and nobody ever runs it by name. |

**And a package is declared exactly once.** Thirteen were not — `fd`, `ripgrep`,
`ripgrep-all`, `plocate`, `recoll`, `pandoc`, `fzf`, `jq`, `libsecret`,
`wl-clipboard`, `networkmanagerapplet`, `nil`, `rust-analyzer` — each in one
system list and one home list. `fzf`, `bat` and `git` were listed as packages
*beside* the `programs.*` modules that install them.

`toolkit.nix` splits into two lists and the second one is what `study` removes:
browsers, anything whose job is fetching over the network, and the creative and
media suite. **Nothing else** — study keeps the search tools, the file managers,
the editors, the document toolchain, the compilers and a local media player. The
airgap is two claims: the firewall means nothing gets out, and the missing
programs mean you don't reach for them out of habit. Removing `ncdu` serves
neither.

## Theming

There is one place that decides how this machine looks:
**`modules/system/appearance.nix`** — the base16 scheme, the wallpaper, the four
font families, the cursor. Everything else derives from it.

That sentence used to be in this README with `core.nix` in it, and it was only
two-thirds true. The colours and fonts derived; the Qt theme was written out by
hand in `core.nix` *and* in `home/shaul.nix`, three of those statements under
`lib.mkForce`, while `desktop.nix` switched off the stylix target that computes
exactly the same answer from `plasma6.enable`. The cursor was stated three times
in three places, in two different sizes, under a theme name Plasma 6 no longer
ships.

```
modules/system/appearance.nix    stylix.base16Scheme + stylix.fonts + stylix.cursor
        │
        ├── stylix's own targets ──── GTK, foot, waybar base, firefox,
        │                             Qt (→ qt.style/qt.platformTheme → the
        │                             QT_* variables), the pointer
        │                             (→ home.pointerCursor)
        │
        └── modules/home/palette.nix ── config.shaulos.palette
                                            ├── .css    "#rrggbb"       → waybar, niri KDL
                                            ├── .hypr   "rgb(rrggbb)"   → hyprland.conf, hyprlock.conf
                                            ├── .font   mono/sans/sizes → waybar, hyprlock, Plasma
                                            └── .cursor name/size       → Plasma, niri KDL, hyprland.conf
```

**To re-theme, change `stylix.base16Scheme` and rebuild.** Nothing else needs
touching — which was not true before: `palette.nix` used to be five hex literals
transcribed from the scheme by hand, so a new scheme left the bar, the lock
screen and both compositors' borders on the old colours with nothing to tell
you.

`palette.nix` hands out colours **already in the target syntax**, and consuming
modules interpolate them bare. The copying-by-hand it replaced went wrong
exactly there: `hyprlock.conf` was getting `rgb(#7aa2f7)`, and hyprlang's
`rgb()` takes six *bare* hex characters, so every coloured line in it was a
parse error.

**Qt is not stated anywhere.** Stylix's NixOS Qt target reads `plasma6.enable`
and computes `qt.platformTheme = "kde"` and `qt.style = "breeze"`; nixpkgs' own
`qt` module then exports `QT_QPA_PLATFORMTHEME` and `QT_STYLE_OVERRIDE` from
those two. Four hand-written lines and three `mkForce`s were replaced by
switching the target back on. The *home-manager* Qt target stays off, and that
is not the same decision: unlike the NixOS one it has no desktop detection, so
it defaults to `qtct` → Kvantum, which is a coherent look that is not the Breeze
that Plasma renders.

**The cursor comes from `stylix.cursor`.** Stylix turns it into
`home.pointerCursor` (GTK, X11, `~/.local/share/icons`), and `palette.nix` hands
the same name and size to plasma-manager, to niri's KDL and to `hyprland.conf`.
Before, those three disagreed — 24, 12 and unset — and the one that named a
theme named `Breeze_Snow`, which KDE renamed to `Breeze_Light` for Plasma 6, so
Plasma had been silently falling back to the default pointer.

Two deliberate exceptions, both stated in the files that make them: waybar's
`font-size: 12px` (glyph sizing, not UI scale) and Plasma's toolbar font (one
point below `stylix.fonts.sizes.applications`, which is Plasma's own
convention). `stylix.targets.kde` is off — Plasma's fonts are written by
plasma-manager, but they are *built* from `stylix.fonts` rather than restated.

**Where a font goes.** Same rule as packages: exactly one list. Stylix's
font-packages target already puts the four families named in `stylix.fonts` into
`fonts.packages`, so `appearance.nix` lists only what nothing else installs —
`noto-fonts`, `noto-fonts-color-emoji` and `nerd-fonts.jetbrains-mono` were in
both, which is invisible until the day you change `stylix.fonts.monospace` and
the old family keeps being installed.

## Keys

Same mechanism as theming, one layer up. There is one place that decides what a
key does, and every file that needs it is generated from there:

```
modules/home/keys.nix        config.shaulos.keys
        │
        ├── .session ── the shared binds: terminal, launcher, file manager,
        │               Emacs, the scripts from scripts.nix, the volume keys
        ├── .startup ── the shared autostart list
        ├── .keyboard ─ xkb layout, options, repeat
        │
        ├── .niri.binds  / .niri.startup  → niri/config.kdl
        ├── .hypr.binds  / .hypr.startup  → hypr/hyprland.conf
        └── the guide                     → ~/.config/shaulos/keys.org
```

**Press `Super+Shift+/` in either session to read the generated guide.**

The split is the same one `wayland-common.nix` draws. A bind that *spawns a
program both sessions provide* is shared, because its target comes from a module
both compositors import and the key must not depend on which one is running. A
bind that names a *compositor verb* — `consume-window-into-column`,
`layoutmsg, swapnext` — lives in that compositor's own module, because niri
scrolls columns and Hyprland tiles and no abstraction should pretend otherwise.

This replaced five hand-written copies of one keymap — two configs and a
`guide.org` cheat-sheet beside each — of which four were wrong. `power-search`
was `Super+Space` under niri and `Super+P` under Hyprland; `Super+E`,
`Super+Shift+E` and `Super+1..5` existed only under Hyprland; the Hyprland
cheat-sheet documented resize on `Super+Ctrl` (it is `Super+Alt`) and listed a
three-bind dwindle section the config has never had. The niri one still told you
to rebuild a specialisation to switch sessions.

The guide is not documentation *about* the config, it is *output of* it. Editing
`~/.config/shaulos/keys.org` accomplishes nothing — the next `just switch`
overwrites it, which is the only reason it can be trusted.

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
just bootstrap-data  # fetch ~/Documents from Google Drive + GitHub (idempotent)
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

### Your documents

Nix builds the system; it does not own your files. `modules/system/data.nix`
fetches them once:

| Source                            | Destination                        |
|-----------------------------------|------------------------------------|
| Google Drive `unified:a_written`  | `~/Documents/siach_shai/a_written` |
| Google Drive `unified:seforim`    | `~/Documents/seforim`              |
| GitHub `SYKhayyat/typed_notes`    | `~/Documents/siach_shai/b_typed`   |

A timer runs it two minutes after boot — deliberately *not* on the boot path,
so nothing waits on the network for a job that is usually already done. It
skips anything already present, and it decides that by looking for **files**,
not for the directory: `modules/home/emacs/default.nix` creates
`~/Documents/seforim/Bavli` during home-manager activation, so a directory test
was always true and the seforim library never downloaded.

Run it by hand any time with `just bootstrap-data`.

**Google Drive needs rclone set up first.** Until it is, the bootstrap says so
and skips that half — it does not fail. Either decrypt the config from sops
(uncomment the `rclone.conf` secret in `modules/system/secrets.nix`, which is
the reproducible route), or configure it interactively:

```sh
rclone config
```

- `n` for a new remote, named exactly **`unified`**
- storage type **`drive`** (Google Drive)
- leave `client_id`, `client_secret`, `root_folder_id` and
  `service_account_file` blank
- scope **`1`** (full access), advanced config **`n`**, auto config **`y`**
- sign in in the browser that opens; shared drive **`n`**; confirm **`y`**, then **`q`**

It writes `~/.config/rclone/rclone.conf`. Check it with `rclone lsd unified:` —
you should see your Drive folders. Then `just bootstrap-data`.

To move the remote to another machine, either re-run `rclone config` there or
copy that one file. `.gitignore` blocks `rclone.conf`; never commit it in the
clear.

### Emacs

Nothing to provision. The configuration lives in its own repo,
[SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config), and arrives
as the `emacs-config` flake input already tangled — so `~/.config/emacs/modules`
is a read-only store symlink pinned in `flake.lock`, not a directory that
drifts. Bump it with `just update-emacs`.

> On the first switch after the split, home-manager will move your existing
> writable `~/.config/emacs/modules` to `modules.pre-flake-input` rather than
> clobber it. Diff that against the repo before deleting it — under the old
> scheme a hand-edit in there could silently have become your live config.

See `CHANGES.md` for the last overhaul and its post-install checklist.
