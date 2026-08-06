# Overhaul — what changed and what you must do next

This pass fixed build-blocking bugs, de-duplicated the config, added repo tooling,
made Emacs reproducible, and added laptop hardware + a real study airgap.
It was authored off-machine, so **nothing here has been `nixos-rebuild`-tested** —
work through the checklist below on the NixOS box.

---

## 2026-08-06 (c) — four specialisations became one, and the sessions became sessions

Findings 2.1 and 1.2 of the Lamdan review, taken at the root rather than patched.

**Why.** A specialisation is a whole second system closure. Three of the four
were buying one with money they didn't need to spend:

- `hyprland` and `niri` were answering *"which session should the display
  manager start"* — which is the entire job description of a display manager.
  Both compositors install cleanly beside Plasma and register `.desktop`
  sessions through uwsm; SDDM lists them. The price of asking the bootloader
  instead was: every `nixos-rebuild` built all four closures, each was a GC
  root, and changing your mind about a compositor cost a reboot rather than a
  logout.
- `minimal` was answering *"how do I get a shell when the desktop is wedged"* —
  which systemd-boot already answers with ten kept generations, any of which
  boots the system you had *before* you broke it. And it was not minimal:
  specialisations inherit, so force-disabling xserver/sddm/plasma6 left
  pipewire, printing, flatpak, all 16 font packages and the whole of
  `cli-tools.nix`. Its home side didn't shrink either — `lib.mkIf false` around
  the home-manager block contributes nothing, it does not *retract* the
  parent's, so "recovery mode" still built GIMP, Krita, digiKam and darktable.
- `study` stays, and it is the whole reason the mechanism is in the repo: the
  radios are off and the firewall denies everything. That state genuinely
  cannot coexist with the base system at runtime.

**The bug the split was hiding, and it is worse than the review said.**
`home-manager.users.<name>` is a submodule, so two definitions of it *merge*.
The base set `users.shaul.imports = [ home/desktop.nix ]`; each specialisation
set `users.shaul.imports = [ its own profile ]`. Both were imported. **The
study specialisation was therefore running the full desktop profile
underneath its own** — tor-browser, qutebrowser and the entire graphics suite,
in the session whose stated purpose is not having them. That is fixed by
construction now: one import site, and a `shaulos.study` boolean the profile
branches on.

**And the drift the split had already produced**, all of it now structurally
impossible rather than individually patched:

| Was | Now |
|---|---|
| `p10k.nix` and `foot.nix` imported only by `desktop.nix`, while `common.nix` loads the p10k plugin and sources `~/.p10k.zsh` everywhere — so niri and study booted with an unconfigured prompt and an unconfigured `Mod+Return` terminal | one profile imports both |
| `dolphin` installed by the niri and study profiles; Hyprland is the session that binds `Mod+E` to it and is yazi's `reveal` opener. Invisible until you booted the one session with Plasma forced off | in `wayland-common.nix`, present in every session |
| **niri never auto-locked** — `lock-niri.nix` was three lines installing swaylock, no idle daemon, no timeout | one `lock.nix`: hyprlock + hypridle for both compositors |
| Hyprland's hypridle config was never started either — `lock-idle.nix` said "started via exec-once in Hyprland" and `hyprland.conf` had no such line. Both sessions shipped an idle config nothing ran | `spawn-at-startup "hypridle"` / `exec-once = hypridle`, explicitly |
| wlogout's stock layout hardcodes `swaylock`, installed in exactly one session — so the power menu's lock button did nothing under Hyprland | `programs.wlogout` with an explicit layout naming `hyprlock` |
| `hyprland.conf` hardcoded `monitor = , 1366x768@60, 0x0, 1` while niri used `output ".*" { scale 1.0 }` — plug in an external display and the sessions behaved differently, for no reason anyone chose | `monitor = , preferred, auto, 1` |
| `modules/system/{niri,hyprland}.nix` were the same file: 22 of ~30 non-blank lines byte-identical | `modules/system/wayland.nix`, imported by both; each compositor module is now four lines |

**Changed**

- `hosts/desktop/configuration.nix`: imports the three session modules; one
  `specialisation.study`; one home-manager import site. The per-specialisation
  portal lists are gone — plasma6, `programs.niri` and `programs.hyprland` each
  register their own backend and per-desktop `portals.conf` via
  `xdg.portal.configPackages`, which only works when they coexist.
