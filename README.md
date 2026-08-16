# ShaulOS — NixOS configuration

[![check](https://github.com/SYKhayyat/nixOS_config/actions/workflows/check.yml/badge.svg)](https://github.com/SYKhayyat/nixOS_config/actions/workflows/check.yml)

A single-host NixOS flake for the machine `desktop` (`nixosConfigurations.desktop`,
`x86_64-linux`). One system closure offers three graphical sessions — **KDE
Plasma**, **Niri** and **Hyprland** — which you pick at the SDDM greeter, plus two
boot-time **specialisations**: `study` for hard-offline work, and `focus` for
Emacs on a machine running almost nothing else. Theming is driven by
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
- A NixOS host. The `nrs`/`nrt`/`nfu` aliases assume the flake is checked out at
  `/home/shaul/nixos-config` (see `myConfig.flakePath` in `flake.nix`); change
  it there if you clone elsewhere. It said
  `/home/shaul/nixOS_config-specializations` — the name of the *branch*, not of
  any directory that has ever existed — so all three aliases resolved to a path
  with no flake in it. `just` was unaffected: it uses `.#desktop` and is only
  ever run from the checkout, which is exactly why nothing caught it.

## Layout

```
flake.nix                     # inputs, myConfig, outputs (host + fmt/check/devShell)
statix.toml                   # what the lint gate checks — and the one it doesn't
.github/workflows/check.yml   # the four gates — see "Continuous integration"
tools/check-closure.sh        # asks the BUILT system whether the docs are true
hosts/desktop/                # host entrypoint + hardware-configuration.nix
home/
  common.nix                  # shell (zsh), git, aliases
  shaul.nix                   # THE home profile — one file, every session
  focus.nix                   # the `focus` profile — Emacs and the search stack
modules/
  system/                     # NixOS modules (core, hardware, dev, services, secrets, ...)
    core.nix                  # the machine: Nix, boot, its name, locale, the user
    network.nix               # NetworkManager, the firewall, sshd — the file `focus` skips
    appearance.nix            # the ONE statement of how this machine looks
    base-tools.nix            # what the MACHINE installs — the repair set, and nothing else
    profile.nix               # the `shaulos.study` flag the home profile reads
    data.nix                  # the one-time ~/Documents bootstrap
    desktop.nix               # X, SDDM, Plasma 6, audio, printing, Bluetooth, KDE Connect, Flatpak
    wayland.nix               # everything a Wayland session needs that isn't a compositor
    niri.nix  hyprland.nix    # the compositors, four lines each
    study-offline.nix         # `study`  — inherits, and forces state off
    focus.nix                 # `focus`  — does not inherit; a smaller import list
  home/                       # home-manager modules
    toolkit.nix               # what YOU install — every program you type, and what study removes
    wayland-common.nix        # bar/launcher/notifier/lock/file-manager for any Wayland session
    lock.nix                  # hyprlock + hypridle, both compositors
    palette.nix               # the stylix scheme, rendered per config-file syntax
    keys.nix                  # the shared keymap + autostart, rendered per compositor
    emacs/default.nix         # packages, daemon, and which module groups load
    niri/  hyprland/          # just the compositor config files
    waybar.nix  yazi.nix  scripts.nix  p10k.nix
    foot.nix  konsole.nix   # the two terminals: compositor sessions, and Plasma
secrets/                      # sops-nix encrypted secrets (see below)
```

The Emacs *configuration* is not in this repo. It lives at
[SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config) and comes in
as a pinned flake input — it is ~3× the size of this whole Nix config, runs on
Windows and macOS as well, and has its own CI. `modules/home/emacs/default.nix`
keeps only what this *machine* provides, and that is four things, not two:

* the package set Emacs shells out to, and `services.emacs`;
* the scaffolding of directories the config expects to exist;
* a generated `99-local-fonts.el`, which is how this display's `uiSize` reaches
  a config that runs on three operating systems and cannot know it;
* **which module groups load** — see [Emacs: only `essentials`
  loads](#emacs-only-essentials-loads) below, because that one is a decision
  with consequences all over this repo rather than a line of wiring.

That list used to read "packages + daemon only", which was true when it was
written and had quietly stopped being true twice over.

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

**`just switch` used to end the niri and Hyprland sessions** (never Plasma), which
looked like a spontaneous reboot because SDDM is `Restart=always` and came
straight back. The systemd user scope those entries get is exactly the reason:
under uwsm the compositor *is* a NixOS-managed user unit, and
`switch-to-configuration` restarts user units whose files changed — where
uwsm's unit graph turns any stop into an irreversible teardown of the whole
session. `modules/system/wayland.nix` now pins those units with
`X-RestartIfChanged=false`, the same measure NixOS applies to
`systemd-user-sessions` for the same reason. New units apply at the next login.

## The two specialisations

| Name    | What it changes                                             |
|---------|-------------------------------------------------------------|
| `study` | NetworkManager, wireless, Bluetooth, sshd and the data bootstrap off; firewall deny-all; no browsers, no downloaders, no creative or media suite |
| `focus` | No Plasma, no SDDM, no X, no compositor, no PipeWire, no printing, no Flatpak, no Bluetooth, no network stack at all, no Baloo, no ollama, no plocate timer. `cage` on tty1 running one Emacs frame |

Pick either in the systemd-boot menu. They are specialisations and the sessions
are not, and the line between them is whether the difference can coexist with
the base system at runtime. "Which compositor" can — that is what a display
manager is for. "The radios are off" cannot, and neither can "Baloo is not
running": on the base system those two plus plasmashell, kwin and SDDM are
about **1.3 GB resident**, to host a 35 MB editor.

They reach for opposite halves of the specialisation module, and that is the
interesting part:

**`study` inherits.** It is this system with the radios off — it wants every
package, every font, all three compositors. It sets `shaulos.study = true`
(declared in `modules/system/profile.nix`), which `modules/home/toolkit.nix`
reads via `osConfig`. That flag exists so there is exactly **one** place that
says which home profile to import: `home-manager.users.<name>` is a submodule,
so a second `imports = [ … ]` inside an inheriting specialisation *merges* with
the parent's rather than replacing it.

**`focus` does not.** It is a *smaller* system, and written as an inheriting
specialisation it would be about fifteen `lib.mkForce false` lines that
silently stop being true the next time `desktop.nix` gains a service — the
`lynx`-in-the-airgap failure one layer down. `inheritParentConfig = false`
makes it a different import list instead: Plasma is absent because nothing
imported `desktop.nix`. That also dissolves the submodule-merge problem
entirely — with no parent definition to merge with, `home/focus.nix` can be a
genuinely different profile and needs no flag.

The catch worth knowing, because it is the failure mode of the whole idea:
"absent because nothing imported it" only holds for options whose default is
off. `networking.useDHCP` defaults to **true** and is not implemented by
NetworkManager, so the first build of `focus` had no NetworkManager and a
`dhcpcd.service` nothing in this repo had ever mentioned. It evaluated, built,
and would have booted; it showed up only in a diff of `etc/systemd/system`
against the parent. `focus` now says `networking.useDHCP = false` out loud.

**Lost your desktop?** Reboot and pick an older generation — systemd-boot keeps
ten (`configurationLimit`). For a guaranteed TTY on any generation, press `e` at
the boot menu and append `systemd.unit=multi-user.target`. That is what the old
`minimal` specialisation was for, minus a whole system closure.

## Where a package goes

An *inheriting* specialisation can only ever **add** — inheriting the parent is
the whole mechanism. So anything in `environment.systemPackages` is present in `study` and
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
font families, `uiSize`, the cursor. Everything else derives from it.

That sentence used to be in this README with `core.nix` in it, and it was only
two-thirds true. The colours and fonts derived; the Qt theme was written out by
hand in `core.nix` *and* in `home/shaul.nix`, three of those statements under
`lib.mkForce`, while `desktop.nix` switched off the stylix target that computes
exactly the same answer from `plasma6.enable`. The cursor was stated three times
in three places, in two different sizes, under a theme name Plasma 6 no longer
ships.

```
modules/system/appearance.nix    stylix.base16Scheme + stylix.fonts + stylix.cursor
        │                        uiSize ──┬── stylix.fonts.sizes
        │                                 └── fonts.fontconfig.localConf
        │                                     (the default for anything that
        │                                     never asked — i.e. Emacs)
        │
        ├── stylix's own targets ──── GTK, foot, waybar base, firefox,
        │                             Qt (→ qt.style/qt.platformTheme → the
        │                             QT_* variables), the pointer
        │                             (→ home.pointerCursor)
        │
        ├── plasma-manager ────────── kdeglobals fonts, konsole's profile
        │                             (neither is a stylix target: targets.kde
        │                             is off, and konsole has none)
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

**To make all text smaller or bigger, change `uiSize` and rebuild.** It is a
size in points, it is at the top of `appearance.nix`, and every surface derives
from it: `uiSize` for Plasma, GTK, dunst and waybar, `uiSize + 1` for both
terminals and for the fontconfig default, `uiSize / 10` for Firefox's
`devPixelsPerPx`. The DPI stays 96 and every scale factor stays 1, so a point is
4/3 of a pixel and nothing multiplies it twice.

Nothing you are looking at changes until you log out. Font sizes are read once,
at process start: after a `just switch` the files on disk are correct and every
program launched before it is still holding the old ones. A six-day uptime means
a six-day-old `kdeglobals` in `plasmashell`, and an Emacs daemon that resolved
fontconfig's default the week before.

That was three separate hardcodes until it wasn't, and none of them were where
you would look for a font size. Emacs got fontconfig's built-in 12.0 — a third
larger than the desktop around it, in the app this machine is mostly for — and
the reason is worth reading twice, because grep gets it wrong. `01-ui.el` in the
emacs-config repo *does* state a size, `:height 90`, inside
`(when (display-graphic-p) …)` evaluated at load time. Under `emacs --fg-daemon`
there is no frame yet, so that is nil, the block never runs, and every
`emacsclient -c` frame falls through to fontconfig. The statement is right there
in the file and has never once executed. Same file also searches for
`"JetBrains Mono"`, with a space, which is not what the Nerd Font patch is
called — so on the frames that *did* run it, Emacs was rendering in DejaVu Sans
Mono while everything else used JetBrainsMono. `modules/home/emacs/default.nix`
now generates a `99-local-fonts.el` into the module tree that sets both from
`uiSize` and hooks `after-make-frame-functions`, which is the half
`display-graphic-p` at load time cannot do. Firefox pinned
`devPixelsPerPx = "1.0"` while everything else ran at
three quarters. And waybar's `font-size: 12px` carried a comment calling it a
deliberate exception for Nerd Font glyphs — but 9pt *is* 12px at 96 DPI, so it
was the derived value in the other unit, pinned by hand and labelled a decision.
Two real exceptions are left, and both are deliberate. Plasma's toolbar font sits
one point below `stylix.fonts.sizes.applications`, which is Plasma's own
convention. And `modules/home/lock.nix` sets the hyprlock clock to
`font_size = 64`, derived from nothing — that one has the paragraph beside it in
the file, and the short version is that a glyph you read at a glance from across
a room is answering a different question from text you read a line at a time at
a desk. Tying them to one variable would mean fixing a cramped panel also
resizes the lock screen.

A third surface was wrong for a subtler reason and is now fixed: waybar derived
its size with `* 4 / 3`, and Nix `/` on two integers is **integer division**, so
`10.667` truncated to `10` and the bar sat ~6% under everything it was supposed
to match. It is `* 4.0 / 3` now. The tell that it is right: stylix independently
emits `* { font-size: 8pt; }` into the same stylesheet, and 8pt at 96 DPI *is*
10.667px — two derivations that never consult each other agreeing to the digit.

A fourth surface turned up after those three were fixed, and it was not a bad
literal — it was no statement at all. `grep -rni konsole` over this repo returned
nothing, and `~/.local/share/konsole/` was empty, while konsole was the terminal
the Plasma session was actually opening. A hardcoded size leaves something to
grep for; an undeclared program leaves nothing, and this one was found by reading
`ps`. It is `modules/home/konsole.nix` now, at the same size foot gets. Note the
`overrideConfig` trap in that file's header: plasma-manager rewrites `konsolerc`
on every activation, so a profile picked in Konsole's settings dialog is reverted
by the next rebuild — the same way the keyboard layout was.

`stylix.targets.kde` is off — Plasma's fonts are written by plasma-manager, but
they are *built* from `stylix.fonts` rather than restated. The three
`stylix.fonts.sizes.*` lines that used to sit in `home/shaul.nix` are gone for
the same reason the Qt variables were: stylix's home-manager integration copies
all four sizes down from the system config with `mkDefault`, so those lines were
shadowing the value they were there to receive.

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
myConfig.keyboard (flake.nix)    layouts + xkb options, list AND joined string
        │
        ├── modules/system/desktop.nix → services.xserver.xkb    (the X server)
        ├── home/shaul.nix             → programs.plasma.input.keyboard (KWin)
        │
modules/home/keys.nix        config.shaulos.keys
        │
        ├── .session ── the shared binds: terminal, launcher, file manager,
        │               Emacs, the scripts from scripts.nix, the volume keys
        ├── .startup ── the shared autostart list
        ├── .keyboard ─ myConfig.keyboard + the repeat rates
        │
        ├── .niri.binds  / .niri.startup  → niri/config.kdl
        ├── .hypr.binds  / .hypr.startup  → hypr/hyprland.conf
        └── the guide                     → ~/.config/shaulos/keys.org
```

**Press `Super+Shift+/` in either session to read the generated guide.**

**Hebrew is on both Shift keys** — hold either, tap the other
(`grp:shifts_toggle`). It used to be `grp:lctrl_lalt_toggle`, sitting on the
Ctrl+Alt that the VT switch is built out of. Both Shifts is the one chord with
nothing else on it, and xkeyboard-config spells it `[Shift_L, ISO_Prev_Group]` /
`[Shift_R, ISO_Next_Group]` — so both keys go on being Shift. The single-key
alternatives (`grp:rctrl_toggle` and friends) *replace* their key's symbols,
which spends a modifier to save a keystroke.

**Caps Lock is Caps Lock.** `caps:escape` used to be set and is deliberately
gone; adding it back is one string in `myConfig.keyboard.options`. It has never
been the Hebrew toggle, whatever the old cheat-sheets claimed.

**Plasma had never been told any of this**, and that is why the keyboard felt
unreliable rather than wrong. KWin does not read `services.xserver.xkb`, and
NixOS does not export `XKB_DEFAULT_*` from it — that is a workaround people add
by hand, precisely because the console and some Wayland compositors ignore the
option. KWin reads `kxkbrc`, and `programs.plasma.overrideConfig = true` means
plasma-manager owns `kxkbrc` outright and resets it on every activation. With no
keyboard declared, the default session fell back to bare `us`: set it in System
Settings and it survived until the next `just switch`.

So the layout and options live in `myConfig` rather than in `keys.nix` — three
consumers in two module systems, and a home-manager module cannot be read from a
NixOS one. `myConfig` renders both spellings, because xkb's own format and the
two compositor configs want a comma-joined string while plasma-manager wants
lists. Nothing downstream reformats a keyboard value, for the same reason nothing
downstream formats a colour.

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
                     #   all three pass --no-update-lock-file; see below
just specialisations # list specialisations available for next boot (`study`, `focus`)
just update          # nix flake update
just update-emacs    # bump the emacs-config input only
just lock            # lock a newly added input, and nothing else
just emacs-dev PATH  # rebuild against a local emacs-config checkout
just bootstrap-data  # fetch ~/Documents from Google Drive + GitHub (idempotent)
just fmt             # nix fmt (nixfmt)
just lint            # statix + deadnix, and nothing else (CI's `lint` job, ~2m)
just eval            # all three of CI's eval steps, build nothing (the fast gate)
just check           # everything CI checks: statix, deadnix, Emacs, the closure
just closure         # build the closure and assert what it claims about itself
just gc              # nix-collect-garbage --delete-older-than 14d
just bundle          # dump all *.nix into combined.txt (e.g. to paste)
```

Shell aliases (from `home/common.nix`): `nrs` (switch), `nrt` (test),
`nfu` (flake update) — these use `myConfig.flakePath` so they work regardless of
the current directory.

`nrs` and `nrt` also carry `--no-update-lock-file`, and for a while they did
not, which made them the one hole in the rule the `justfile` states in bold at
the top. Measured, with `sops-nix` dropped from `flake.lock` — the state this
repo genuinely shipped in once, six inputs declared and four pinned:

| Route | Exit | `flake.lock` |
|---|---|---|
| `just switch` | **1** — `requires lock file changes but they're not allowed` | untouched |
| `nrs`, before the flag | **0** — emitted a system drv | **silently rewritten** |

`nfu` is deliberately without the flag: rewriting the lock is that alias's whole
job, the same exemption `just lock` has.

`nix develop` provides a dev shell with `nixfmt`, `statix`, `deadnix`,
`nil`, `just`, `nh`, plus `sops`/`age`/`ssh-to-age` for the secrets walkthrough
below.

## Continuous integration

`.github/workflows/check.yml` runs four gates on every push, cheapest first.
Each one is strictly stronger than the last, and all four run the same
commands you can run by hand:

| Gate | ~ | What it proves | By hand |
|---|---|---|---|
| `lock` | 1m | `flake.lock` accounts for every input in `flake.nix` | `nix flake metadata --no-update-lock-file` |
| `lint` | 2m | statix and deadnix are clean | `just lint` |
| `eval` | 5m | the whole module system evaluates, and `study` and `focus` are the only specialisations | `just eval` |
| `build` | 40m | the closure builds, and is the machine this README describes | `just closure` |

Two of those rows used to be wrong, and both were wrong in the same direction —
they claimed a local command was equivalent to a CI job when it was not:

* `lint` offered **`just check`**, which is `nix flake check` — *all four*
  checks including the 40-minute closure build. A two-minute gate documented as
  a forty-minute one is a gate you stop running. `just lint` now exists and is
  exactly the two `nix build` invocations CI's `lint` job runs.
* `eval` offered **`just eval`**, which ran only the first of that job's three
  steps. Proven by construction rather than argued: deleting the entire
  `specialisation.focus` block from `hosts/desktop/configuration.nix` left
  `just eval` **green** — it printed a drvPath and noticed nothing — while CI
  went red. The config could silently lose a whole specialisation and the
  documented local gate passed. `just eval` now runs all three steps.

The fix was to make the commands true rather than to soften the claim, which is
the same move the rest of this file argues for: a document that describes a
weaker check is a document you have to remember to distrust.

`lint`, `eval` and `build` all `needs: lock`, so an unlocked input is **one**
red job and three skipped ones rather than four identical failures with the
cause buried in each.

**Why this exists.** These checks — most of them — were already in `flake.nix`,
and nothing ran them. That is the same shape as the finding that split the Emacs
config out of this repo: `tools/verify.sh` byte-compiled every module and was
wired to nothing, so 1,569 lines silently stopped loading and no build ever went
red. The Emacs half got a CI job out of that. This half did not, and it is the
half authored on a Windows box with no Nix on it. The bill was sitting in the
tree: `flake.nix` declared six inputs, `flake.lock` pinned four, and the repo as
committed did not evaluate at all.

**`--no-update-lock-file` is on every invocation, in CI and in the `justfile`.**
One rule: *nothing changes `flake.lock` except `just lock`.* Without the flag,
nix resolves an unpinned input, writes the entry and carries on — so a green run
says nothing about the inputs you are going to build, and `just switch` puts you
on a system that is not the one you committed. With it, an input the lock does
not pin is an error, in CI and on the machine alike.

**What CI cannot tell you** is whether the system *switches*. It builds the
closure; activation, the greeter, and everything that only happens on real
hardware are still yours. `just switch` is still a thing you do with a boot menu
in reach.

**Deliberately not a gate: formatting.** Nothing this config has ever suffered
was a formatting problem, and a check that goes red for cosmetics is a check
people learn to scroll past. `just fmt` stays a thing you run.

### `tools/check-closure.sh`

The `build` gate does not stop at "it built". It reads the result and asks
whether the claims in this README are true of it:

- no browser is in `environment.systemPackages`, in **either** closure — the
  rule `base-tools.nix` states, and the exact way `firefox` and `lynx` got into
  the airgap the first time;
- `study` has no browser and no downloader in the home profile at all;
- `study` still has the search tools, the file managers, the editors, the
  document toolchain, the compilers and a local media player — one binary per
  clause of the sentence three sections up;
- **`study`'s daemons are actually off** — NetworkManager, wpa_supplicant,
  ModemManager, sshd, Bluetooth and both data-bootstrap units absent, anchored
  against a present-test for the desktop it still inherits. `study`'s whole
  claim is a *process* claim and for a long time this script checked only its
  packages;
- **no `dhcpcd.service`, in `study` or `focus`.** Both closures can generate one
  the same way — `networking.useDHCP` defaults to *true* and is implemented by
  the base networking module, not by NetworkManager — and for a long time only
  `focus` was asserted. The airgap took a lease on every wired link;
- **the seforim stack and `EMACS_MODULE_GROUPS` agree** — with `essentials`
  alone, nothing whose only caller lives in `extras/` may be in any profile.

Every "is X absent" test is paired with an "is Y present" test in the same
directory, and a missing directory is a hard failure rather than a pass. An
absence test that cannot tell *absent* from *I was looking in the wrong place*
goes green forever and tells you nothing, which is the failure mode this entire
pass exists to kill.

The last two bullets are the presence-test mirror of that, and they were added
because the script had been going green on both. It asserted `recoll` was in
`focus`'s profile — it was — while the Emacs in that closure could not run a
single `seforim-` command. A binary being installed says nothing about anything
being able to reach it.

**A disabled unit is not an absent one.** `systemd.services.<n>.enable = false`
does not omit the unit: nixpkgs' `makeUnit` emits `ln -s /dev/null` instead,
which is systemd's masking convention, and `[ -e ]` follows that symlink and
reports the unit as present. So the script tests *not running* rather than
*absent*, and accepts either form — genuinely absent, because the generating
module went inert, or masked by name. Both are live in this repo and they are
not interchangeable: `study`'s radios are absent, its two `shaulos-data-bootstrap`
units are masked.

The script has itself been mutation-tested — a fixture closure, seventeen
one-at-a-time regressions, each required to turn it red. That is not ceremony:
a check made entirely of absence assertions is worth exactly as much as the
number of times it has been seen to fail. It found one gap that way, and
CHANGES.md entry (s) records which.

## Secrets (sops-nix)

Encrypted secrets live in `secrets/secrets.yaml` and are safe to commit **once
encrypted** — sops keeps values encrypted with keys in plaintext. The module
`modules/system/secrets.nix` stays inert until `secrets.yaml` exists.

### It is inert right now, on purpose, and that needs defending

Stated plainly, because the current state is easy to mistake for an oversight:

* `.sops.yaml` still contains the literal placeholder
  `age1REPLACE_WITH_YOUR_HOST_AGE_PUBLIC_KEY`;
* `secrets/secrets.yaml` does not exist;
* every `sops.secrets."…"` block in `modules/system/secrets.nix` is commented
  out.

So the input, the module, this section and the `secrets/README.md` walkthrough
are all live, and **nothing uses them**. The branch is even named `sops`.

That is a real tension with this repo's own rules, and it deserves naming rather
than hoping nobody checks. `flake.nix:8-17` deletes `nixpkgs-unstable` with the
argument that it is *"a second fetch, a second lock entry and a second full
evaluation on every rebuild, bought for zero call sites"*, and
`modules/system/data.nix` deletes `services.onedrive` for being *"a knob with no
call sites and no history of changing… not a requirement, a hedge."* sops-nix is
a fetch, a lock entry and a NixOS module import whose only call sites are
comments. By the letter of both rules it should go.

**It stays, and the chiluk is the cost of getting it back.** `nixpkgs-unstable`
and `onedrive` were each one line to re-add on the day they were wanted. sops-nix
is not: the walkthrough below is host-key derivation, a re-key, and a
`.sops.yaml` edit that you do *on the machine*, and the moment you want it is
the moment you are holding a credential and least want to be reading setup
docs. The thing being paid for is not the module — it is the walkthrough being
correct and in the tree when it is needed.

What it costs today, measured rather than waved at: one flake input, one lock
entry, one module import that evaluates to nothing. No unit, no package, no
activation step.

**What would change the verdict.** If the `rclone.conf` route below is still
unexercised the next time this repo is audited, that is no longer a hedge with a
justification — it is a walkthrough nobody has ever run, which is a different
and worse thing, because an untested walkthrough fails exactly when you are
depending on it. Either run it or drop the input.

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
not for the directory: `modules/home/emacs/default.nix` used to create
`~/Documents/seforim/Bavli` during home-manager activation, so a directory test
was always true and the seforim library never downloaded. Both halves of that
are closed now — the predicate asks about files, *and* the `mkdir` that made the
lie possible is commented out with the rest of the seforim scaffolding (see
[Emacs: only `essentials` loads](#emacs-only-essentials-loads)). Belt and
braces, rather than one fix and one landmine.

The seforim library itself still downloads, and that is a deliberate line: it is
*data*, not machinery for code that no longer loads, and the texts are readable
without Emacs.

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

### Emacs: only `essentials` loads

The `emacs-config` repo ships two module groups. `essentials/` is a general
Emacs configuration that knows nothing about Hebrew or seforim; `extras/` is the
personal half that layers on top of it. Its `init.el` defaults to **both** and
reads `EMACS_MODULE_GROUPS` to be told otherwise.

This machine says `essentials`, in `modules/home/emacs/default.nix`, in both
places that matter — `home.sessionVariables` for anything launched from a shell,
and `systemd.user.sessionVariables` for `emacs.service`, which is what `$EDITOR`
resolves to. Setting only the first would leave every `emacsclient` frame
loading a different config from a standalone `emacs`.

**What that costs, because it is not small:**

| group | modules | lines | loaded |
|---|---|---|---|
| `essentials` | 25 | 2,379 | yes |
| `extras` | 15 | **3,165** | **no** |

`extras/` is 57% of the configuration: all 89 `seforim-*` functions, 31 of them
interactive commands, and the entire Hebrew and RTL layer. It is still copied
into the Nix store and symlinked into `~/.config/emacs/modules`. It is simply
not loaded.

**And everything that existed to serve it is switched off with it.** That is the
rule, and it is deliberately stronger than "leave a comment":

> Machinery that exists to serve code which does not load gets switched off in
> the same commit — commented out with the reason beside it, not annotated and
> left running.

| Where | What is commented out |
|---|---|
| `modules/system/services.nix` | the four-hourly `recollindex` service + timer |
| `modules/home/emacs/default.nix` | `~/.recoll/recoll.conf`, `hdate`, the `~/.cache/emacs/seforim` and `~/Documents/seforim/Bavli` scaffolding |
| `modules/home/toolkit.nix` | `recoll`, `xapian` |
| `home/focus.nix` | `recoll`, `xapian` |

`poppler-utils` stays — `essentials/11-pdf.org` probes `pdfinfo` and Org export
shells out to `pdftotext`, so it is not a seforim package; it was merely listed
beside one. **The seforim library still downloads**, because that is data rather
than machinery and the texts are readable without Emacs.

`tools/check-closure.sh` asserts the agreement, so this cannot drift again: with
`essentials` alone, nothing whose only caller is `extras/` may be in any
profile, anchored by a present-test on `pdftotext`.

**To turn it back on:** set `EMACS_MODULE_GROUPS = "essentials extras"` (or drop
the line and take `init.el`'s default), then uncomment the blocks in the table
above — the closure check will name every one of them for you. For a single
session instead, leave the config alone:

```sh
EMACS_MODULE_GROUPS="essentials extras" emacs
systemctl --user set-environment EMACS_MODULE_GROUPS="essentials extras"
systemctl --user restart emacs.service
```

> **One thing worth knowing before you re-enable the indexer.** The four-hourly
> `recollindex` was never the index the seforim search read, in any
> configuration. `extras/15-seforim-dream.org` keeps a *private* recoll config
> directory at `~/.cache/emacs/seforim/recoll` and queries that, explicitly so
> it "never touches a system-wide recoll setup". The timer ran `recollindex`
> with no `-c`, building a second index over the same corpus that nothing has
> ever opened. `M-x seforim-recoll-index` is what maintains the real one — so
> turning `extras` back on is not a reason to uncomment that timer.

See `CHANGES.md` for the last overhaul and its post-install checklist.
