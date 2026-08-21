# Onboarding

What this repository is, how to work on it safely, and the handful of rules
that account for most of what would otherwise surprise you.

Twenty minutes. §4 is the one to read carefully — it is where the design
decisions are, and every one of them exists because something went wrong first.

| You want to | Go to |
|---|---|
| Understand what this builds | [§1](#1-what-this-is) |
| Get set up and rebuild | [§2](#2-set-up-and-rebuild) |
| Know the rules before changing anything | [§3](#3-three-rules) |
| Understand the design | [§4](#4-the-design-and-what-each-decision-cost) |
| Add a package or a service | [§5](#5-making-a-change) |
| Fix something broken | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

---

## 1. What this is

A **single-host NixOS flake** for the machine `desktop`
(`nixosConfigurations.desktop`, `x86_64-linux`).

One system closure offers:

- **three graphical sessions** — KDE Plasma, Niri, Hyprland — picked at the SDDM
  greeter;
- **two boot-time specialisations** — `study` for hard-offline work, and `focus`
  for Emacs on a machine running almost nothing else.

Theming is [stylix](https://github.com/nix-community/stylix), Plasma is
[plasma-manager](https://github.com/nix-community/plasma-manager), the user
environment is [home-manager](https://github.com/nix-community/home-manager),
secrets are [sops-nix](https://github.com/Mic92/sops-nix) — currently inert, and
the README defends that at length.

### What you need

- Nix with **flakes** and `nix-command` enabled.
- Pinned to **NixOS 26.05 "Yarara"** — `nixos-26.05`, home-manager
  `release-26.05`, stylix `release-26.05`. **One nixpkgs.**
- The Nix implementation is **Lix**
  (`nix.package = pkgs.lixPackageSets.stable.lix`).
- A NixOS host.

### The layout

```
flake.nix                     inputs, myConfig, outputs (host + fmt/check/devShell)
statix.toml                   what the lint gate checks — and the one it doesn't
.github/workflows/check.yml   the four gates
tools/check-closure.sh        asks the BUILT system whether the docs are true
hosts/desktop/                host entrypoint + hardware-configuration.nix
home/                         common.nix, shaul.nix, focus.nix
modules/system/  modules/home/
justfile                      every real command, wrapped
```

## 2. Set up and rebuild

Clone it, then **set the path**:

```nix
# flake.nix
myConfig.flakePath = "/home/shaul/nixos-config";   # change if you clone elsewhere
```

`nrs`, `nrt` and `nfu` — the shell aliases from `home/common.nix` — resolve
through that value, so they work regardless of the current directory. `just`
does not use it; it uses `.#desktop` and is only ever run from the checkout.

That asymmetry is worth knowing on day one, because it hid a bug: the value was
once `/home/shaul/nixOS_config-specializations` — the name of the **branch**, not
of any directory that has ever existed — so all three aliases resolved to a path
with no flake in it, and `just` never noticed.

### The commands, cheapest first

```sh
just eval            # all three of CI's eval steps, build nothing — the fast gate
just lint            # statix + deadnix (~2m)
just build           # build only, no activation
just test            # activate without writing a boot entry
just switch          # the real thing
just closure         # build and assert what the closure claims about itself (~40m)
just check           # everything CI checks
```

`just` or `just --list` shows them all. The `justfile` wraps the real
`nixos-rebuild` / `nix` invocations so there is one place they are spelled.

**Use `just test` when you are unsure.** It activates without a boot entry, so a
reboot gets you back.

**Keep a boot menu in reach for `just switch`.** CI proves the closure *builds*;
activation, the greeter and everything that only happens on real hardware are
still yours.

### If you lose the desktop

Reboot, pick an older generation — systemd-boot keeps ten. For a guaranteed TTY
on any generation, press `e` at the boot menu and append
`systemd.unit=multi-user.target`.

## 3. Three rules

### 1. Nothing changes `flake.lock` except `just lock`

`--no-update-lock-file` is on **every** invocation, in CI and in the `justfile`.

Without it, nix resolves an unpinned input, writes the entry and carries on — so
a green run says nothing about the inputs you are going to build, and `just
switch` puts you on a system that is not the one you committed. With it, an
input the lock does not pin is an **error**, in CI and on the machine alike.

The exemptions are `just lock` and `nfu`, whose whole job is rewriting the lock.

This repository shipped once with six inputs declared and four pinned, and did
not evaluate at all.

### 2. The documented local command must be the CI job

Not "roughly equivalent to". Two rows of the CI table were once false in the
same direction, and both are instructive:

- `lint` offered `just check`, which is `nix flake check` — *all four* checks
  including the 40-minute closure build. **A two-minute gate documented as a
  forty-minute one is a gate you stop running.**
- `eval` offered a `just eval` that ran only the first of that job's three
  steps. Proven by construction: deleting the entire `specialisation.focus`
  block left `just eval` **green** while CI went red. The config could silently
  lose a whole specialisation and the documented local gate passed.

The fix was to **make the commands true rather than to soften the claim.** A
document that describes a weaker check is a document you have to remember to
distrust — and if you are adding a gate, that is the standard.

### 3. The closure is asked whether the documentation is true

`tools/check-closure.sh` does not stop at "it built". It reads the result and
asserts the README's claims against it: no browser in
`environment.systemPackages` in either closure, `study` with no browser or
downloader in the home profile at all, and `study` **keeping** the search tools,
file managers and editors.

That first one is not hypothetical. It is the exact way `firefox` and `lynx` got
into the airgap the first time.

So a claim in the README about what the machine contains is a claim the build
checks. Change one and you change both, in the same commit.

## 4. The design, and what each decision cost

### Sessions are not specialisations, and the line is runtime coexistence

"Which compositor" **can** coexist with the base system at runtime — that is what
a display manager is for. "The radios are off" cannot, and neither can "Baloo is
not running".

The numbers are the argument: on the base system, Baloo and plocate plus
plasmashell, kwin and SDDM are about **1.3 GB resident**, to host a 35 MB editor.

### `study` inherits and `focus` does not

**`study` inherits.** It is this system with the radios off — it wants every
package, every font, all three compositors.

It sets `shaulos.study = true` (declared in `modules/system/profile.nix`), which
`modules/home/toolkit.nix` reads via `osConfig`. That flag exists so there is
**exactly one place** that says which home profile to import — because
`home-manager.users.<name>` is a submodule, so a second `imports = [ … ]` inside
an inheriting specialisation *merges* with the parent's rather than replacing
it.

**`focus` does not inherit.** It is a *smaller* system, and written as an
inheriting specialisation it would be about fifteen `lib.mkForce false` lines
that silently stop being true the next time `desktop.nix` gains a service.

`inheritParentConfig = false` makes it a different import list instead: Plasma is
absent because nothing imported `desktop.nix`. That also dissolves the
submodule-merge problem entirely — with no parent definition to merge with,
`home/focus.nix` can be a genuinely different profile and needs no flag.

### The catch, which is the failure mode of the whole idea

**"Absent because nothing imported it" only holds for options whose default is
off.**

`networking.useDHCP` defaults to **true** and is not implemented by
NetworkManager. So the first build of `focus` had no NetworkManager and a
`dhcpcd.service` nothing in this repository had ever mentioned. It evaluated, it
built, and it would have booted.

It showed up only in a **diff of `etc/systemd/system` against the parent.**

`focus` now says `networking.useDHCP = false` out loud. If you are adding to
`focus`, that diff is the technique — not reading the module list and assuming.

### Why the four gates exist

Most of these checks were **already in `flake.nix`, and nothing ran them.**

That is the same shape as the finding that split the Emacs config out of this
repository: `tools/verify.sh` byte-compiled every module and was wired to
nothing, so 1,569 lines silently stopped loading and no build ever went red. The
Emacs half got a CI job out of that. This half did not — and it is the half
authored on a Windows box with no Nix on it.

The bill was sitting in the tree.

### Formatting is deliberately not a gate

Nothing this config has ever suffered was a formatting problem, and a check that
goes red for cosmetics is a check people learn to scroll past. `just fmt` stays a
thing you run.

### Secrets are deliberately inert

sops-nix is wired in and not doing anything, on purpose, and the README defends
that at length. Read the argument before turning it on — it is about what a
secret in this repository would actually buy.

## 5. Making a change

### The loop

```sh
# edit
just eval        # fast: does the module system still evaluate, are the
                 # specialisations still exactly study and focus
just lint
just test        # activate without a boot entry
just switch      # when you are happy
```

Before pushing, `just check` runs everything CI does — including the 40-minute
closure build. `just eval` and `just lint` are what you run while iterating.

### Adding a package

The README's [*Where a package goes*](../README.md#where-a-package-goes) section
is the decision procedure, and it is worth following rather than guessing,
because the wrong location is what `check-closure.sh` catches.

Two things to remember:

- `environment.systemPackages` is subject to the **no-browser rule**, in both
  closures.
- Anything you add to the home profile is something `study` may need to strip —
  or may need to keep. `study` losing a search tool is a regression, not a
  tightening.

### Adding a service to `focus`

Check the diff, do not read the module list. See
[the catch](#the-catch-which-is-the-failure-mode-of-the-whole-idea).

### Adding an input

```sh
just lock        # the only command allowed to touch flake.lock
```

Then add a **call site in the same commit**. A `nixpkgs-unstable` input lived
here for a while, threaded through as an `unstable` arg, with zero call sites in
the whole repository.

### Adding a gate

Make the documented local command *be* the CI job. Not similar to it. See
[rule 2](#2-the-documented-local-command-must-be-the-ci-job).

## 6. Emacs

The Emacs configuration is **its own repository**, and a flake input here.

```sh
just update-emacs        # bump the emacs-config input only
just emacs-dev PATH      # rebuild against a local emacs-config checkout
```

Only the `essentials` module group loads on this machine — deliberately, and
configured here. The env var is `EMACS_MODULE_GROUPS`, and on NixOS it wants
setting in **two** places: `home.sessionVariables` for shells and
`systemd.user.sessionVariables` for the daemon `emacsclient` talks to.

## 7. First boot on a new machine

The README's *First-boot setup* section covers it. The one command worth knowing
now:

```sh
just bootstrap-data      # fetch ~/Documents from Google Drive + GitHub (idempotent)
```

Note that `study` turns the data bootstrap off along with the radios.

---

## Where to go next

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — symptom-first, starting with "I
  lost my desktop".
- [`../README.md`](../README.md) — the full reference: layout, sessions,
  specialisations, where a package goes, theming, keys, CI, secrets, first boot.
- [`../CHANGES.md`](../CHANGES.md) — the running record of what changed and why.
- [`../lamdan/shaulos-config-2026-08-06.md`](../lamdan/shaulos-config-2026-08-06.md)
  — a whole-repository design review, adversarial by design.
