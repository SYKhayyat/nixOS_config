# Troubleshooting

Symptom first.

Two things to know before anything else, because they change what a failure
means:

**One rule governs the lock file:** *nothing changes `flake.lock` except `just
lock`.* `--no-update-lock-file` is on every invocation, in CI and in the
`justfile`, so an input the lock does not pin is an **error** rather than a
silent resolve-and-carry-on.

**CI cannot tell you whether the system switches.** It builds the closure.
Activation, the greeter, and everything that only happens on real hardware are
still yours. `just switch` is still a thing you do with a boot menu in reach.

---

## Contents

- [I lost my desktop](#i-lost-my-desktop)
- [Rebuilding](#rebuilding)
- [The lock file and inputs](#the-lock-file-and-inputs)
- [CI and the gates](#ci-and-the-gates)
- [`tools/check-closure.sh`](#toolscheck-closuresh)
- [The specialisations](#the-specialisations)
- [Sessions and theming](#sessions-and-theming)
- [Packages](#packages)
- [Emacs](#emacs)
- [Secrets](#secrets)
- [Disk and generations](#disk-and-generations)

---

## I lost my desktop

**Reboot and pick an older generation.** systemd-boot keeps ten
(`configurationLimit`).

For a guaranteed TTY on *any* generation, press `e` at the boot menu and append:

```
systemd.unit=multi-user.target
```

That is what the old `minimal` specialisation was for, minus a whole system
closure.

If you can get a shell, roll back properly:

```sh
sudo nixos-rebuild switch --rollback
```

## Rebuilding

### `just switch` fails with "requires lock file changes but they're not allowed"

**Working as intended.** An input declared in `flake.nix` is not pinned in
`flake.lock`.

```sh
just lock        # lock a newly added input, and nothing else
```

That is the only command allowed to touch the lock. The alternative — letting
nix resolve it and write the entry — means a green run says nothing about the
inputs you are about to build, and `just switch` puts you on a system that is
not the one you committed.

This repository genuinely shipped in that state once: six inputs declared, four
pinned, and it did not evaluate at all.

### `nrs` / `nrt` rewrote my lock file

They should not any more — both carry `--no-update-lock-file` now. For a while
they did not, which made them the one hole in the rule the `justfile` states in
bold at the top.

Measured, with `sops-nix` dropped from `flake.lock`:

| Route | Exit | `flake.lock` |
|---|---|---|
| `just switch` | **1** — refused | untouched |
| `nrs`, before the flag | **0** — emitted a system drv | **silently rewritten** |

`nfu` is deliberately *without* the flag: rewriting the lock is that alias's
whole job, the same exemption `just lock` has.

If you see a lock rewrite from `nrs` today, that is a regression worth fixing at
the alias.

### `nrs` / `nrt` / `nfu` cannot find the flake

They assume the flake is checked out at `/home/shaul/nixos-config`, from
`myConfig.flakePath` in `flake.nix`. **Change it there if you clone
elsewhere.**

This is worth knowing because it was wrong once in an instructive way: the value
was `/home/shaul/nixOS_config-specializations` — the name of the *branch*, not
of any directory that has ever existed — so all three aliases resolved to a path
with no flake in it.

`just` was unaffected, because it uses `.#desktop` and is only ever run from the
checkout. **Which is exactly why nothing caught it.**

### The rebuild takes forty minutes

The `build` gate does too. Use the cheaper commands while iterating:

```sh
just eval      # all three of CI's eval steps, build nothing — the fast gate
just lint      # statix + deadnix, ~2m
just build     # build only, no activation
just test      # switch without a boot entry
```

`just test` is the one to reach for when you are unsure — it activates without
writing a boot entry, so a reboot gets you back.

### It built and will not activate

CI proves the closure builds and nothing more. Activation failures are yours,
and the message is in `journalctl -xe` or in the rebuild output itself.

`just test` first, `just switch` second, boot menu in reach.

## The lock file and inputs

### Which nixpkgs?

Pinned to **NixOS 26.05 "Yarara"** — `nixos-26.05`, `home-manager`
`release-26.05`, `stylix` `release-26.05`. **One nixpkgs.**

A second `nixpkgs-unstable` input used to be threaded in as an `unstable` arg
for per-package bleeding edge, and had **zero call sites in the whole repo**. If
you are reaching for it, add it back deliberately with a call site in the same
commit.

The Nix implementation is **Lix**
(`nix.package = pkgs.lixPackageSets.stable.lix`).

### Updating

```sh
just update          # nix flake update — everything
just update-emacs    # bump the emacs-config input only
just lock            # lock a newly added input, and nothing else
```

`nfu` is the shell alias for `just update`.

### The `lock` gate is red and three jobs were skipped

By design. `lint`, `eval` and `build` all `needs: lock`, so an unlocked input is
**one** red job and three skipped ones, rather than four identical failures with
the cause buried in each.

Fix the lock and the rest run.

## CI and the gates

Four gates on every push, cheapest first, each strictly stronger than the last —
and **all four run the same commands you can run by hand**:

| Gate | ~ | What it proves | By hand |
|---|---|---|---|
| `lock` | 1m | `flake.lock` accounts for every input in `flake.nix` | `nix flake metadata --no-update-lock-file` |
| `lint` | 2m | statix and deadnix are clean | `just lint` |
| `eval` | 5m | the whole module system evaluates, and `study` and `focus` are the only specialisations | `just eval` |
| `build` | 40m | the closure builds, and is the machine the README describes | `just closure` |

### A local command passed and CI went red

That equivalence used to be false in two rows, both in the same direction — they
claimed a local command was equivalent to a CI job when it was not. Both are
fixed; if you hit a third instance, this is the shape:

- `lint` once offered **`just check`**, which is `nix flake check` — *all four*
  checks including the 40-minute closure build. **A two-minute gate documented
  as a forty-minute one is a gate you stop running.**
- `eval` once offered a `just eval` that ran only the first of that job's three
  steps. Proven by construction rather than argued: deleting the entire
  `specialisation.focus` block left `just eval` **green** — it printed a drvPath
  and noticed nothing — while CI went red. The config could silently lose a
  whole specialisation and the documented local gate passed.

The fix in both cases was **to make the commands true rather than to soften the
claim**. A document that describes a weaker check is a document you have to
remember to distrust.

### Formatting is not a gate

Deliberately. Nothing this config has ever suffered was a formatting problem,
and a check that goes red for cosmetics is a check people learn to scroll past.

`just fmt` stays a thing you run.

### `just lint` fails on statix

`statix.toml` says what the lint gate checks — **and the one it does not**. Read
it before disabling a rule.

## `tools/check-closure.sh`

The `build` gate does not stop at "it built". It reads the result and asks
whether the README's claims are **true of it**.

### It says a browser is in the closure

That is the check doing its job, and it is not hypothetical: it is the exact way
`firefox` and `lynx` got into the airgap the first time.

The rule `base-tools.nix` states is that no browser is in
`environment.systemPackages` in **either** closure. `study` additionally has no
browser and no downloader in the home profile at all.

If you added one deliberately, the rule has to change too — in the same commit.

### It says `study` lost a tool it should have

`study` is meant to still have the search tools, the file managers and the
editors. It is *this system with the radios off*, not a stripped one. Losing a
tool from it is a regression, not a tightening.

### It passes and I do not trust it

Reasonable. `just closure` builds and asserts locally, so you can read what it
actually checks rather than taking the summary's word for it.

## The specialisations

Two, picked at the systemd-boot menu:

| Name | What it changes |
|---|---|
| `study` | NetworkManager, wireless, Bluetooth, sshd and the data bootstrap off; firewall deny-all; no browsers, no downloaders, no creative or media suite |
| `focus` | No Plasma, SDDM, X, compositor, PipeWire, printing, Flatpak, Bluetooth, network stack, Baloo, ollama or plocate timer. `cage` on tty1 running one Emacs frame |

```sh
just specialisations      # list what is available for next boot
```

### Why are the sessions not specialisations?

The line is **whether the difference can coexist with the base system at
runtime.**

"Which compositor" can — that is what a display manager is for. "The radios are
off" cannot, and neither can "Baloo is not running": on the base system those
two plus plasmashell, kwin and SDDM are about **1.3 GB resident**, to host a
35 MB editor.

### A service I never asked for is running in `focus`

**This is the failure mode of the whole idea, and it has happened.**

`focus` uses `inheritParentConfig = false`, so it is a different import list
rather than fifteen `lib.mkForce false` lines that silently stop being true the
next time `desktop.nix` gains a service. Plasma is absent because nothing
imported `desktop.nix`.

But *"absent because nothing imported it"* only holds for options whose default
is **off**. `networking.useDHCP` defaults to **true** and is not implemented by
NetworkManager — so the first build of `focus` had no NetworkManager and a
`dhcpcd.service` nothing in this repo had ever mentioned. It evaluated, built,
and would have booted. It showed up only in a **diff of `etc/systemd/system`
against the parent.**

`focus` now says `networking.useDHCP = false` out loud. If you suspect another
instance, that diff is the technique:

```sh
diff <(ls /nix/store/…-parent/etc/systemd/system) \
     <(ls /nix/store/…-focus/etc/systemd/system)
```

### A change to the home profile did not reach `study`

`study` **inherits**, and `home-manager.users.<name>` is a submodule — so a
second `imports = [ … ]` inside an inheriting specialisation **merges** with the
parent's rather than replacing it.

That is why there is a flag instead: `study` sets `shaulos.study = true`
(declared in `modules/system/profile.nix`), which `modules/home/toolkit.nix`
reads via `osConfig`. **Exactly one place says which home profile to import.**

`focus` needs no such flag, because with no parent definition to merge with,
`home/focus.nix` can be a genuinely different profile.

### The eval gate says there is a third specialisation

It asserts that `study` and `focus` are the **only** ones. If you added a third,
update the assertion in the same commit.

## Sessions and theming

Three graphical sessions from one system closure — **KDE Plasma**, **Niri** and
**Hyprland** — picked at the SDDM greeter.

### A session is missing from the greeter

Rebuild and re-log. If it is still absent, check that the session's module is
imported by `desktop.nix` — a session that nothing imports is absent with no
error, the same shape as the `focus` case above.

### Theming looks inconsistent between sessions

Theming is driven by [stylix](https://github.com/nix-community/stylix), and
Plasma additionally by
[plasma-manager](https://github.com/nix-community/plasma-manager). A setting
that plasma-manager owns will not follow into Niri or Hyprland, and the reverse.

The README's *Theming* section is the map of which layer owns what.

## Packages

### Where does a package go?

The README has a whole section on this
([*Where a package goes*](../README.md#where-a-package-goes)), and it is worth
reading before adding one, because the wrong location is what
`check-closure.sh` catches.

The short version: `environment.systemPackages` is the system closure and is
subject to the no-browser rule; the home profile is per-user and is what `study`
strips.

### A package is in the closure and I did not put it there

Something imported it transitively. `nix why-depends` against the built closure
is the tool:

```sh
nix why-depends /run/current-system /nix/store/…-thepackage
```

## Emacs

The Emacs configuration lives in **its own repository** and is a flake input
here. That split happened for a specific reason worth knowing.

### Only `essentials` loads

That is deliberate and configured here — see *Emacs: only `essentials` loads* in
the [README](../README.md#emacs-only-essentials-loads).

The env var is `EMACS_MODULE_GROUPS`, and on NixOS it needs setting in **two**
places: `home.sessionVariables` for shells and `systemd.user.sessionVariables`
for the daemon `emacsclient` talks to. Setting only one gives an Emacs that
behaves differently depending on how you started it.

### Working on the Emacs config against this machine

```sh
just emacs-dev PATH      # rebuild against a local emacs-config checkout
just update-emacs        # bump the emacs-config input only
```

### Why Emacs is a separate repository

`tools/verify.sh` in the old combined repository byte-compiled every module and
was **wired to nothing**, so 1,569 lines silently stopped loading and no build
ever went red. The Emacs half got a CI job out of that finding.

This half did not, at the time — and it is the half authored on a Windows box
with no Nix on it. The bill was sitting in the tree: `flake.nix` declared six
inputs, `flake.lock` pinned four, and the repo as committed did not evaluate at
all. That is why the four gates above exist.

## Secrets

**sops-nix is inert right now, on purpose.** The README has a section defending
that decision at length; read it before wiring anything up, because the argument
is about what a secret in this repository would actually buy.

The dev shell (`nix develop`) provides `sops`, `age` and `ssh-to-age` for the
walkthrough.

## Disk and generations

```sh
just gc              # nix-collect-garbage --delete-older-than 14d
```

systemd-boot keeps ten generations (`configurationLimit`). A garbage collection
that removes a generation you are still booted into is refused; one that removes
the *only* older generation leaves you without a rollback target, which is worth
thinking about before running it on a machine you are about to change.

### The store is enormous

Expected on a machine that has built three compositors and two specialisations.
`just gc` is the routine answer. `nix store optimise` deduplicates by hard-link
if you want more.

---

## Useful commands, all in one place

```sh
just                 # or `just --list` — everything
just switch          # sudo nixos-rebuild switch --flake .#desktop
just test            # activate without a boot entry
just build           # build only, no activation
just specialisations # what is available for next boot
just eval            # the fast gate — all three of CI's eval steps
just lint            # statix + deadnix (~2m)
just closure         # build and assert what the closure claims about itself
just check           # everything CI checks
just fmt             # nix fmt (nixfmt)
just gc              # collect garbage older than 14 days
just bundle          # dump all *.nix into combined.txt
```

Shell aliases from `home/common.nix`: `nrs` (switch), `nrt` (test), `nfu` (flake
update). They use `myConfig.flakePath`, so they work regardless of the current
directory.

## Reporting something not on this page

Include which specialisation and session you were in, the output of `just eval`,
and — for anything about what is or is not in the system — the relevant part of
`just closure`.

`lamdan/shaulos-config-2026-08-06.md` is a whole-repository design review, and
`CHANGES.md` is the running record of what changed and why.