- **Deleted:** `lib/mk-specialization.nix` (its only remaining caller was the
  one specialisation, and it carried three `lxqt` branches for a desktop
  environment nothing in the repo ever passed it), `modules/system/minimal.nix`,
  `modules/home/lock-idle.nix`, `modules/home/lock-niri.nix`,
  `home/desktop.nix`, `home/niri.nix`, `home/study.nix`.
- **New:** `modules/system/wayland.nix`, `modules/system/profile.nix`,
  `modules/home/lock.nix`, `home/shaul.nix`.
- `modules/home/wayland-common.nix` stopped being a function. It took an
  `xdgDesktop` argument to pin `XDG_CURRENT_DESKTOP`, and also pinned
  `WAYLAND_DISPLAY = "wayland-1"`. Both are gone: uwsm and SDDM set the former
  from the session's `DesktopNames`, and the compositor exports the latter. A
  hardcoded `WAYLAND_DISPLAY` in `home.sessionVariables` is a guess sourced by
  every login shell — i.e. a guess with the power to override the truth. It
  happened to be right.
- `modules/home/scripts.nix`: the `pgrep` compositor detection **stays**, and
  is now correct rather than merely harmless — one closure serves three
  sessions, so the compositor genuinely isn't knowable until the key is
  pressed. What changed is the silent fall-through: under Plasma, `spotlight`
  and `teleport` matched no branch and exited 0 having done nothing. They now
  say so.
- One-line rider, finding 3.2: `programs.firefox.enable = lib.mkForce false` in
  `study-offline.nix`. `cli-tools.nix` sets the *NixOS* option, which puts
  firefox in `environment.systemPackages`; the home-side `mkForce false` never
  touched it, so "offline airgap, no browsers" had a browser on `$PATH`.

**What this costs you.** One boot-menu entry (`minimal`) and two boot-menu
entries (`hyprland`, `niri`) disappear; the compositors move to the greeter.
`pcmanfm-qt` and `thunar` moved from the Hyprland module — which every session
imports now — to the non-study application list, so study mode loses two file
managers it never asked for. niri's `XCURSOR_SIZE = 12` override is gone; the
KDL's `cursor { xcursor-size 12 }` already did that job for the session that
wanted it.

**⚠ Not evaluated.** Authored off-machine as usual, but this one restructures
the module graph rather than editing leaves, so it is the change most likely to
fail at `nix flake check`. Run `just check`, then `just build`, before
`just switch`. Specifically worth watching: `programs.niri.enable` and
`programs.hyprland.enable` in one closure (they should merge cleanly — both
contribute to `xdg.portal.*` and `environment.sessionVariables` as lists or as
equal values), and `programs.wlogout`'s default CSS finding its icons.

**On the machine, in order**

```sh
just check                    # statix + deadnix + the emacs-config input
just build                    # full closure, no activation
just switch
# log out; SDDM should now list Plasma, Niri (uwsm) and Hyprland (uwsm)
# reboot only to reach `study` in the boot menu
```

Sanity checks after switching, one per drift row above: `which dolphin` in a
Hyprland session; `pgrep hypridle` in a niri session; `cat ~/.p10k.zsh` exists
in every session; `spotlight` under Plasma should now pop a notification rather
than nothing.

---

## 2026-08-06 (b) — the Emacs config moved to its own repo

Finding 1.1 of the Lamdan review, the other half. The config now lives at
**[github.com/SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config)**
and arrives here as a pinned flake input.

**Why.** By line count this was never a NixOS configuration that includes
Emacs — ~6,900 lines of Emacs config against ~2,300 of Nix. And it is
explicitly a different product: `init.el` advertises "ONE config, everywhere"
and carries `w32-pipe-read-delay`, `~/scoop/shims`, `C:/msys64` and a darwin
branch; `00-core` self-installs from MELPA on a bare box; `tools/deploy.sh`
exists to put it on a non-Nix machine and has to warn you away from the machine
this repo is named after.

