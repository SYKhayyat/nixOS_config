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

## 2026-11-18 — Emacs stays on stable 30.2

`pkgs.emacs-pgtk` from 26.05, the Wayland build. `~/emacs-configs` does not need
31, so there is no unstable pin for Emacs and no second Emacs in the closure.

## 2026-11-18 — sshd off, not keys-only (audit P0 #2)

This laptop is not a remote host; it joins untrusted networks. If that changes,
`modules/system/network.nix` is where to turn it back on — keys-only, root login
disabled, and with the reason written beside it.
