# Audit — ShaulOS NixOS configuration

Date: 2026-11-18 · Repo at `8346188`

**Scope:** what should change *in this repository*. Each finding has a location, the problem and
the fix. Anything about the machine or other repos (home-directory data, caches, `~/emacs-configs`)
is in a short list at the end, because a commit here cannot fix it.

Baseline (measured): the flake evaluates, `statix` and `deadnix` pass, and
`tools/check-closure.sh /run/current-system` passes. The running system was behind HEAD at the
time of writing, so a `just switch` was pending; it landed the same day, and the closure then
measured **28.6 GB** (`study` 18.6 GB, `focus` 7.1 GB). The 39.5 / 26.6 / 13.4 GB figures below
are the pre-switch readings this audit worked from, not the current sizes.

---

## P0 — do first

### 1. The flake still builds the Emacs config you no longer use

You now run `~/emacs-configs` (profiles `hebrew`/`notes`/`ide`, packages in `elpa/`). No `.nix`
file mentions it. The flake still pins and builds the old config:

| Remove | Where |
|---|---|
| `inputs.emacs-config`, `inputs.doom-config`, `inputs.nix-doom-emacs-unstraightened` | `flake.nix` inputs; `myConfig.emacsConfig` (:519), `emacs-package.nix` import + `emacs30-pgtk` rename (:530-536), `myConfig.doomDir` (:545-560), Doom `hmModule` (:655-660), `checks.emacs-config` (:731) |
| Doom module | `modules/home/doom/`, its import at `home/shaul.nix:18` |
| Old Emacs module body | `modules/home/emacs/default.nix`: `${emacsConfig}` references, `EMACS_MODULE_GROUPS` (:371, :374), `services.emacs` (:376-383, including the dead `client` block), migration/bridge activation scripts. Also the duplicate `home.packages = [ emacs ]` (:183) |
| `EMACS_MODULE_GROUPS` env | `modules/home/hyprland/default.nix:432` |
| Packages only the old config used | `texlive.combined.scheme-full` (257 MB), `tinymist`, `tree-sitter`, `nil`, `lua-language-server`, `graphviz`; the enchant/hunspell/aspell + `DICPATH` exception in `base-tools.nix:67-85` |
| Recipes | `justfile`: `update-emacs`, `emacs-dev` |
| Stale assertion | `tools/check-closure.sh:377`: asserts that `recoll`/`xapian`/`hdate` are absent, because of the module groups being deleted |
| Docs | `README.md:715-` Emacs sections; the flake essay at `flake.nix:55-105` |
| Single-daemon callers | `keys.nix:231,305` (`emacsFrameArgv`), `yazi.nix` opener, `modules/system/focus.nix:186-190` (`cage` runs `emacsclient -a ""`) |

