# Overhaul — what changed and what you must do next

This pass fixed build-blocking bugs, de-duplicated the config, added repo tooling,
made Emacs reproducible, and added laptop hardware + a real study airgap.
It was authored off-machine, so **nothing here has been `nixos-rebuild`-tested** —
work through the checklist below on the NixOS box.

## Do this on the machine (in order)

1. **Lock the new input** (adds sops-nix):
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
5. **Make Emacs reproducible** — move your literate modules into the repo once:
   ```sh
   cp ~/.config/emacs/modules/*.org modules/home/emacs/modules/
   ```
   (see `modules/home/emacs/modules/README.md`)
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
- **`unstable` special-arg** is a no-op (equals `pkgs`); kept for signature
  compatibility. A true stable/unstable split would be a separate change.
- `pkgs.ollama-cpu` — verified this attribute is valid; no change needed.