**What that cost, and what's gone.** The store is read-only and the config
tangles `.el` next to `.org` at runtime, so `default.nix` staged the modules at
`~/.config/emacs/modules-src` and then ran an mtime-gated `cp` into a *writable*
`~/.config/emacs/modules`. That copy was a directory Nix did not own: no
rollback, no GC, and the sync only ever added. Edit a module in place and either
your edit silently became the live config while the repo went stale, or it was
clobbered with no backup — with nothing to tell you which. It also hid its own
failures: six untracked modules never entered the store at all, invisible
because the writable copy still had them from an earlier deploy.

The new repo's flake tangles **at build time**, so what lands here is an
immutable store symlink. The staging hop and the syncer are deleted.

**Changed here**

- `flake.nix`: new `emacs-config` input; `myConfig.emacsConfig` (pre-tangled
  config) and `myConfig.emacsPackage` (Emacs + package set) threaded to the one
  module that needs them. New `emacs-config` check so a bad input bump fails
  `nix flake check` rather than halfway through a switch.
- `modules/home/emacs/default.nix`: down to packages, `services.emacs`,
  `recoll.conf`, directory scaffolding, and three `home.file` symlinks.
- Removed: `init.el`, `early-init.el`, `modules/` (40 modules), `tools/`,
  `emacs-package.nix`, and the four Emacs READMEs — all now in the other repo,
  **with their history** (`git subtree split`).
- The `emacs-modules` / `emacs-bytecompile` checks added earlier today moved to
  the new repo, where they run in GitHub Actions on every push.
- `justfile`: `just update-emacs` bumps the input; `just emacs-dev [PATH]`
  rebuilds against a local checkout for a fast edit loop.

**The new edit loop.** Commit in `emacs-config` → `just update-emacs` →
`just switch`. Slower than editing in place; the trade is that the revision you
are running is written in `flake.lock` and can be rolled back. While actively
hacking, `just emacs-dev ~/emacs-config` skips the round trip entirely.

**⚠ Migration, read before switching.** `~/.config/emacs/modules` is currently a
real writable directory and becomes a store symlink. home-manager refuses to
clobber a real directory, so an activation step **moves it to
`~/.config/emacs/modules.pre-flake-input`** first. That is deliberate: under the
old scheme a hand-edit there could silently have become your live config, so
those files may be the only copy of something.

```sh
just update-emacs && just build      # dry build first
just switch
diff -ru ~/.config/emacs/modules.pre-flake-input ~/emacs-config/modules
# nothing you care about? then: rm -rf ~/.config/emacs/modules.pre-flake-input
```

---

## 2026-08-06 (a) — the seforim system was dead, and nothing could have told you

Acting on finding 1.1 of `lamdan/shaulos-config-2026-08-06.md`. This is the
root-cause fix, not the symptom fix.

**The symptom.** Five of the six seforim modules did not load — **1,569 of the
system's 1,775 lines.** No mefarshim linking, no search layer, no study log, no
bookmarks, no TOC, no reader mode, no dashboard. Only `10-seforim-core` (which
requires nothing) survived.

**Why.** A module's feature symbol *is* its filename. The essentials/extras
split renumbered the tree; `11`–`15` kept requiring the pre-split names
(`14a-seforim-core` …). Nothing provided those, `require` signalled, and
`init.el` caught it in `condition-case` — deliberately, so one broken module
can't take the session down. It logged one line to `*Messages*` and carried on.

**Why nothing caught it — this is the actual finding.** `tools/verify.sh`
existed the whole time and byte-compiles every module. It ended its pipeline
with:

```sh
... | grep -vE "…|Cannot open load file.*no such|…" || true
```

Three independent reasons it could never have helped: `|| true` pinned the exit
status at 0; even without it a pipeline reports `grep`'s status, not Emacs's;
and the filter dropped *the exact message an unresolvable `require` produces*.
`modules/README.md` claimed "`tools/verify.sh` will tell you if they drift." It
could not tell you anything. Wiring it into CI as it stood would have produced a
green check over 1,569 lines of dead elisp.

Meanwhile `nix flake check` ran statix and deadnix over `.nix` files only.
Nothing in this repo had ever looked at the elisp — which is ~3× the Nix
configuration by line count.

**What was fixed**

- The 12 stale `require` forms across `11`–`15`. Prose and `#+TITLE`s that
  referenced modules by *number* now reference them by *name*, since the
  numbers are the part that rots.
