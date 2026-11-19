# Audit — ShaulOS NixOS configuration

Date: 2026-11-19 · Repo at `de9a296` plus the uncommitted working tree

**Scope:** the whole configuration as it is now, meaning the commits already in plus the
uncommitted move of Emacs to the pinned `emacsConfigs` input. Each finding gives a location, the
problem and the fix. Items about the machine or other repos come at the end, because a commit here
cannot fix them. The previous audit (2026-11-18, `8346188`) is in git history; its items are checked
off below.

How much each file was reviewed:

| Depth | Files |
|---|---|
| Read in full | `flake.nix`, `justfile`, `hosts/desktop/*`, every file in `modules/system/`, `home/shaul.nix`, `home/common.nix`, `home/focus.nix`, `modules/home/emacs.nix`, `toolkit.nix`, `wayland-common.nix`, `lock.nix`, `waybar.nix`, `scripts.nix`, `.github/workflows/check.yml`, `tools/check-docs.sh` |
| Read in part | `modules/home/keys.nix` (startup list, keyboard), `hyprland/default.nix` and `sway/default.nix` (startup, references), all of `packages/*.nix` (sources, hashes, wrappers, sandbox flags), `tools/check-closure.sh`, `tools/bump-omnirush.py` |
| Grep only | `konsole.nix`, `foot.nix`, `p10k.nix`, `yazi.nix`, `palette.nix`, `darktable.nix`, `lisp.nix`, `art.nix`, `raw-editor-sources.nix`, `statix.toml` |
| Also checked | the last 8 CI runs, the upstream `emacs-configs` source at `e679a50`, and the live machine (disk, swap, the runtime Emacs tree, user namespaces) |

**Baseline:**

| Gate | Result |
|---|---|
| `just lint` (statix, deadnix, docs check) | pass |
| `just eval` (toplevel, specialisation names, `focus`) | pass: `sx2f6x8n…`, `["focus","study"]`, `ppsxszj1…` |
| `just closure` locally | not run (~40 min) |
| **CI "the closure builds"** | **failed on every push since at least 2026-11-04**; see P0 |

Machine: `/` is 925 G with 688 G used (79%). `main` is one commit ahead of `origin`.

---

## P0 — the system cannot be built from scratch

### Quicklisp's fixed-output hash no longer matches, and CI has been red for two weeks

The last 7 runs of `check` all fail in the same place. The lint and eval jobs pass; the closure job
does not:

```
error: hash mismatch in fixed-output derivation '…-quicklisp-2026-01-01.drv'
error: 1 dependencies of derivation '…-home-manager-path.drv' failed to build
```

`packages/quicklisp.nix` is a fixed-output derivation that runs the Quicklisp bootstrap with
`:dist-version nil` (line 100), which means "whatever dist is current". The `outputHash` (line 64)
records one moment of that. Either Quicklisp published a new dist or the output holds build-time
`.fasl` files that differ between builds; both make the hash unstable. This machine still switches
only because the old output is kept alive by the current home generation. On a fresh install, or
after that generation is collected, `just switch` fails. `home-manager-path` depends on it, so the
whole system fails, not only Lisp.

Because CI has been red the whole time, no closure claim in `tools/check-closure.sh` has actually
been checked on any of these commits.

**Fix:** pin the dist and keep the output free of build artefacts:

1. Pass a dated dist to the bootstrap
   (`:dist-url "http://beta.quicklisp.org/dist/quicklisp/<date>/distinfo.txt"`), and make
   `version` that date.
2. Delete `*.fasl` and the cache directory from `$out` before the derivation finishes.
3. Rebuild once with `outputHash = lib.fakeHash` to get the new hash.

If that is more than Quicklisp is worth here, the alternative is to ship only `quicklisp.lisp` (a
plain `fetchurl`) and let `~/.sbclrc` run the install on first use, the way `elpa/` works for
Emacs.

---

## P1 — fix before committing the Emacs refactor

The design is sound. The config is pinned as a `flake = false` input, so CI can evaluate it. The
writable tree lives at `~/.local/share/emacs-configs`: store links go into it, `elpa/` and `state/`
are real directories, and every upstream entry point honours `EMACS_CONFIG_ROOT`. Profiles are
discovered from `configs/`. The runtime tree works: `elpa/` has 49 directories (33 M), and its
`packages.lock` matches `lisp/packages.el` (46 packages). The three problems below are about how
the tree behaves after the first install.

### 1. The docs give the wrong command for updating the Emacs config

