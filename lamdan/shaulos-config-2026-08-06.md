# Lamdan — ShaulOS NixOS config

**Date:** 2026-08-06
**Scope:** whole repo, working tree (not HEAD — the entire overhaul is uncommitted)
**Question asked:** not "does this work" — "should this exist, and is this the shape it should have"

---

## Coverage — read this before trusting anything below

Every tracked file was assigned to a region and every region was read. Depth was not
uniform, and here is exactly where it wasn't:

| Region | Files | Depth |
|---|---|---|
| Flake, host entry, specialisation factory | `flake.nix`, `hosts/`, `lib/`, `justfile` | full line read |
| System modules | `modules/system/*.nix` (12) | full line read |
| Home profiles | `home/*.nix` (4) | full line read |
| Home Wayland / ricing | `modules/home/*.nix`, `niri/`, `hyprland/` (13) | full line read |
| Emacs Nix layer + loader | `emacs/default.nix`, `init.el`, `early-init.el`, `tools/*.sh` | full line read |
| Emacs literate modules | 40 `.org` files, 5,513 lines | **6 read in full; 34 read structurally** |
| Prose docs | 7 READMEs / guides, ~1,100 lines | **not read** (`modules/README.md` excepted) |

"Structurally" means: every `defun`, `provide`, `require`, `use-package`, `defhydra`,
tangle target, and global keybinding was extracted from all 40 files and cross-checked
for collisions, dangling references, and filename drift. That pass is what produced
finding #1. It is not a substitute for reading the elisp, and no claim below rests on
elisp I did not read.

Also excluded: `flake.lock`, `wallpaper.jpg`.

**History was used to rank, never to select.** 38 commits, 31 of whose messages are
literally `...`, last real commit 2026-07-30. Churn concentrates in
`modules/home/hyprland/default.nix` (17), `modules/home/niri/default.nix` (14),
`home/study.nix` (11 changes on a 23-line file). That ranking agrees with the findings
below rather than producing them — which is the only use history is fit for here,
because a repo whose commit messages are ellipses has no recorded intent to mine.

---

## What I committed to before reading any implementation

> A single user, a single desktop machine, one person's tools. The want ladder: "four
> bootable desktop environments" climbs to "I want to try tiling WMs without losing my
> working Plasma desktop" climbs to "I don't want a broken session to leave me with no way
> to use my computer." What satisfies that minimum: install every session's packages side
> by side, let the greeter offer them, and keep the last-good generation in the boot menu —
> which NixOS gives you for free and which is the *actual* rollback story. Specialisations
> earn their keep only where the difference can't coexist at runtime in one closure: a
> genuinely airgapped mode where the firewall and NetworkManager must actually be off, and
> a TTY recovery target. So I'd predict two specialisations, not four, and I'd expect a
> factory abstraction (`lib/mk-specialization.nix`) to exist *because* the count was
> inflated past the point where writing them out by hand felt bad. Layout-wise: flake, one
> host dir, ~8 system modules, home-manager profiles, and Emacs **out of this repo
> entirely** — Nix installs the editor, the editor's config is its own thing with its own
> life cycle.

The sketch was right about the specialisations and right about Emacs, and it badly
underestimated how much the Emacs half would turn out to be the whole story. It had no
idea the seforim system was in here, let alone that it was broken.

---

# Lens 1 — Was this the right software to build?

## Finding 1.1 — This is two products in one repo, and the second one is currently dead

**Verdict: `rewrite` — split the repository.**

By line count this is not a NixOS configuration that happens to include Emacs. It is an
Emacs distribution that happens to be shipped by Nix:

```
all .nix                 2,332      of which system/    887
                                    of which emacs nix  138
Emacs .org modules       5,513
Emacs loader (.el)         289
Emacs tools (.sh)          173
Emacs docs (.md)           850
──────────────────────────────
Emacs total              6,963      ≈ 3× the entire Nix configuration
```

And it is not merely large — it is explicitly, deliberately, *a different product*, and
the code says so in its own words:

- `init.el`: *"Portable modular loader (NixOS / Linux / Windows / macOS) … ONE config,
  everywhere."*