Target: `modules/home/emacs/default.nix` becomes about 50 lines. It installs one Emacs, puts
`~/emacs-configs/bin` on `PATH`, sets `EDITOR`, and adds three desktop entries. Don't make
`~/emacs-configs` a flake input (CI couldn't evaluate it), and don't copy it with `home.file`
(`elpa/` is written at runtime).

This also removes most of the 241 git fetches that make every eval take about 8 minutes. Those
fetches come from the old config's per-package pins.

### 2. sshd accepts passwords — `modules/system/network.nix`

Port 22 is open, with `PasswordAuthentication yes`, on a laptop that joins untrusted networks.
If you never ssh into this machine, set `services.openssh.enable = false`. Otherwise:

```nix
services.openssh.settings = {
  PasswordAuthentication = false;
  KbdInteractiveAuthentication = false;
  PermitRootLogin = "no";
};
```

### 3. Nothing backs up your data

`modules/system/data.nix` only downloads. No module uploads anything. Add
`services.restic.backups` for `~/ksav`, `~/shall` and `~/Documents` (366 GB, irreplaceable),
to a target you choose, with a periodic `restic check`. Test one restore. Disk encryption (no
LUKS in `hosts/desktop/hardware-configuration.nix`) needs a reinstall, which is only safe after
backups work. Decide it then, and write the decision down.

### 4. Nothing caps disk growth — `modules/system/core.nix`

The generated `nix.conf` has no `min-free`/`max-free` and `auto-optimise-store = false`. Nothing
caps the coredump store or the journal (868 MB and 2.6 GB today).

```nix
nix.settings = { auto-optimise-store = true; min-free = "5G"; max-free = "20G"; };
systemd.coredump.extraConfig = "MaxUse=200M";
services.journald.extraConfig = "SystemMaxUse=500M";
```

---

## P1 — small correctness fixes (about one commit)

| Where | Problem | Fix |
|---|---|---|
| `home/shaul.nix:250` | `~/.npm-global/bin` on `PATH` lets a stray `npm i -g` shadow the packaged CLIs | drop that entry |
| `modules/system/network.nix:66` | `/etc/hosts` pins a rotating Cloudflare IP for `omnirush.ai` | delete it; set `networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];` |
| `flake.nix:142` and `:632` | overlay list written twice (dev shell vs system), nothing keeps them equal | one `overlays` list, used in both places |
| `modules/system/wayland.nix:142` | `security.polkit.enable` duplicates `core.nix:161` | delete the `wayland.nix` one |
| `modules/system/hardware.nix:129` | `powerManagement.enable = true` is already the default | delete |
| `modules/system/development.nix:56` | `android_sdk.accept_license` with no Android SDK | delete |
| `modules/system/hardware.nix` | zram (50%) is full and swapping to NVMe; `swappiness = 180` makes that worse | `memoryPercent = 70`, `swappiness = 120`; add `MemoryHigh` on `ollama` |
| `modules/system/services.nix:32` | `updatedb` runs every hour over the whole disk | `"daily"` |
| `home/common.nix:236` | `nrs`/`nrt` call `python3`, which the `focus` closure doesn't have | use `${pkgs.python3}/bin/python3` or drop python |
| `modules/system/wayland.nix:136` | `hardware.acpilight` while brightness uses `brightnessctl` | delete |
| `modules/home/raw-editor-sources.nix:25` | unused `options` arg | delete |
| `.sentry-native/` | crash-telemetry files committed | `git rm -r`, add to `.gitignore` |
| `packages/*.nix` (npm CLIs) | `version` strings don't match the lock, and the "bump together" comment describes nothing real | delete the comment, or read the version from the lock |

---

## P2 — bloat

Biggest wins, by size, for apps that duplicate something else you keep (`modules/home/toolkit.nix`):

| Cut | Approx. size | Keep instead |
|---|---|---|
| `lighttable` (also ~90 lines inline in `flake.nix`) | 1.5 GB | darktable |
| `photon-studio` + 4 ArtCraft apps | ~1.5 GB | gimp / krita |
| `calligra`, `scribus`, `texmacs`, `sile` | 0.45 GB | LibreOffice |
| `ansel`, `filmulator`, one of `rawtherapee`/`art` | ~0.2 GB | darktable + one second opinion |
| `tor-browser`, `vlc`, `nushell`, `leo-editor`, `navi` | ~0.5 GB | `nix run` when needed |
| 8 of 12 search tools, 5 of 7 file managers | small | fd, rg, rga, plocate; yazi, dolphin |

That's about 4.5 GB from the main closure. Do one commit per family, so a mistake is one
`git revert`. Also in `modules/system/development.nix:30-52`, `nix-ld` loads both
`steam-run`'s `multiPkgs` and a hand-written list that mostly overlaps it. Keep one.

Structural: GNOME (and sway) are in every closure "to compare". If the comparison is done,
remove them. GNOME's tracker alone is indexing your home directory (4.1 GB cache).

---

## Not in scope here (outside this repo)

* **An Emacs crash loop:** 5,000+ coredumps, from one Konsole tab calling the *old* Nix Emacs
  with `--batch … package-alist` about 4,000 times a day. The stack (`__stack_chk_fail` in
  `__libc_early_init`) points to a glibc mismatch from that shell's `LD_*` env, not to memory
  pressure. Stop the loop, then vacuum `/var/lib/systemd/coredump`. The failed
  `drkonqi-coredump-processor` units are a side effect of this.
* **`~/emacs-configs/bin/launch.sh`:** the `--no-wait` / `env -u WAYLAND_DISPLAY` issues were
  measured on 30.2. Retest on 31.1. Never add `--no-wait` to the `$EDITOR` path.
* **Dead caches:** `~/.cache/tracker3` (4.1 G), `~/.cache/android-sdk` (2.4 G),
  `~/.local/share/io.github.kdroidfilter.seforimapp` (8 G).
* **sops:** the running generation has no `sops-install-secrets`, so `/etc/nix/tokens.conf`
  points at a missing file. After the next switch, check `ls /run/secrets/nix-access-tokens`.

## Left out on purpose

Repo reorganisation (renaming `home/`, splitting `desktop.nix`/`README.md`, a comment-ratio CI
gate, an in-file ordering convention) is a matter of style, not a defect. The one concrete
organisational bug, the duplicated overlay list, is in P1. Old post-mortem comments shrink
naturally as files are edited, and P0 #1 deletes the worst offenders.

## Decisions needed from you

1. Backup target: external disk, NAS, or cloud (B2 ≈ $2–4/month for this size)?
2. Do you ever ssh into this laptop?
3. Which of the duplicate apps in P2 do you actually use? Is GNOME/sway still needed?
4. Emacs 31 (unstable) or stable 30.2? If `~/emacs-configs` doesn't need 31, use stable.