- Six `extras/*.org` modules were **untracked**: `01-hebrew-completion`,
  `02-hebrew-org`, `03-hebrew-typesetting`, `06-torah-search`,
  `16-seforim-integration`, `17-hydras`. A flake copies the *git tree* to the
  store, so they existed on exactly one machine — and the writable
  `~/.config/emacs/modules` sync never deletes, so that machine kept a stale
  copy from an earlier deploy and never noticed. Now tracked.

**What was fixed so it cannot happen again**

- **`tools/check-modules.sh`** (new) — static consistency over the module tree.
  No Emacs, no packages, no network, ~1 second. Verifies: `provide` matches
  filename and is unique; explicit `:tangle` target and `;;; name.el ---`
  header match; **every local `require` resolves to a module that exists**;
  dependencies point essentials → extras and never back, and only backwards in
  load order within a group; no orphaned `.el`; no `my/module-enabled-p`
  capability gate naming a module that isn't there; every `.org` tracked by git.
- **`tools/verify.sh`** — rewritten so it *can fail*. Emacs's exit status is
  captured before anything touches the pipeline, `Cannot open load file` is
  surfaced rather than hidden, and only genuine noise is filtered. It also no
  longer points `package-user-dir` at a non-existent `~/.emacs.d/elpa` on Nix,
  where the packages are on the Emacs binary's own load-path.
- **`nix flake check` now checks the elisp** — two new checks, `emacs-modules`
  (the static pass) and `emacs-bytecompile` (tangle + byte-compile against the
  real package set). `just check-emacs` and `just verify-emacs` run them
  directly.
- **`emacs-package.nix`** (new) — the Emacs package set, factored out of
  `default.nix`'s `let`. A verification job that compiles against a *different*
  package set than the one you run is verifying a lookalike; this makes the
  flake check build the identical Emacs.
- **`init.el`** — a failed module now raises `display-warning` at `:error`
  level, so the *Warnings* buffer pops and stays, instead of one line in
  `*Messages*` that scrolls away unread. `M-x my/load-report` lists what failed
  and why, and names `check-modules.sh` when the error looks like this one.
- **`.gitattributes`** (new) — `eol=lf` for `*.sh`/`*.nix`/`*.el`/`*.org`. Those
  scripts now execute inside a Nix build, and a CRLF shebang fails with `bad
  interpreter: /usr/bin/env^M`.

**Known limitation, stated deliberately.** This does *not* decouple module
identity from load order — renumbering still renames a module and still
invalidates every reference to it. Doing that properly means changing the
tangle target of all 40 modules, and it could not be tested from the Windows
mirror. What changed is that breaking the coupling is now **loud**: a renumber
that misses a dependant fails `nix flake check` instead of silently deleting a
subsystem. See `modules/README.md` → *Renumbering a module*.

**Verify on the machine.** Entry (b) above moved these tools into the
`emacs-config` repo, so run them there — `just check-emacs` / `just
verify-emacs` no longer exist here:

```sh
cd ~/emacs-config                  # or wherever you clone it
bash tools/check-modules.sh        # expect: "check-modules: 40 modules OK"
nix flake check                    # + the real tangle & byte-compile

cd ~/nixOS_config-specializations
just update-emacs && just switch
# then, in Emacs:  M-x my/load-report     → "All modules loaded cleanly."
#                  M-x seforim-mefarshim  → should exist
```

The byte-compile check is new and has never run. If it fails on a module that
`check-modules.sh` passes, that is a *real* finding — a syntax error, or a
`require` of a package missing from `emacs-package.nix` — not a false positive.

---

## Do this on the machine (in order)

1. **Lock the new inputs** (adds sops-nix and emacs-config). `flake.lock` was
   authored off-machine and has no entry for either — **nothing will evaluate
   until this runs**:
   ```sh
   nix flake lock
   ```
2. **Format + lint** to catch anything I couldn't:
   ```sh
   just fmt && just check     # nix fmt ; nix flake check (statix + deadnix)
   ```
   First `just check` may list pre-existing statix/deadnix findings — fix or ignore.
3. **Dry build** before switching:
   ```sh
   just build
   ```
4. **Switch**: `just switch`. Then reboot and test each specialisation from the
   systemd-boot menu (niri, hyprland, study, minimal).