- `early-init.el`: *"PORTABLE: nothing here is OS- or Nix-specific."*
- `init.el` carries `w32-pipe-read-delay`, `~/scoop/shims`, `C:/msys64/mingw64/bin`,
  `/opt/homebrew/bin`, and a darwin menu-bar branch.
- `00-core.org` auto-detects Nix-vs-MELPA and self-installs from MELPA on a bare box.
- `tools/verify.sh` byte-compiles against `$HOME/.emacs.d/elpa` — a package.el install —
  and calls `cygpath` for Windows paths.
- `tools/deploy.sh` exists **to copy this config onto a non-Nix machine**, and warns:
  *"Do NOT point this at `~/.config/emacs` on NixOS: home-manager owns init.el there as a
  read-only store symlink and the copy will fail or fight it."*

That last line is the argument in one sentence. The project's own deployment tool has to
warn you away from the machine the repo is named after.

**What that costs, concretely.** Because the Emacs config must be writable (it tangles
`.el` next to `.org` at runtime) and the Nix store is not, `default.nix` stages the
modules read-only at `~/.config/emacs/modules-src` and then runs a 20-line activation
script that is a hand-rolled `cp -u`:

```nix
if [ ! -f "$dest" ] || [ "$org" -nt "$dest" ]; then
  $DRY_RUN_CMD install -m 0644 "$org" "$dest"
fi
```

So the path from repo to running code is: repo → nix store → **mtime-gated copy into a
mutable dir Nix does not own** → tangled `.el` → loaded. Nix's guarantee covers the first
hop. Everything after it is a directory in `$HOME` that Nix cannot roll back, cannot
garbage-collect, and never deletes from — the sync only ever adds. Edit
`~/.config/emacs/modules/extras/00-hebrew.org` directly (and you will, because it's an org
file in your editor and it is writable) and one of two things happens on the next
`just switch`: your edit is newer, so it *survives* and is now the live config while the
repo is silently stale — or it's older, and it is clobbered with no backup. You cannot
tell from the outside which one happened.

**The bill, and it has already arrived.** The essentials/extras split renumbered every
module. `10-seforim-core.org` correctly `(provide '10-seforim-core)`. But five modules
still require the *old* feature names:

| Module | Lines | Requires |
|---|---|---|
| `extras/11-seforim-candidates.org` | 87 | `14a-seforim-core` |
| `extras/12-seforim-search.org` | 129 | `14a-`, `14b-` |
| `extras/13-seforim-extras.org` | 236 | `14a-`, `14b-` |
| `extras/14-seforim-mefarshim.org` | 526 | `14a-`, `14b-` |
| `extras/15-seforim-dream.org` | 591 | `14a-`, `14b-`, `14c-`, `14d-`, `14e-` |

Nothing provides `14a-seforim-core`, `14b-seforim-candidates`, `14c-seforim-search`,
`14d-seforim-extras`, or `14e-seforim-mefarshim`. `require` signals; `init.el` catches it
in `condition-case`, pushes to `my/load-errors`, and prints one line to `*Messages*`.

**1,569 of the seforim system's 1,775 lines do not load.** The Otzaria mefarshim linker,
the search layer, the study log, the bookmarks, the TOC, the reader mode, the dashboard —
all of it. Only `10-seforim-core` (206 lines, the one module that requires nothing)
survives. The symptom is not a crash. The symptom is `M-x seforim-mefarshim` quietly not
existing.

`init.el`'s own comment says the gate must key on the module's *name*, not its number,
because *"renumbering a module — which the essentials/extras split did to most of them —
must not silently un-gate it, and nothing tells you."* The exact hazard was identified,
guarded against in one place, and missed in another. And `tools/verify.sh` — which
byte-compiles every module and would surface these — is wired to nothing that runs.
`nix flake check` runs statix and deadnix over `.nix` files. Nothing in this repo has ever
looked at the elisp.

