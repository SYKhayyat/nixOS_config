# Decisions

Short records of choices that are deliberately not expressed as Nix code.

## 2026-11-18 — No backups yet (audit P0 #3)

`~/ksav` (156 GB), `~/shall` (109 GB) and `~/Documents` (101 GB) have no
remote copy. `modules/system/data.nix` only downloads.

**Decision:** do not add a `services.restic.backups` target with a placeholder
remote. A backup pointing at a destination nobody configured is worse than a
written gap: it looks like coverage. The target is still to be chosen
(external disk, NAS, or Backblaze B2 via rclone), and when it is, the module
goes in `modules/system/` with `restic check` scheduled and one restore
tested — not just one backup written.

This is the highest-value open item in the audit, and it is open on purpose.

## 2026-11-18 — Disk encryption deferred until backups work (audit P0 #3)

`hosts/desktop/hardware-configuration.nix` has plain ext4 and a swap
partition, no LUKS. Adding it needs a reinstall or a live `cryptsetup
reencrypt`, and neither is safe on the only copy of the data above.

**Decision:** encryption is not being added in this pass. The order is
backups first, then a tested restore, then LUKS. Do not treat this as an
omission: it is a conscious deferral with a stated precondition.

## 2026-11-18 — Three sessions: Plasma, Hyprland, sway

GNOME and niri were removed. GNOME was the audit's structural suggestion — the
comparison it existed for is done, and its tracker was indexing `$HOME` — and
niri went with it: its session was a third tiling compositor whose keys,
palette and bar had to be kept in step with Hyprland's for no answer Plasma or
Hyprland did not already give. sway stays as the i3-lineage second compositor.

**Decision:** `services.displayManager` offers Plasma (default), Hyprland and
sway. Adding a fourth back is an import in `hosts/desktop/configuration.nix`,
not a specialisation.

## 2026-11-18 — Emacs stays on stable 30.2, with the Compat package

`pkgs.emacs-pgtk` from 26.05, the Wayland build. So there is no unstable pin for
Emacs and no second Emacs in the closure.

The config does use API that arrived in Emacs 31 — corfu, vertico and consult
declare `(compat "31")` and call `set-local`, `incf`, `decf` — and the answer is
the GNU ELPA Compat package, not a newer Emacs. It is one dependency in the
config's `elpa/`, and it has to be `require`d in `lisp/core.el` before anything
completion-related loads, because Emacs 30.2 ships a *stub* `compat.el` that
provides the feature and nothing else while `lisp/emacs-lisp/` shadows `elpa/`.

**Decision:** the Emacs interpreter comes from nixpkgs stable; API compatibility
is a package the config owns. An unstable Emacs (a second Emacs, a second
`native-comp` cache, a second set of every package) buys nothing for it.

## 2026-11-18 — the Emacs configuration is a pinned flake input

`github:SYKhayyat/emacs-configs` is a flake input (`flake = false`), not the
`~/emacs-configs` checkout. A machine with an empty `$HOME` has to be able to
build a working Emacs, and the checkout was the last thing the build assumed —
and the one thing a fresh install does not have.

The store copy is read-only, and Emacs writes three things: `elpa/`,
`state/` (savehist, recentf, auto-save…) and `eln-cache/`. So `modules/home/emacs.nix`
builds `~/.local/share/emacs-configs` out of symlinks to the store plus those two
real directories, and the launchers export `EMACS_CONFIG_ROOT` so init finds it
(a symlink this file reads through would make `load-file-name` name the store).
Bumping the pin is `just update-emacs`, which is also the only way a change to the
config reaches this machine.

**Rejected:** copying the config into `$HOME` at activation (imperative, and it
drifts from the pin), and running straight from the checkout (not reproducible;
`just lock` would pin something the machine does not actually run).

## 2026-11-18 — sshd off, not keys-only (audit P0 #2)

This laptop is not a remote host; it joins untrusted networks. If that changes,
`modules/system/network.nix` is where to turn it back on — keys-only, root login
disabled, and with the reason written beside it.