5. **Emacs** — nothing to copy any more. The config is the `emacs-config` flake
   input and the modules arrive pre-tangled; see entry (b) at the top,
   including the one-time `modules.pre-flake-input` migration.
   ```sh
   just update-emacs      # lock the input
   ```
6. **Secrets (optional)** — follow `secrets/README.md` to set up sops-nix, then
   uncomment the secret blocks in `modules/system/secrets.nix`. Until then the
   secrets module is inert.

## Bugs fixed (were broken)

- `awww` → `swww` in niri + hyprland (the package `awww` does not exist — this
  was an evaluation error; wallpaper daemon + `swww img`).
- `modules/home/yazi.nix`: rewritten from malformed Lua (a non-existent config
  API, plus a `run = run =` typo) to the real `programs.yazi` TOML surface.
- Hyprland window rules: `match:class … float on` (unreleased syntax) →
  documented `windowrule = float, class:^(…)$` form; removed invalid Sway-style
  `preselect` binds.
- niri keyboard: `kb_options = …` → `options "…"` (valid KDL) so caps→escape and
  the layout toggle actually apply.
- `file-sync.nix`: `StartLimitBurst`/interval moved from `serviceConfig` (where
  systemd ignores them) to the Unit level.
- Emacs `services.emacs.client.arguments`: `"-a ''"` split into `"-a" ""`.
- Git email placeholder `shaul@example.com` → `myConfig.email` (real address).
- Wallpaper path unified to the nix-store path (was a hardcoded
  `/home/shaul/nixos-config/…` that broke if the repo moved).
- Rebuild alias uses `myConfig.flakePath` (was `~/nixos-config`, wrong name).

## Inefficiencies fixed

- **niri & study specialisations now import `common.nix`** — previously they
  booted with no zsh/p10k/aliases (silent shell regression).
- New `modules/home/wayland-common.nix` holds the shared Wayland toolkit that
  was copy-pasted across `home/niri.nix` and `home/study.nix`.
- **Removed double-started daemons**: mako/udiskie/waybar were launched by *both*
  the compositor module and a systemd user service. Now the compositor module is
  the single source (added `spawn-at-startup "mako"` to niri).
- `modules/home/palette.nix`: one source of truth for the Tokyo-Night ricing
  colors (were duplicated across waybar/lock/niri/hyprland).
- Removed the redundant `firefox` package entry (already enabled via
  `programs.firefox`), and the stale `combined.txt` dump.

## Added

- Repo hygiene: `.gitignore`, `README.md`, a `justfile`, and flake `formatter` /
  `checks` (statix + deadnix) / `devShells` — no new inputs required for these.
- Reproducible Emacs: repo-managed `modules/home/emacs/modules/*.org`, staged and
  copied to a writable dir so runtime tangling still works.
- sops-nix scaffold (input + guarded module + `.sops.yaml` + docs), inert until
  you create `secrets/secrets.yaml`.
- `modules/system/hardware.nix`: Bluetooth (+blueman), zram (zstd, 50%),
  `boot.tmp.cleanOnBoot`, thermald, and TLP power management.
- Flatpak (`services.flatpak.enable`) — portals were already configured.
- Hardened `study-offline.nix` into a genuine airgap: NM/wifi/Bluetooth off,
  firewall deny-all, and sshd/onedrive/file-sync disabled (also fixes the ~90s
  boot stall waiting on network-online.target).

## Deliberately NOT changed (flagged for you to decide)

- **Secure boot (lanzaboote)**: needs hands-on key enrollment (`sbctl`) and
  migrating off systemd-boot — too risky to wire blind. Do it as a focused pass.
- **Three overlapping sync tools**: `services.onedrive` + `onedriver` package +
  rclone file-sync. Pick the ones you actually use.
- **QT vs Stylix theming fight** (many `mkForce breeze`/`kde` in core + desktop):
  functional but messy; left alone to avoid regressing your Plasma look.
- **`nix-ld` `steam-run.args.multiPkgs` hack**: fragile across nixpkgs bumps but
  currently works — left as-is.
- `pkgs.ollama-cpu` — verified this attribute is valid; no change needed.

---

# 26.05 + Lix upgrade (2026-08-02)

