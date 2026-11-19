# ShaulOS — NixOS configuration

[![check](https://github.com/SYKhayyat/nixOS_config/actions/workflows/check.yml/badge.svg)](https://github.com/SYKhayyat/nixOS_config/actions/workflows/check.yml)

A single-host NixOS flake for the machine `desktop` (`nixosConfigurations.desktop`,
`x86_64-linux`). One system closure offers three graphical sessions — **KDE
Plasma**, **Hyprland** and **Sway** — which you pick at the SDDM greeter, plus two
boot-time **specialisations**: `study` for hard-offline work, and `focus` for
Emacs on a machine running almost nothing else. Theming is driven by
[stylix](https://github.com/nix-community/stylix), Plasma by
[plasma-manager](https://github.com/nix-community/plasma-manager), the user
environment by [home-manager](https://github.com/nix-community/home-manager),
and secrets by [sops-nix](https://github.com/Mic92/sops-nix).

**New here?** [`docs/ONBOARDING.md`](docs/ONBOARDING.md) — what this builds, how to
rebuild safely, the three rules, and what each design decision cost.
**Something broken?** [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) —
symptom-first, starting with "I lost my desktop".

## Requirements

- Nix with **flakes** and `nix-command` enabled
  (`experimental-features = nix-command flakes`).
- Pinned to **NixOS 26.05 "Yarara"** (`nixos-26.05`, `home-manager`
  `release-26.05`, `stylix` `release-26.05`). Exactly one nixpkgs is *imported*:
  `pkgs` is 26.05 for the formatter, the dev shell, the system and every home
  module. `nixpkgs-unstable` also exists as an input, and only as the source of
  two overlay packages 26.05 is behind on — `darktable` 5.6.1 and `rapidraw`
  1.6.4. There is no `unstable` argument anywhere; naming the input is the only
  way to reach it.
- The Nix implementation is **Lix** (`nix.package = pkgs.lixPackageSets.stable.lix`).
- A NixOS host. The `nrs`/`nrt`/`nfu` aliases assume the flake is checked out at
  `/home/shaul/config` (see `myConfig.flakePath` in `flake.nix`); change it
  there if you clone elsewhere. That value has been wrong twice in the same way,
  which is why the sentence is worth reading rather than skimming: it said
  `/home/shaul/nixOS_config-specializations` — the name of the *branch*, not of
  any directory that has ever existed — and was then "corrected" to
  `/home/shaul/nixos-config`, a directory that also does not exist. Both times
  all three aliases resolved to a path with no flake in it. `just` was
  unaffected: it uses `.#desktop` and is only ever run from the checkout, which
  is exactly why nothing caught it either time.

## Layout

```
flake.nix                     # inputs, myConfig, outputs (host + fmt/check/devShell)
statix.toml                   # what the lint gate checks — and the one it doesn't
.github/workflows/check.yml   # the four gates — see "Continuous integration"
tools/check-closure.sh        # asks the BUILT system whether the docs are true
tools/check-docs.sh           # asks the SOURCE whether the docs name files that exist
hosts/desktop/                # host entrypoint + hardware-configuration.nix
home/
  common.nix                  # shell (zsh), git, aliases
  shaul.nix                   # THE home profile — one file, every session
  focus.nix                   # the `focus` profile — Emacs and the search stack
modules/
  system/                     # NixOS modules
    core.nix                  # the machine: Nix, boot, its name, locale, the user
    hardware.nix              # firmware, graphics, zram, /tmp, TLP, /dev/uinput
    network.nix               # NetworkManager, DNS, the firewall, sshd — the file `focus` skips
    appearance.nix            # the ONE statement of how this machine looks
    base-tools.nix            # what the MACHINE installs — the repair set, and nothing else
    development.nix           # nix-ld (steam-run's library set) and direnv
    services.nix              # ollama, and the plocate timer
    secrets.nix               # sops-nix rendering (inert until secrets/secrets.yaml exists)
    profile.nix               # the `shaulos.study` flag the home profile reads
    data.nix                  # the one-time ~/Documents bootstrap
    desktop.nix               # X, SDDM, Plasma 6, audio, printing, Bluetooth, KDE Connect, Flatpak
    wayland.nix               # everything a Wayland session needs that isn't a compositor
    hyprland.nix  sway.nix    # the two tiling compositors
    study-offline.nix         # `study`  — inherits, and forces state off
    focus.nix                 # `focus`  — does not inherit; a smaller import list
  home/                       # home-manager modules
    toolkit.nix               # what YOU install — every program you type, and what study removes
    wayland-common.nix        # bar/launcher/notifier/lock/file-manager for any Wayland session
    lock.nix                  # hyprlock + hypridle, both compositors
    palette.nix               # the stylix scheme, rendered per config-file syntax
    keys.nix                  # the shared keymap + autostart, rendered per compositor
    emacs.nix                 # the package, the profile launchers, the shell-outs
    hyprland/  sway/          # just the compositor config files
    darktable.nix             # darktable LUTs/styles/lua
    raw-editor-sources.nix    # the pinned D7200 DCP, and its ICC for darktable
    art.nix                   # ART profiles/LUTs, from the same shared sources
    lisp.nix                  # ~/.sbclrc, so `ql:quickload` works at the prompt
    waybar.nix  yazi.nix  scripts.nix  p10k.nix
    foot.nix  konsole.nix   # the two terminals: compositor sessions, and Plasma
secrets/                      # sops-nix encrypted secrets (see below)
assets/wallpaper.jpg          # the one image stylix and the compositors share
```

The Emacs *configuration* is not in this repo, but it is pinned by it: flake
input `emacsConfigs` (`github:SYKhayyat/emacs-configs`), three profiles
(`hebrew`, `notes`, `ide`) and the lisp they load. The store copy cannot be what
Emacs runs from — `package.el` writes `elpa/`, Emacs writes `state/` and each
profile's `eln-cache/` — so `modules/home/emacs.nix` builds a writable
`~/.local/share/emacs-configs` out of links to it plus two real directories, and
the launchers point `EMACS_CONFIG_ROOT` there.

`modules/home/emacs.nix` keeps only what this *machine* provides: one
Emacs (`pkgs.emacs-pgtk`, the Wayland build), the three profile launchers as
store wrappers, `$EDITOR` pointing at the notes one, and three desktop entries.
The launcher starts each profile's daemon; nothing here declares those as
systemd units, on purpose — three daemons at login is 150–400 MB for profiles
you might not open.

**Reproducibility trade, stated:** the config's *lisp* is pinned with the rest
of the flake, but `elpa/` is not — packages are fetched from ELPA and MELPA by
`emacs-install`, so `nixos-rebuild --rollback` does not roll Emacs packages back
and a MELPA change can arrive with no Nix change. That is the cost of a config
that also runs on macOS and Windows.

## Sessions

Pick these at the SDDM greeter — one system closure has all three, and SDDM
remembers the last one you used:

| Session          | Config                                          |
|------------------|-------------------------------------------------|
| **Plasma**       | `plasma-manager` in `home/shaul.nix` (default)  |
| **Hyprland (uwsm)** | `modules/home/hyprland/default.nix`          |
| **Sway (uwsm)**  | `modules/home/sway/default.nix`                 |

Prefer the `(uwsm)` entries for the tiling compositors: they get a proper
systemd user scope and working portals. Nothing needs a rebuild or a reboot to
switch — log out, pick another.

**`just switch` used to end the Hyprland and sway sessions** (never Plasma), which
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
| `study` | NetworkManager, wireless, Bluetooth and the data bootstrap off; firewall deny-all; no browsers, no downloaders, no creative or media suite |
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
package, every font, both tiling compositors. It sets `shaulos.study = true`
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

That is not a style point. `programs.firefox.enable = true` used to live in the
module now called `modules/system/base-tools.nix` (then `cli-tools.nix`), and
`study-offline.nix` carried a `mkForce
false` to undo it. `lynx` sat two words away on line 31 of the same file and got
no such line — so *"offline airgap, no browsers"* shipped with a browser on
`$PATH`. Fixing the package rather than the drawer leaves the drawer.

So there is a rule now, and the two files that state it are
`modules/system/base-tools.nix` and `modules/home/toolkit.nix`:

| Where | What belongs there |
|---|---|
| `environment.systemPackages` (`base-tools.nix`) | Only what must work when home-manager is **broken, absent, or not yours**: `git`, `vim`, `curl`, `wget`, `htop`, `tree`, `unzip`/`zip`, plus `nh` and `home-manager` — the tools you repair a bad generation with, in a TTY, possibly *because* the home profile is what failed. Nothing else. |
| `home.packages` (`toolkit.nix`) | Everything a person types. This is where `study` can reach it. |
| `home.packages` (the owning module) | A package that exists because one module needs it: the session stack in `wayland-common.nix`, Emacs's shell-outs in `emacs.nix`, the shell in `home/common.nix`. The test is *"would you still want it if you uninstalled Emacs?"* — if yes, it is a tool and it belongs in `toolkit.nix`. |
| nowhere | A program a script calls by store path (`${pkgs.grim}/bin/grim`) is in the closure already. List it only if you also want to type its name. `polkit_gnome` is the clean case: `keys.nix` starts the agent by path, and nobody ever runs it by name. |

**And a package is declared exactly once.** Thirteen were not — `fd`, `ripgrep`,
`ripgrep-all`, `plocate`, `pandoc`, `fzf`, `jq`, `libsecret`,
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
                                            ├── .css    "#rrggbb"       → waybar
                                            ├── .hypr   "rgb(rrggbb)"   → hyprland.conf, hyprlock.conf
                                            ├── .font   mono/sans/sizes → waybar, hyprlock, Plasma
                                            └── .cursor name/size       → Plasma, hyprland.conf
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
the same name and size to plasma-manager and to `hyprland.conf`. Before, those
disagreed — 24 and unset — and the one that named a theme named `Breeze_Snow`,
which KDE renamed to `Breeze_Light` for Plasma 6, so Plasma had been silently
falling back to the default pointer.

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
you would look for a font size. Emacs used to get fontconfig's built-in 12.0, and
the old Nix-side fix (a generated `99-local-fonts.el`) went away with the old
config: `~/emacs-configs` owns its fonts now, on all three of its platforms.
Firefox pinned `devPixelsPerPx = "1.0"` while everything else ran at three
quarters. And waybar's `font-size: 12px` carried a comment calling it a
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
        ├── .hypr.binds  / .hypr.startup  → hypr/hyprland.conf
        ├── .sway.binds  / .sway.startup  → sway/config
        └── the guide                     → ~/.config/shaulos/keys.org
```

**Press `Super+Shift+/` in either session to read the generated guide**, or
**`Super+F1` for a searchable list of the same keys** — `fuzzel` in dmenu mode,
type to filter, Esc to close. `Super+F1` also works under Plasma, through a KDE
global shortcut, because Plasma reads neither compositor's config.

Both renderings are generated from this file and from each compositor's
registered binds, so neither can describe a key the config does not have. The
list carries two sections that are *not* generated and say so: the machine's own
keys (`Ctrl+Alt+F1`, `Ctrl+Alt+Delete`), and each application's defaults (Emacs,
foot, fuzzel, yazi) — those belong to the app, and writing them down once behind
that header is the most a generated list can honestly claim about them.

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
bind that names a *compositor verb* — `bindsym` in sway, `layoutmsg, swapnext`
in Hyprland — lives in that compositor's own module, because the two layouts
behave differently and no abstraction should pretend otherwise.

This replaced hand-written copies of one keymap, each with a `guide.org`
cheat-sheet beside it, of which most were wrong. `Super+E`, `Super+Shift+E` and
`Super+1..5` existed in only one config; a cheat-sheet documented resize on
`Super+Ctrl` (it is `Super+Alt`) and listed a three-bind dwindle section the
config has never had.

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
just update-opencode # bump opencode and freebuff from the llm-agents input
just update-omnirush # bump the OmniRush CLI and app (also done by every rebuild)
just omnirush-check  # what that bump would do, writing nothing
just lock            # lock a newly added input, and nothing else
just bootstrap-data  # fetch ~/Documents from Google Drive + GitHub (idempotent)
just fmt             # nix fmt (nixfmt)
just lint            # statix, deadnix, and the docs check (CI's `lint` job, ~2m)
just eval            # all three of CI's eval steps, build nothing (the fast gate)
just check           # everything CI checks: statix, deadnix, the closure
just closure         # build the closure and assert what it claims about itself
just gc              # nix-collect-garbage --delete-older-than 14d
just bundle          # dump all *.nix into combined.txt (e.g. to paste)
```

`just switch`, `just test` and `just build` each refresh the two OmniRush pins
before they rebuild, and so do `nrs` and `nrt`. That is what "always on the
latest" can mean here: a pure flake cannot resolve a moving target at eval
time, so the rebuild command moves the pin instead — the version still lands in
this repo and shows up in `git diff`, and `nixos-rebuild rollback` still
returns to a known-good build.

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
| `lint` | 2m | statix and deadnix are clean, and every path a live document names exists | `just lint` |
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
config out of this repo: a `verify.sh` in the Emacs repo byte-compiled every
module and was wired to nothing, so 1,569 lines silently stopped loading and no
build ever went red. The Emacs half got a CI job out of that. This half did not, and it is the
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
  ModemManager, Bluetooth and both data-bootstrap units absent, anchored
  against a present-test for the desktop it still inherits. `study`'s whole
  claim is a *process* claim and for a long time this script checked only its
  packages;
- **no `dhcpcd.service`, in `study` or `focus`.** Both closures can generate one
  the same way — `networking.useDHCP` defaults to *true* and is implemented by
  the base networking module, not by NetworkManager — and for a long time only
  `focus` was asserted. The airgap took a lease on every wired link.

Every "is X absent" test is paired with an "is Y present" test in the same
directory, and a missing directory is a hard failure rather than a pass. An
absence test that cannot tell *absent* from *I was looking in the wrong place*
goes green forever and tells you nothing, which is the failure mode this entire
pass exists to kill.

**A disabled unit is not an absent one, and it is two hops from `/dev/null`.**
`systemd.services.<n>.enable = false` does not omit the unit. nixpkgs'
`makeUnit` builds a store path named `unit-<name>-disabled` and puts systemd's
masking symlink *inside* it, so the closure holds:

```
/etc/systemd/system/<name>
  -> /nix/store/…-unit-<name>-disabled/<name>
       -> /dev/null
```

`[ -e ]` resolves all of that, finds `/dev/null` and calls the unit present. So
the script tests *not running* rather than *absent*, resolving the full chain
with `readlink -f`, and accepts either form — genuinely absent because the
generating module went inert, or masked by name. Both are live here and they are
not interchangeable: `study`'s radios are absent, its two
`shaulos-data-bootstrap` units are masked.

The script has itself been mutation-tested — a fixture closure, nineteen
one-at-a-time regressions, each required to turn it red. That is not ceremony: a
check made entirely of absence assertions is worth exactly as much as the number
of times it has been seen to fail.

**And the mutation suite is not sufficient either**, which is the more useful
half. It went green while both the checker and the fixture shared one wrong
belief — that masking was a single `ln -s /dev/null` — so the fixture confirmed
the assumption instead of testing it, and the airgap's two masked units were
being reported as live. Nothing caught that except building the closure and
asking the artifact. If you take one thing from this section: a test written by
whoever wrote the code agrees with the code, and the `build` gate is what
disagrees. CHANGES.md entry (s) has the full account.

### `tools/check-docs.sh`

The same question at the other end: `check-closure.sh` asks the artifact whether
the docs are true; this asks the source whether the docs name files that exist.
It reads only live documents — this file, `docs/*` minus the dated audit, and
`secrets/README.md` — and only paths that start at a top-level directory, plus
relative links, because a bare `core.nix` in a sentence is a basename rather
than a claim about a location.

It exists because this pass found README pointing at the old name of
`modules/system/base-tools.nix` months after the rename, and three documents
describing a sops setup that had gone live. Both were sentences, not
code. It cannot tell whether a sentence is *true* — only that the file it names
is there — and that is the honest size of the claim.

## Secrets (sops-nix)

Encrypted secrets live in `secrets/secrets.yaml` and are safe to commit **once
encrypted** — sops keeps values encrypted with keys in plaintext. The module
`modules/system/secrets.nix` stays inert until `secrets.yaml` exists.

### What is live, and what is still a comment

The module stopped being inert on 2026-11-18, and this section said otherwise for
long enough that the difference is worth stating as state rather than argument:

* `.sops.yaml` carries the host's real age public key (`age1jcak…`), derived from
  `/etc/ssh/ssh_host_ed25519_key`;
* `secrets/secrets.yaml` exists, and holds one encrypted value,
  `nix-access-tokens`;
* `modules/system/secrets.nix` renders that value to `/etc/nix/tokens.conf`,
  which `modules/system/core.nix` `!include`s — so the GitHub token that used to
  be a manual step is supplied at activation;
* the `rclone.conf` secret is still commented out, which is why the data
  bootstrap still asks you to run `rclone config` once.

Check the live half after a switch, because a missing age key at
`/var/lib/sops-nix/key.txt` turns into a missing file rather than a build error:

```sh
ls -l /run/secrets/nix-access-tokens
```

**`rclone.conf` is the remaining hook.** The walkthrough below is written for
it, and it is what makes the data bootstrap reproducible on a fresh machine
instead of a manual `rclone config` in a terminal. If it is still unexercised at
the next audit, that is no longer a hedge with a justification — it is a
walkthrough nobody has ever run, which fails exactly when you are depending on
it. Either run it or drop it.

One-time setup on the machine (full walkthrough in `secrets/README.md`):

1. Derive an age key from the host SSH key so the box can decrypt at boot with no
   extra secret material, and print the matching public key:
   ```sh
   sudo mkdir -p /var/lib/sops-nix
   sudo sh -c 'ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /var/lib/sops-nix/key.txt'
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Put that `age1…` public key in `.sops.yaml` — already done on this machine;
   it is one line per host if there is ever a second one.
3. Edit the encrypted file with `sops secrets/secrets.yaml`, add or uncomment the
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
not for the directory: the old Emacs scaffolding created
`~/Documents/seforim/Bavli` during home-manager activation, so a directory test
was always true and the seforim library never downloaded. The predicate asks
about files now, and the `mkdir` that made the lie possible is gone with the
old Emacs module.

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

Flake input `emacsConfigs` is the configuration: three profiles (`hebrew`,
`notes`, `ide`), the lisp they load, and `vendor/`. It is pinned in
`flake.lock`, so a machine with nothing in `$HOME` builds a working Emacs.

A store path cannot be what Emacs runs from. `package.el` writes `elpa/`, Emacs
writes `state/` (recentf, savehist, custom.el) and each profile's `eln-cache/`,
and the store is read-only. So `modules/home/emacs.nix` builds
`~/.local/share/emacs-configs` — links to the read-only half, real directories
for `elpa/` and `state/` — and `emacsLauncher` in `flake.nix` makes
`emacs-hebrew`/`emacs-notes`/`emacs-ide` store wrappers that `sh` the pinned
`launch.sh` with `EMACS_CONFIG_ROOT` set to it. `$EDITOR` and `$VISUAL` are the
notes wrapper, and three desktop entries name the same paths. `launch.sh
<profile>` starts that profile's daemon if it is not running; the daemons are
deliberately not systemd units, so they cost nothing until you open the profile
you want.

Update the configuration by pushing to that repository, then `just lock` and
`just switch`. `emacs-install` refills `elpa/` from `lisp/packages.el`;
activation runs it once when `elpa/` is empty (a new machine, or the first
switch after the input changed), because `package-refresh-contents` is a network
round trip and not something to do on every switch.

The wrappers are built rather than named as paths into a checkout because an
executable bit in another repository is not something this one can check. It has
already cost every entry point at once: `launch.sh` was committed `100644`, so a
fresh checkout made every caller fail with `Permission denied` and no gate here
could see it. A store path is `0555` by construction, and `sh` reads the
script instead of exec'ing it, so the bit stops mattering.

The wrapper also puts its own dependencies on `PATH` — `emacs`, `emacsclient`
and coreutils, all of which `launch.sh` calls by bare name — rather than
inheriting whatever it was started with, because one of its callers has almost
no `PATH` at all: the `focus` session's `cage` service runs under systemd with
coreutils, grep, sed and systemd, and nothing else. That is where the
specialisation's Emacs comes from, and which Emacs it is.

For the `study` airgap, run `emacs-install` and warm each profile before
switching in — `elpa/` is not fetched offline.

The old Nix-side Emacs config (the `emacs-config`/Doom inputs, the module groups,
texlive, the single daemon, `migrateEmacsModules`) was deleted on 2026-11-18.
The only trace left is in `CHANGES.md`; the machine no longer builds a second
Emacs toolchain.