Separately: six `extras/*.org` modules are **untracked** —
`01-hebrew-completion`, `02-hebrew-org`, `03-hebrew-typesetting`, `06-torah-search`,
`16-seforim-integration`, `17-hydras`. A flake in a git repo copies the *git tree* to the
store. Untracked files do not make it. On this machine you will never notice, because the
mutable `modules/` dir already has them from a previous deploy and the sync never deletes.
On the fresh install this whole mechanism exists to guarantee, they are simply gone. That
is the writable-copy hack not merely weakening reproducibility but *concealing its own
failure*.

**Steelman.** One repo means one `git pull`, one place to look, and the Emacs config
versions in lockstep with the system that provides its `texlive`, `tinymist`, `recoll`,
`hdate`, and language servers — which is a genuine coupling, not an imagined one. If this
machine is the only place the Emacs config actually runs, the portability is aspirational
and the split is bookkeeping for a benefit you never collect. And splitting costs you the
atomic "bump Emacs config and the packages it needs in one commit."

**If none of those hold, it's wrong** — and the first one doesn't hold, because
`deploy.sh`, `verify.sh`'s ELPA path, and every Windows branch in `init.el` are proof the
config already runs somewhere else. The coupling argument survives, and a flake input
handles it better than a subdirectory does: you get the lockstep *and* a revision you can
pin, roll back, and see in `flake.lock`.

**The change.**

1. New repo `emacs-config`, containing `init.el`, `early-init.el`, `modules/`, `tools/`,
   and the four Emacs READMEs. `deploy.sh` is its installer. It gets its own CI: one job,
   `tools/verify.sh`, on push. That job is what would have caught finding 1.1's bill.
2. In this flake, `modules/home/emacs/default.nix` keeps the package set, `services.emacs`,
   the `recoll.conf`, and the directory-scaffolding activation — and loses the
   `modules-src` staging, the mtime syncer, and the module tree. It drops from 138 lines to
   roughly 60.
3. The Emacs config arrives either as a flake input (pinned, reproducible, `home.file`
   pointing at the store) or as a plain `git clone` in `$HOME` (mutable, honest about it).
   Pick one deliberately. The current design is the worst of both: it *looks* pinned and
   *behaves* mutable.

**The cost.** Real but bounded. Two repos to clone on a fresh box. `just switch` no longer
deploys Emacs changes — `deploy.sh` does, or a flake input bump does. Nothing else in the
config imports `modules/home/emacs/modules`, so the extraction is a `git filter-repo` and
one import change. Can be done in one sitting, and is strictly easier now than after the
next round of modules lands.

**Do first, regardless of whether you split:** fix the five `require` forms and
`git add` the six untracked modules. That is a ten-minute change that resurrects 1,569
lines. Then run `tools/verify.sh` before you trust any of it.

## Finding 1.2 — `minimal` is not minimal, and does not need to exist

**Verdict: `delete`.**

Specialisations inherit the parent configuration. `minimal.nix` force-disables `xserver`,
`sddm`, and `plasma6`, and adds a small package list. It does not — cannot — remove
anything else the base imported: pipewire, printing, flatpak, all 16 font packages, the
whole of `cli-tools.nix` and `development.nix`.

And the home side does not shrink either. `mkSpecialization` guards home-manager with
`lib.mkIf (homeDesktopPath != null)`. `mkIf false` contributes nothing — it does not
*retract* the parent's `home-manager.users.shaul = home/desktop.nix`. So the "recovery
mode" specialisation still builds LibreOffice, GIMP with plugins, Krita, digiKam,
darktable, RawTherapee, Inkscape, Scribus, tor-browser, and the rest of the 30-package
graphics suite.

`minimal` is the full system with three services turned off, and it costs you a fifth
system closure on every `nixos-rebuild`, on a machine `hardware.nix` describes as
low-RAM.

**Steelman.** If the real want is "a boot menu entry I can reach when a compositor change
wedges the graphical session," it does deliver that, and it delivers it *from the boot
menu* — which is where you need it when you can't get a session. That is a genuine
property, and "wrong for the stated reason, right for the actual reason" is a real
outcome.

**It still loses**, because you already have that entry: systemd-boot with
`configurationLimit = 10` lists the previous ten generations, any of which boots the
system you had before you broke it — which is strictly more useful than the *current*
system minus a display manager. And if you want a guaranteed TTY on demand, press `e` at
the boot menu and append `systemd.unit=multi-user.target`. No closure, no rebuild, and it
works on every generation, not just this one.