Also authored off-machine — **untested**. Work through this on the NixOS box.

## Do this on the machine (in order)

1. **Relock.** Every input URL changed and `flake.lock` was already stale (it
   predates the sops-nix input, so it was never re-locked after that pass):
   ```sh
   just update            # nix flake update
   ```
2. **Build, don't switch.** This is a cross-release jump plus a new Nix
   implementation; the first build is large:
   ```sh
   just build
   ```
3. **Switch.** The nix-daemon restarts here as it becomes Lix:
   ```sh
   just switch
   ```
4. **Verify Lix took:**
   ```sh
   nix --version          # expect: nix (Lix, like Nix) 2.94.x
   ```
5. **Reboot** — you're crossing to a systemd stage-1 initrd and kernel 6.12 →
   6.18. If the new initrd misbehaves, pick the previous generation at the
   systemd-boot menu; `configurationLimit = 10` means it's still there.
6. Re-check the specialisations (`niri`, `hyprland`, `study`, `minimal`) boot —
   they're the least-exercised paths and plasma-manager/stylix churn lands there.

`nixos-version` will still say "current" — see the last note below.

## What changed

- **nixpkgs `nixos-unstable` → `nixos-26.05`.** The lock was pinned at ~2026-04-30,
  i.e. just *before* the 26.05 branch point, so this is a genuine upgrade, not a
  downgrade to stable. 26.05 "Yarara" is supported through 2026-12-31.
- **home-manager `master` → `release-26.05`**, **stylix `danth/stylix` →
  `nix-community/stylix#release-26.05`** (stylix moved orgs; its release branch
  must match nixpkgs + HM or you get option-set mismatches). Stylix now also
  `follows` our nixpkgs — previously it didn't, so the lock carried a second
  full nixpkgs (`nixpkgs_2`) just for stylix. One fewer eval, one fewer skew.
- **plasma-manager stays on `trunk`** — it has no release branches, only `trunk`,
  which targets home-manager *master*. It `follows` our pinned HM, so if trunk
  starts using an API that isn't in `release-26.05`, pin it to a rev. This is the
  single most likely thing to break on a future `just update`.
- **sops-nix stays on master** (no release branches; tracks nixpkgs, fine on stable).
- **New `nixpkgs-unstable` input.** The `unstable` special-arg is no longer a
  no-op alias for `pkgs` — it's a real second nixpkgs, threaded through
  `specialArgs` into the host config, every specialisation, and home-manager's
  `extraSpecialArgs`. Use it as `unstable.foo` for the odd package worth chasing.
- **Lix replaces CppNix**: `nix.package = pkgs.lixPackageSets.stable.lix`
  (Lix 2.94 in 26.05; `lixPackageSets.latest` is 2.95 if you want it). Lix is a
  fork of Nix 2.18 — same store layout, same store DB, same flake semantics, so
  there's no `/nix` migration and nothing gets re-downloaded. The daemon restarts
  during `switch`; that's the whole migration.

## Checked against the 26.05 backward-incompatibility list — no action needed

- `fileSystems.<name>.fsType` lost its default: both entries in
  `hardware-configuration.nix` already set it explicitly.
- systemd stage-1 initrd is now the default. No LUKS and no `/dev/root`
  references here, so nothing to adjust.
- `system.rebuild.enableNg` removed (bash `nixos-rebuild` is gone) — never set it.
- `linux_hardened` / `linux-rt` / `profiles/hardened` removed — none in use.
- `services.xserver` now *errors* on unknown `videoDrivers` instead of ignoring
  them — `videoDrivers` isn't set.
- dbus → dbus-broker by default; `services.dbus.enable` and
  `services.dbus.packages` are unaffected.
- `services.openssh.settings.AcceptEnv` now needs a list — not set.

## Deliberately NOT changed

- **`system.stateVersion` / `home.stateVersion` stay at `25.11`.** These are not
  version numbers to keep current — they declare which release's *stateful*
  defaults your existing data was created under. Bumping them silently changes
  service defaults out from under live state. Leave them until you rebuild the
  machine from scratch.
- **`system.nixos.version = "current"`** in `core.nix` is why `nixos-version`
  won't tell you you're on 26.05. Cosmetic, left alone — but that's the reason.