`README.md:740` says "pushing to that repository, then `just lock` and `just switch`".
`docs/ONBOARDING.md:296` says `just lock  # after pushing to the config repository`. But `just lock`
is `nix flake lock`, which pins only *missing* inputs. So you push, run `just lock`, switch, and
nothing changes. The correct recipe is `just update-emacs`, which `docs/DECISIONS.md` and the
justfile already name.

**Fix:** replace `just lock` with `just update-emacs` in both places. `tools/check-docs.sh` checks
that named paths exist, not what commands do, so CI cannot catch this.

### 2. Activation installs packages only when `elpa/` is empty

The `createEmacsConfigRoot` activation in `modules/home/emacs.nix` runs `emacs-install` only when
`ls -A elpa` is empty. The comment at `modules/home/emacs.nix:65` and `README.md:742` say it also
runs on "the first switch after the input changed". It does not. Two consequences:

* A package added to `lisp/packages.el` upstream is not installed after
  `just update-emacs && just switch`. Any profile that `require`s it fails at startup until you run
  `emacs-install` by hand.
* If an install fails partway, `elpa/` is no longer empty, so the install is never retried.

**Fix:** write a stamp only on success, and re-run the install whenever the stamp is out of date:

```nix
home.activation.createEmacsConfigRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  run mkdir -p "${emacsConfigRoot}/elpa" "${emacsConfigRoot}/state"
  stamp="${emacsConfigRoot}/state/installed-from"
  want="${emacsConfigSource}"
  if [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
    if run ${pkgs.coreutils}/bin/timeout 600 ${emacsInstall}/bin/emacs-install; then
      run sh -c 'echo "$1" > "$2"' _ "$want" "$stamp"
    else
      echo "emacs: package install failed; run 'emacs-install' when the network is back" >&2
    fi
  fi
'';
```

To re-run only when the package list changes, not on every pin bump, stamp with
`builtins.hashFile "sha256" "${emacsConfigSource}/lisp/packages.el"` instead. Then update both
comments so they describe what the code does.

### 3. On a new machine, the first install can fail with no visible sign

On a fresh install, activation runs during the first `switch` or at boot, possibly before the
network is up. The install has no timeout, and its failure message goes only to the journal. The
launchers then start Emacs against an empty `elpa/`, and the first minibuffer errors out.

**Fix:** add the `timeout` from #2. Have the launcher (`emacsLauncher` in `flake.nix`) print one
line to stderr when `$EMACS_CONFIG_ROOT/elpa` is empty, for example "packages not installed — run
emacs-install".

---

## P2 — correctness, security and drift