**The change.** Delete `specialisation.minimal` and `modules/system/minimal.nix`. If you
want the convenience of a menu entry, that's a `boot.loader.systemd-boot.extraEntries`
stanza pointing at the same kernel with `systemd.unit=multi-user.target` — a few lines, no
second closure. **Cost:** one boot-menu entry disappears; nothing imports `minimal.nix`.

---

# Lens 2 — Right software, wrong shape?

## Finding 2.1 — `hyprland` and `niri` should be sessions, not specialisations

**Verdict: `delete` (two of the four), keep `study`.**

`study` earns its specialisation and I want to be clear about that: NetworkManager off,
wireless off, Bluetooth off, firewall deny-all, sshd/onedrive/file-sync off. That state
genuinely cannot coexist with the base system at runtime, and the module comment even
notes it fixed a ~90s boot stall on `network-online.target`. Correct tool, correct use.

`hyprland` and `niri` are a different thing entirely. Both are Wayland compositors that
install cleanly alongside Plasma and register `.desktop` session files via uwsm. SDDM will
list them. That is what a display manager *is*. Building a second and third full system
closure so you can pick a compositor at the bootloader instead of the login screen means:
every `nixos-rebuild switch` builds all of them, every one is a GC root, and switching
compositors costs a reboot instead of a logout.

The tell is `lib/mk-specialization.nix` itself. It exists to make four of these cheap to
write, and what it actually does is force `sddm.enable`, `sddm.wayland.enable`,
`plasma6.enable`, and `defaultSession` per specialisation — i.e. it is a machine for
answering "which session should the display manager start," which is a question the
display manager already answers, at login, for free.

It also carries three branches for `lxqt` (lines 20, 21, 27) — a desktop environment
never passed to it from anywhere in the repo. Config knob, zero call sites, no history of
changing: that was never a requirement, it was a hedge.

**Steelman.** Two real properties here. First, per-session *system-level* divergence:
`hyprland` pulls in `modules/system/hyprland.nix`, `niri` pulls in `niri.nix`, and if you
enabled both unconditionally you'd carry both compositors' system config in one closure.
Second, `programs.plasma` with `overrideConfig = true` is destructive to Plasma's config
directory, so isolating the sessions that shouldn't touch it has some value.

**Both are answerable without specialisations.** Enabling `programs.niri` and
`programs.hyprland` together is normal and supported — the cost is disk in one closure
instead of disk across three, which is *less* total. And `programs.plasma.enable` is
already gated on `desktopEnvironment == "plasma"`; under a unified session that gate
becomes "am I the Plasma home profile," which is the same conditional in a different
place.

**The change.** Enable both compositor system modules in the base. Keep `study` as the one
specialisation. Home-manager grows a session dimension instead of a boot dimension — the
cleanest version is one home profile that reads `XDG_CURRENT_DESKTOP`/`$DESKTOP_SESSION`
for the handful of things that genuinely differ, or three profiles selected the way you
select them now, minus the boot closures. Delete the three `lxqt` branches either way.

**The cost.** This is the expensive finding and I'm not going to pretend otherwise.
`mk-specialization.nix`, `hosts/desktop/configuration.nix`, and all four `home/*.nix`
profiles change. `home/desktop.nix` currently serves both Plasma and Hyprland via a
`desktopEnvironment` conditional and would need untangling. Not incremental; one focused
sitting, and you should do it on a day when you can reboot a few times. **This is the one
finding where "I'd rather keep it" is a defensible answer** — the config works, and the
cost of reshaping it is real. But it is the decision everything else in the Wayland half
inherits from, including 2.2 and 2.3, and it gets more expensive with every module that
learns about specialisations.

## Finding 2.2 — `modules/system/niri.nix` and `modules/system/hyprland.nix` are the same file

**Verdict: `rewrite`.**

