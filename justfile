# ShaulOS — common tasks. Run `just` (or `just --list`) to see everything.
host := "desktop"

# List available recipes
default:
    @just --list

# ── One rule, and it is the only reason `--no-update-lock-file` is below ──
#
# Nothing in this file may change flake.lock except `just lock`.
#
# Without the flag, nix resolves an input the lock does not pin, writes the
# entry and carries on — so you switch to a system built from inputs that are
# not the ones you committed, and nothing prints. That is not hypothetical:
# flake.nix declared six inputs and flake.lock pinned four for fourteen entries,
# and the only thing that knew was a line in CHANGES.md.
#
# nixos-rebuild does not parse this flag itself; it forwards what it does not
# recognise to `nix build`, which is the same route `emacs-dev` below already
# takes with `--override-input`.

# Rebuild and switch the running system
switch:
    sudo nixos-rebuild switch --flake .#{{host}} --no-update-lock-file

# Activate without adding a bootloader entry (safe to try things)
test:
    sudo nixos-rebuild test --flake .#{{host}} --no-update-lock-file

# Build only — no activation
build:
    nixos-rebuild build --flake .#{{host}} --no-update-lock-file

# Show which specialisations exist for next boot (there is one: `study`).
# The compositors are NOT here — they are greeter sessions, pick them at login.
specialisations:
    @ls /run/current-system/specialisation 2>/dev/null || echo "none active"

# Update every flake input and show the diff
update:
    nix flake update

# Format all .nix files (RFC style)
fmt:
    nix fmt

# Everything CI checks, in one command: statix, deadnix, the Emacs config, and
# the whole system closure. `--no-update-lock-file` is the part that makes it
# honest — without it nix quietly resolves an input the lock does not pin and
# carries on, which is how flake.lock came to account for four of six.
check:
    nix flake check --no-update-lock-file --print-build-logs

# The fast gate. Forces the entire module system — every option type, every
# `pkgs.<name>`, both compositors, plasma-manager, the specialisation — and
# builds none of it. Minutes, not tens of minutes, and it is what catches the
# class of bug this config has actually shipped.
eval:
    @nix eval --raw --no-update-lock-file .#nixosConfigurations.{{host}}.config.system.build.toplevel.drvPath
    @echo

# Build the closure, then ask it whether it is the machine README.md describes:
# no browser is a system package in any closure, `study` has none of them at
# all, and `study` still has the tools it is supposed to keep.
closure:
    nix build --print-build-logs --no-update-lock-file .#checks.x86_64-linux.toplevel
    bash tools/check-closure.sh ./result

# Re-lock the inputs without changing their versions — what you run after adding
# one to flake.nix. Nothing else will do it for you any more, on purpose.
lock:
    nix flake lock
    @git diff --stat flake.lock

# Pull the latest Emacs config (github:SYKhayyat/emacs-config) and show the move.
# The config lives in its own repo; this is how its changes reach this machine.
update-emacs:
    nix flake update emacs-config
    @git diff --stat flake.lock

# Point the Emacs config at a local checkout for a fast edit loop — no commit,
# no push, no input bump. Undo with `just update-emacs`.
emacs-dev path="/home/shaul/emacs-config":
    sudo nixos-rebuild switch --flake .#{{host}} \
        --override-input emacs-config path:{{path}}

# Fetch ~/Documents from Google Drive + GitHub if it isn't there yet.
# Idempotent: it checks for files, not directories, and skips what it finds.
# A timer also runs this 2 minutes after boot — this is for when you've just
# finished `rclone config`, or a fetch failed and you fixed the reason.
bootstrap-data:
    sudo systemctl start shaulos-data-bootstrap.service
    @journalctl -u shaulos-data-bootstrap.service -n 30 --no-pager

# Garbage-collect generations older than 14 days
gc:
    sudo nix-collect-garbage --delete-older-than 14d
    nix-collect-garbage --delete-older-than 14d

# Regenerate combined.txt (a single-file dump of all sources, e.g. to paste)
bundle:
    find . -name '*.nix' -not -path './.git/*' -exec sh -c 'echo "===== $1 ====="; cat "$1"; echo' _ {} \; > combined.txt