| Where | Problem | Fix |
|---|---|---|
| `home/common.nix:140` (`clearStaleBackups`) | Runs `find "$HOME" -type f -name '*.hm-bak' -delete` before every activation, which happens on every switch and every boot. Measured here: **50 s** to walk the 366 G home. It also deletes the backups `home-manager.backupFileExtension` exists to keep, so a file Home Manager moved aside is gone on the next switch, before you have looked at it | Limit the search to where Home Manager writes (`~/.config`, `~/.local/share`, and `-maxdepth 1` on `~`), or drop the step and set `home-manager.backupCommand` to name each backup with a timestamp |
| `packages/omnirush-gui.nix:172` | The wrapper always passes `--no-sandbox`. The reason given at line 33 ("NixOS has no unprivileged user namespaces by default") is not true on this machine: `unshare -Ur true` succeeds. So the Chromium sandbox is off for no reason, in an app that renders remote content | Use the same probe `packages/deepai-code.nix` already uses: pass `--no-sandbox` only when `unshare -Ur true` fails. Correct the comment |
| `flake.nix:338` | `emacsConfigRoot = "/home/shaul/.local/share/emacs-configs"` hardcodes the home path, although `myConfig.homeDir` exists. `emacs.nix` derives `dataRel` with `lib.removePrefix`; if the two ever differ, that silently returns an absolute path and `home.file` fails confusingly | `"${homeDir}/.local/share/emacs-configs"` |
| `modules/home/emacs.nix` (`links`) | `profiles` is discovered from `configs/`, but the top-level links (`lisp`, `vendor`, `bin`, `test`) are hand-listed. A new top-level directory upstream is silently missing from the runtime tree | Derive the list from `readDir` of the source, or assert that each linked name exists |
| `modules/home/emacs.nix:32` vs upstream `bin/launch.sh` | The comment says "a profile added upstream needs no change in this repository". That is true for the Nix side, but `launch.sh` hardcodes `case hebrew\|notes\|ide`. A fourth profile gets a launcher and a desktop entry that exit with status 2 | Fix upstream (accept any directory under `configs/`), or soften the comment |
| `modules/home/emacs.nix` (activation) | `mkdir` and the install don't run through Home Manager's `run`, so `--dry-run` still does the network install | Wrap them in `run` (as in the P1 #2 snippet) |
| `modules/system/base-tools.nix:59` | `home-manager` is installed as "the repair tool" for a home profile that fails to build. But Home Manager runs as a NixOS module here, and `flake.nix` has no `homeConfigurations`, so `home-manager switch` has nothing to build. The repair is `nixos-rebuild` or `just switch`. The CLI is still useful for `home-manager generations` | Keep it, but change the comment to say what it is for, or drop it |
| Stale comments about removed components | `modules/system/appearance.nix:117-124` (`01-ui.el`, `emacs --fg-daemon`, `../home/emacs/default.nix`, which is deleted) and `:261` ("its 30 files"); `tools/check-closure.sh:244` (`modules/home/emacs/default.nix`); `.github/workflows/check.yml:38` ("the same version emacs-config uses"); `flake.nix:473`; `modules/system/study-offline.nix:18` and `base-tools.nix:30` (`~/emacs-configs`). `modules/home/scripts.nix:197` and `hyprland/default.nix:63, 189, 409` describe niri, which has been removed, as if it were still installed | Rewrite or delete them. `tools/check-docs.sh` only reads `.md` files, so drift in `.nix` comments is never caught. Running `path_claims` over `*.nix` and `*.sh` too would have caught three of these |
| `CHANGES.md:115` | "installs all 66 packages from the pinned list" — `lisp/packages.el` lists 46, and 46 are installed | Say 46, or drop the number |
| `packages/quicklisp.nix:51` | `version = "2026-01-01"` is a label, not what was fetched (see P0) | Make it the pinned dist's date |
| Upstream `packages.lock` | Stale: 63 entries against 46 in `packages.el`. It is not linked, so it does no harm here, but it misleads anyone reading it | Regenerate or delete it upstream |

---

## P3 — hygiene

* **Two changes in one working tree.** The OmniRush bump (`packages/omnirush.nix` 3.0.4 → 3.0.6,
  written by `_omnirush-bump`) is mixed into the Emacs refactor diff. Commit it separately.
* **Every rebuild builds an uncommitted tree.** `switch`, `test` and `build` run `_omnirush-bump`
  first, so every generation comes from a tree git has not seen. The justfile accepts this by
  design. The cheap mitigation is to commit the bump right after a switch succeeds.
* **Two rebuild paths.** The `nrs` and `nrt` aliases (`home/common.nix:239-240`) copy the
  justfile's bump-then-rebuild logic by hand, and `nfu` updates every input, outside the
  `just lock` / `just update-*` rule. Make the aliases call `just switch`, `just test` and
  `just update`, so the policy lives in one place.
* **`clean` removes every rollback** (`home/common.nix:252`): `nix-collect-garbage -d` deletes all
  old generations, including the boot entries you would fall back to. Use
  `nh clean all --keep 3` (nh is installed) or `--delete-older-than 14d`, which matches
  `nix.gc`.
* **The CI badge cannot be trusted until P0 is fixed.** Every push gets a red build, so a new
  regression would look the same as the old one. After the fix, consider
  `cachix/install-nix-action@v31` (you are on v27) and a binary cache, so the 120-minute job stops
  rebuilding darktable each time.
* **Push `de9a296`.** CI has not seen it.

---

## Status of the 2026-11-18 audit

| Item | Status |
|---|---|
| P0 #1 Old Emacs/Doom inputs, modules, recipes, checks | **Done.** Replaced by the `emacsConfigs` input (see P1 above) |
| P0 #2 sshd with passwords | **Done.** sshd is off; the firewall is on with no open ports |
| P0 #3 Backups | **Open by decision.** `docs/DECISIONS.md` says no restic yet. `data.nix` still only downloads |
| P0 #4 Disk caps | **Done.** `min-free`/`max-free` are in bytes (Lix), auto-optimise is on, journald and coredump are capped |
| P1 `~/.npm-global/bin` on `PATH` | Done |
| P1 `omnirush.ai` hosts pin; nameservers | Done (1.1.1.1, 9.9.9.9) |
| P1 duplicate polkit | Done. One `security.polkit.enable` (core.nix) and one agent (polkit-gnome, Hyprland and sway only; Plasma brings its own) |
| P1 `powerManagement.enable`, `android_sdk`, `acpilight` | Done |
| P1 zram/swappiness, `MemoryHigh` on ollama | Done (70%, 120, 4 G) |
| P1 `updatedb` hourly | Done (daily) |
| P1 `nrs`/`nrt` bare `python3` | Done (`pkgs.python3`); see P3 for the duplicated logic |
| P2 duplicate apps | Done |
| P2 `nix-ld` double list | Done (`steam-run` `multiPkgs` only) |
| LUKS | **Deferred** until backups exist (unchanged) |

Checked and found fine: hibernate (12.5 G disk swap ≥ 11 G RAM, and NixOS resumes from
`swapDevices` without `boot.resumeDevice`); sops (`secrets.yaml` and `.sops.yaml` are tracked, one
secret); both GitHub repos the config fetches without credentials (`emacs-configs` and
`typed_notes`) are public, so CI and the data bootstrap can reach them; `bump-omnirush.py` takes
hashes from npm's `dist.integrity` and the release's `SHA256SUMS.txt` rather than computing them,
with timeouts and retries.

---

## Not in scope here (outside this repo)

* **Old checkout:** `~/emacs-configs/elpa` (39 M) is no longer used; the runtime tree has its own
  `elpa/`. Keep the checkout for editing, but its `elpa/` can go.
* **Dead caches:** `~/.cache/tracker3` (4.0 G), `~/.cache/android-sdk` (2.4 G),
  `~/.local/share/io.github.kdroidfilter.seforimapp` (8.0 G). About 14 G of the 79%.
* **Coredumps:** down to 3 files. The crash loop from the last audit is gone.
* **sops on a fresh install:** `secrets.nix` turns sops off silently when the secrets file is
  missing, and `core.nix` `!include`s `/etc/nix/tokens.conf`, a link into `/run/secrets`. Check
  `ls -l /run/secrets/nix-access-tokens` after a reinstall, because nothing else will warn you.

## Status of this audit (implemented 2026-11-19)

| Item | Status |
|---|---|
| P0 Quicklisp FOD | **Done.** `packages/quicklisp.nix` is only the bootstrap file (stable hash); `lisp.nix` runs it into `~/.local/share/quicklisp` at activation, once, with a timeout and a retry |
| P1 #1 update command in the docs | Done. `just update-emacs`, then `just switch` |
| P1 #2 install only when `elpa/` is empty | Done. `state/installed-from` stamps the source; the install re-runs whenever the pin moves |
| P1 #3 silent first-install failure | Done. `timeout 600`, a stderr warning, a retry on the next switch, and the launcher warns when `elpa/` is empty |
| P2 `emacsConfigRoot` hardcodes `$HOME` | Done (`homeDir`) |
| P2 hand-listed links | Done. Derived from the source's top-level directories |
| P2 `launch.sh` profile list | Done upstream (`7d4ded6`): any directory under `configs/` |
| P2 `run` around activation writes | Done |
| P2 `clearStaleBackups` | Replaced. Timestamped `home-manager.backupCommand`, and `gtk.gtk2.force` for the one file that was clobbered on every switch |
| P2 OmniRush GUI `--no-sandbox` | Done. Only when `unshare -Ur true` fails |
| P2 `home-manager` "repair tool" comment | Done. Kept for `generations`/`news` |
| P2 stale comments | Done, all listed sites. `check-docs.sh` over `*.nix` was **not** done |
| P2 `CHANGES.md` 66 packages, upstream `packages.lock` | Done (46; regenerated upstream) |
| P3 `nrs`/`nrt`/`nfu` | Done. They call `just switch`/`test`/`update` |
| P3 `clean` | Done. `nh clean all --keep 3` |
| P3 `install-nix-action` | Done (`v31`). No binary cache added |
| Q4 Backups | **Still open** |

Verified locally: `just lint`, `just eval`, the full closure build and `tools/check-closure.sh`.

## Decisions needed from you

1. Quicklisp (P0): pin a dist inside the derivation, or ship only the bootstrap and install at
   runtime?
2. Emacs activation stamp (P1 #2): re-install on every pin bump, or only when `packages.el`
   changes?
3. Should `launch.sh` upstream accept any profile directory, or should the Nix side stop promising
   that new profiles work?
4. Backups are still the largest risk outside the build (366 G under `~/ksav`, `~/shall` and
   `~/Documents`). Is there a target yet?