22 of ~30 non-blank lines are byte-identical: `acpilight`, `udisks2`, `upower`,
`gnome-keyring`, `polkit`, `dbus.packages = [ gcr ]`, both PAM stanzas, the identical
five-package list, `fontconfig`. The only real differences are `programs.<name>.enable`
and the uwsm compositor block.

These are also the two highest-churn files' system-level counterparts, and the
duplication behaves exactly as duplication does — the fix lands in one and not the other:

- `home/desktop.nix` imports `modules/home/p10k.nix`; `home/niri.nix` and `home/study.nix`
  do not. `common.nix` loads the powerlevel10k *plugin* everywhere but sources
  `~/.p10k.zsh`, which only `p10k.nix` writes. So niri and study get p10k with no config.
  `CHANGES.md` records fixing precisely this class of regression ("niri & study
  specialisations now import `common.nix` — previously they booted with no
  zsh/p10k/aliases") — the `common.nix` half was fixed and the p10k half was left behind.
  Same story for `foot.nix`: only `desktop.nix` imports it, while niri and study both bind
  `Mod+Return` to foot and install it via `wayland-common.nix`.
- `modules/home/hyprland/default.nix` binds `Mod+E` to `dolphin` and imports `yazi.nix`,
  whose `reveal` opener also shells out to `dolphin` — and installs `pcmanfm-qt` and
  `thunar` instead. `niri/default.nix` and `home/study.nix` install `kdePackages.dolphin`.
  Only the session that binds it lacks it. (Plasma ships dolphin system-wide in the base,
  which is why this is invisible until you actually boot the hyprland specialisation, where
  `plasma6.enable` is forced off.)
- `hyprland` gets a full `hypridle` config (dim at 5min, lock at 7, DPMS at 10) via
  `lock-idle.nix`. `niri` gets `lock-niri.nix`, which is three lines installing `swaylock`
  and nothing else — no idle daemon, no timeout. **The niri session never auto-locks.**
  Reachable via wlogout, so it isn't dead code, but the behaviour differs in a way you'd
  only discover by walking away from the machine.
- `hyprland/default.nix` hardcodes `monitor = , 1366x768@60, 0x0, 1`. `niri` uses
  `output ".*" { scale 1.0 }` with no mode. Plug in an external display and the two
  sessions behave differently, for no reason anyone chose.

**Steelman.** Two compositors genuinely do diverge, the files are 35 lines each, and a
premature factory over two instances is the classic wrong abstraction. "Duplicate it twice,
abstract on the third" is sound advice and this is only the second.

**It loses on evidence rather than principle.** You already found this pattern on the home
side and solved it — `wayland-common.nix` exists, its header explains that these bits
"were copy-pasted across `home/niri.nix` and `home/study.nix`," and it takes the compositor
name as a parameter. The identical shape one directory over went unfactored, and the drift
list above is what that cost. This isn't "abstract on the third," it's "you already
abstracted this exact thing, in this exact repo, and stopped halfway."

**The change.** `modules/system/wayland-session.nix`, taking `{ compositor, package,
binPath, prettyName, comment, extraArgs ? [] }` — a mirror of `wayland-common.nix` on the
system side. Both current files become four-line call sites. **Cost:** two call sites, no
dependents, ~30 minutes. This one is cheap and I'd do it today even if you reject 2.1.

## Finding 2.3 — `scripts.nix` discovers at runtime what the build already knows

**Verdict: `rewrite`.**

Every script in `modules/home/scripts.nix` opens with:

```sh
if pgrep -x niri >/dev/null; then COMPOSITOR="niri"
elif pgrep -x Hyprland >/dev/null; then COMPOSITOR="hyprland"
else COMPOSITOR="plasma"; fi
```

`desktopEnvironment` is threaded through `specialArgs` → `extraSpecialArgs` into every
home-manager module. `scripts.nix` is a home-manager module. It has the answer in scope at
evaluation time, does not ask for it, and shells out to `pgrep` to rediscover it — in
eight separate scripts, on every invocation, on a keypress path.

The consequence isn't the `pgrep`; it's that the scripts must then handle cases that
cannot occur. `scripts.nix` is imported by `common.nix`, so *every* session gets all eight.
Under Plasma, `spotlight`, `teleport`, and `toggle-scratchpad-terminal` fall through every
branch and exit silently having done nothing. Three commands on your `PATH` that are
no-ops, by construction, in the default session.

`waybar.nix` has the identical disease in a different dialect: one shared bar config listing
`niri/window` *and* `hyprland/window`, `niri/workspaces` *and* `hyprland/workspaces`, letting
waybar sort out which modules its compositor supports. Its signature is
`{ pkgs, config, lib, ... }` — `desktopEnvironment` is available and unrequested.

**Steelman.** Runtime detection means one script that is correct on any machine, including
one where you launched a compositor by hand outside its specialisation. That's a real
property, and it's the same portability instinct that makes `init.el` good.

**It loses here** because unlike `init.el` — which faces genuinely unknown machines — these
scripts are generated per closure, by a build that has already decided which compositor
this closure is for. Detecting a fact you compiled in is how you end up shipping dead
branches and calling them robustness. The 50-line `spotlight`/`teleport`/`toggleTerm`
triple becomes ~20 lines with one branch each.

**The change.** `scripts.nix` and `waybar.nix` take `desktopEnvironment`; branch at eval;
under Plasma, install only the four scripts that work there (`power-search`, `volctl`,
`screenshot-edit`, `toggle-scratchpad-emacs`). **Cost:** two files, no external dependents,
under an hour. Independent of 2.1 — worth doing either way, and if you *do* unify the
sessions per 2.1 you'll want the runtime path back, so do this one second.

## Finding 2.4 — `palette.nix` is the DRY fix that stopped one level short

**Verdict: `wrong-but-keep`.**

`palette.nix` correctly collapses colours that were duplicated across waybar, hyprlock,
niri, and hyprland. It then hardcodes tokyo-night-dark as five literals, duplicating
`stylix.base16Scheme` in `core.nix`. Change the scheme there and every riced surface keeps
the old colours — silently, because nothing connects them. The file's own comment names the
fix: *"or later wire them to `config.lib.stylix.colors`."*

**Steelman, and it's a good one.** Literals mean every module evaluates without reaching
into another module's internals, `palette.nix` stays a plain data file importable with a
bare `import`, and `config.lib.stylix.colors` is an interface stylix has moved around
before. You change your colour scheme roughly never.

**That steelman mostly holds**, which is why this is `wrong-but-keep` rather than
`rewrite`. It is a two-source-of-truth arrangement whose second source you touch once a
year. Wire it up when stylix next breaks something and you're in the file anyway; the cost
is that `palette.nix` stops being a bare-`import` data file and becomes a real module. Not
worth a dedicated pass.

---

# Lens 3 — Right shape, wrong code inside it?

Lens 3 is the cheapest lens and the least is at stake in it. These are small and I am
labelling them small.

## 3.1 — A second full nixpkgs evaluation for zero call sites

**Verdict: `delete`.**

```nix
unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
```

threaded through `specialArgs` into the host config, through `mk-specialization` into all
four specialisations, and through `extraSpecialArgs` into every home-manager module. A
repo-wide grep for `unstable.` returns two hits: the input URL and the comment explaining
how to use it. **Zero uses.**

`CHANGES.md` presents this as an improvement: *"The `unstable` special-arg is no longer a
no-op alias for `pkgs` — it's a real second nixpkgs."* It was a free no-op alias. It is now
a second full nixpkgs eval — a second fetch, a second lock entry, more eval time and memory
on every rebuild — with exactly the same zero benefit. The same commit correctly removed a
duplicate nixpkgs from the lock (stylix's `nixpkgs_2`) and added a new one four lines up.

**Steelman.** It's scaffolding for a want you know you'll have — the moment you need one
package ahead of stable, it's already wired everywhere and you type `unstable.foo`. Removing
it means re-plumbing `specialArgs` through five configurations later.

**It loses on the §2 table's own row**: a config knob with no call sites and no history of
changing was never a requirement, it was a hedge. Re-adding it is the same four lines you'd
delete, and you'd re-add them at the moment you have an actual package in mind — which is
when you'd find out whether `specialArgs` is even the shape you want.

**The change.** Drop the `nixpkgs-unstable` input and the `unstable` special-arg. Note that
`mk-specialization.nix` already handles `unstable == null` by falling back to `pkgs`, so the
call sites degrade cleanly. **Cost:** four lines, one `nix flake update`. Ten minutes.

## 3.2 — Firefox is installed in the "no browsers" airgap

**Verdict: `rewrite`. One line.**

`README.md` describes `study` as *"offline airgap, no browsers."* `home/study.nix` does
`programs.firefox.enable = lib.mkForce false` — that is home-manager's option.
`modules/system/cli-tools.nix:43` sets `programs.firefox.enable = true` at the **NixOS**
level, which puts firefox in `environment.systemPackages`, and the study specialisation
inherits it. `lynx` is in the same file.

The airgap itself is intact — NM off, wireless off, firewall deny-all — so nothing gets out.
But "no browsers" is not a claim about packets; the network denial is the *backstop*. The
feature is removing the thing you'd open out of habit, and `firefox` is on your `PATH` in
the one session designed to prevent that. (`tor-browser` and `qutebrowser` are correctly
absent — they live in `home/desktop.nix`, which study doesn't import. Only the system-level
one leaks.)

**Steelman.** A browser that cannot reach anything is harmless, and firefox is also a
perfectly good local HTML/PDF viewer, which in a study session you might actually want.

**That's a fair point about firefox and a bad one about the airgap** — if you want a local
viewer, `study.nix` can install one deliberately. Inheriting it by accident from
`cli-tools.nix` isn't a decision, and the README's claim is false either way.

**The change.** `programs.firefox.enable = lib.mkForce false;` in
`modules/system/study-offline.nix`. **Cost:** one line.

## 3.3 — Two modules, one terminal toggle

**Verdict: `delete` (the dead half).**

`essentials/16-vterm.org` and `essentials/17-terminal.org` both define `my/toggle-terminal`
and both `global-set-key` it to `` C-` `` and `C-c t t`. 17 loads after 16, so 17 wins and
16's definition plus both its bindings are dead. One want, satisfied twice, second written
without deleting the first. **Cost:** delete ~12 lines from `16-vterm.org`.

## 3.4 — Small, noted, not argued

- `services.onedrive` + the `onedriver` package + rclone `file-sync.nix`: three sync tools,
  one user, one drive. `CHANGES.md` already flags this as "pick the ones you actually use"
  and deferring it was reasonable. It has a cost you can see in `study-offline.nix`, which
  must force two of the three off individually.
- `system.nixos.version = "current"` in `core.nix` means `nixos-version` won't tell you what
  release you're on. `CHANGES.md` calls it cosmetic; it's cosmetic right up until a rebuild
  goes wrong and that's the command you reach for.
- `cli-tools.nix` carries 13 different file/text search tools (`fd`, `ripgrep`,
  `ripgrep-all`, `fzf`, `fzy`, `plocate`, `recoll`, `fsearch`, `kfind`, `television`,
  `docfd`, `skim`, `ugrep`, `tre`), four editors, and six file managers — all in
  `environment.systemPackages`, so all in every specialisation. This is taste, not a defect;
  trying tools out is exactly what a NixOS config is *for* and removing one is a line
  delete. The only argument against is that `systemPackages` puts them in the base closure
  rather than in `nix shell`, on a machine you describe as low-RAM.
- `powerSearch` is `writeShellScriptBin "power-search" "exec fsearch"` — a wrapper whose
  entire body renames a binary. It's referenced by keybind in both compositors, so it isn't
  dead, but the keybind could name `fsearch`.
- `spotlight` keeps toggle state in `/tmp/spotlight-state`. If the toggle ever desyncs from
  reality it stays desynced until reboot.

---

# What I tried to beat and couldn't

Three things, and they're not consolation prizes — I sat down to design better answers and
came away with worse ones.

**The capability gate in `00-core.org` is right, and my instinct was wrong.**
`my/package-usable-p` records what it skipped and why, gates on `executable-find` rather
than `system-type`, and — the part I'd have missed — gates at the *package* level, not the
module level, with the reasoning spelled out: jinx lives in the completion module, so a
module-level gate on missing `enchant` would silently take vertico, consult and corfu down
with it. I would have written `(when (eq system-type 'gnu/linux) ...)` and been wrong on
every axis. The comment explaining why the OS is the wrong question is the best paragraph in
the repo.

**The stale-index handling in `00-core.org` is a bug I have personally shipped.** The note
that `(unless package-archive-contents (package-refresh-contents))` only refreshes when the
index is *entirely absent* — so a stale index is non-nil forever and never refreshes, and a
week-old MELPA index asks for tarballs that no longer exist — is exactly right, correctly
diagnosed, and correctly fixed with an age check plus a retry-after-refresh advice. I have
nothing to add to it.

**The rename was executed carefully everywhere it was checkable.** I scanned all 40 modules
for tangle targets that disagree with their filename, `provide` forms that disagree with
their filename, and orphaned `.el` output: **zero mismatches**. Which makes the `require`
breakage in 1.1 more interesting rather than less — every consistency check the tooling
*could* express was satisfied. The one that broke is the one no tool in this repo runs.
That's not carelessness; that's a missing CI job.

Honourable mention: `nix.extraOptions = "!include /etc/nix/tokens.conf"` with the
corresponding sops secret commented out. `!include` is the non-failing form, so the config
evaluates and runs cleanly with the file absent and picks the token up the moment it exists.
That's the correct spelling of a deliberate hedge, and it's easy to get wrong.

---

# Ranked

| # | Lens | Verdict | Claim | Cost |
|---|---|---|---|---|
| 1.1 | 1 | `rewrite` | Emacs config is a separate product; 1,569 lines of it currently don't load | Repo split: one sitting. **The require fix: 10 minutes.** |
| 2.1 | 2 | `delete` | `hyprland`/`niri` should be greeter sessions, not boot closures | High — touches 6 files |
| 1.2 | 1 | `delete` | `minimal` isn't minimal and duplicates what generations already give you | Low |
| 2.2 | 2 | `rewrite` | The two compositor system modules are one file; the drift is already visible | ~30 min |
| 2.3 | 2 | `rewrite` | Scripts `pgrep` for a fact the build compiled in | ~1 hour |
| 3.1 | 3 | `delete` | Second nixpkgs eval, zero call sites | 10 min |
| 3.2 | 3 | `rewrite` | Firefox present in the "no browsers" airgap | 1 line |
| 3.3 | 3 | `delete` | Duplicate terminal toggle | 12 lines |
| 2.4 | 2 | `wrong-but-keep` | `palette.nix` duplicates the stylix scheme | Not worth a pass |

The findings do **not** cluster in one region: lens 1 lands on the Emacs tree, lens 2 on
the specialisation/compositor architecture, lens 3 across the flake and system modules.
That distribution is the main evidence that the sweep wasn't just fishing where the light
was good — the single biggest finding came out of the region with the least git history
attached to it, which is exactly the region a churn-driven review would have skipped.

---

# The question I can't answer from the repo

Half of what makes a design wrong is the change it's about to face, and that isn't in here.
Two specific gaps:

1. **Is this a laptop or a desktop?** The host is `desktop`, the directory is
   `hosts/desktop/`, `hardware-configuration.nix` shows a swap *partition* and `kvm-intel`.
   Meanwhile `hardware.nix` says "Laptop hardware," configures TLP with
   `START/STOP_CHARGE_THRESH_BAT0`, enables thermald and `powerManagement`, and its comment
   says "this low-RAM laptop" — and `hyprland/default.nix` hardcodes a 1366x768 panel. If
   it's a desktop, the TLP battery-threshold block is configuring hardware that doesn't
   exist. If it's a laptop, the name is just a name and that's fine. This changes whether
   `hardware.nix` is right or is cargo.

2. **What are you building next?** If the answer involves a second machine, finding 1.1 goes
   from "should" to "must" and finding 2.1 changes shape. If it involves getting the seforim
   system to a state you'd show someone, that's a CI job on `verify.sh` and it's the highest-
   leverage hour in this list.
