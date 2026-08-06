# ShaulOS — common tasks. Run `just` (or `just --list`) to see everything.
host := "desktop"

# List available recipes
default:
    @just --list

# Rebuild and switch the running system
switch:
    sudo nixos-rebuild switch --flake .#{{host}}

# Activate without adding a bootloader entry (safe to try things)
test:
    sudo nixos-rebuild test --flake .#{{host}}

# Build only — no activation
build:
    nixos-rebuild build --flake .#{{host}}

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

# Lint: statix (anti-patterns) + deadnix (dead code), and build the Emacs config
check:
    nix flake check

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

# Garbage-collect generations older than 14 days
gc:
    sudo nix-collect-garbage --delete-older-than 14d
    nix-collect-garbage --delete-older-than 14d

# Regenerate combined.txt (a single-file dump of all sources, e.g. to paste)
bundle:
    find . -name '*.nix' -not -path './.git/*' -exec sh -c 'echo "===== $1 ====="; cat "$1"; echo' _ {} \; > combined.txt
