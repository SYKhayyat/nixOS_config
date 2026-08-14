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

# The compositors are NOT here — they are greeter sessions, pick them at login.

# Show which specialisations exist for next boot (`study` and `focus`)
specialisations:
    @ls /run/current-system/specialisation 2>/dev/null || echo "none active"

# Update every flake input and show the diff
update:
    nix flake update

# `--no-update-lock-file` here too: `nix fmt` resolves the flake to find the
# formatter, so without it this recipe was the one hole in the rule stated at
# the top of this file — a command nobody thinks of as touching the lock, which
# is precisely the kind that does.
#
# NOTE on the one-line comments below: `just --list` is the default recipe, so
# it is what you see every time you type `just`, and it uses only the LAST
# contiguous comment block above a recipe. A blank line therefore separates the
# reasoning from the summary — without it, `--list` prints the closing sentence
# of an essay as the description, which is how this file used to advertise
# `check` as "carries on, which is how flake.lock came to account for four of
# six."

# Format all .nix files (RFC style)
fmt:
    nix fmt --no-update-lock-file

# `--no-update-lock-file` is the part that makes this honest — without it nix
# quietly resolves an input the lock does not pin and carries on, which is how
# flake.lock came to account for four of six.
#
# This is the SLOW one: `nix flake check` runs all four checks, and the fourth
# is the closure build. Reach for `just lint` or `just eval` first.

# Everything CI checks (statix, deadnix, Emacs, the closure) — slow, ~40m
check:
    nix flake check --no-update-lock-file --print-build-logs

# This exists because README.md's CI table used to offer `just check` as the
# by-hand equivalent of CI's `lint` job, and `just check` is `nix flake check`:
# all four checks, including the closure build. The table was telling you a
# 40-minute command was a 2-minute one. Now the row is true.

# statix + deadnix, and nothing else — CI's `lint` job, ~2m
lint:
    nix build --no-link --print-build-logs --no-update-lock-file \
        .#checks.x86_64-linux.statix \
        .#checks.x86_64-linux.deadnix

# All three of the things CI's `eval` job proves, not one.
#
# Step 1 forces the entire module system: every option type, every `pkgs.<name>`,
# both compositors, plasma-manager, and `study` (an inheriting specialisation is
# reachable from `system.build.toplevel` via its `children`). Minutes, not tens
# of minutes, and it is what catches the class of bug this config has actually
# shipped.
#
# Steps 2 and 3 are here because step 1 alone is not what the README said it
# was, and that was proven by construction: deleting the entire
# `specialisation.focus` block from hosts/desktop/configuration.nix left step 1
# **green** — it emitted a drvPath and noticed nothing — while CI went red. The
# config could silently lose a whole specialisation and the documented local
# gate passed.
#
# Step 3 is the one that is not belt-and-braces either. `focus` is built with
# `inheritParentConfig = false`, so it is a separate module-system evaluation
# with its own import list; forcing the parent's toplevel forces `study`'s but
# says nothing about a broken import inside `focus`.

# The fast gate: force the whole module system + both specialisations, build nothing
eval:
    @nix eval --raw --no-update-lock-file .#nixosConfigurations.{{host}}.config.system.build.toplevel.drvPath
    @echo
    @echo "── the specialisations are the ones we think ──"
    @got=$(nix eval --json --no-update-lock-file .#nixosConfigurations.{{host}}.config.specialisation --apply builtins.attrNames); \
        echo "specialisations: $got"; \
        test "$got" = '["focus","study"]' || { \
            echo 'FAIL: expected exactly ["focus","study"] — see README, "The two specialisations"'; \
            exit 1; \
        }
    @echo "── the focus specialisation evaluates ──"
    @nix eval --raw --no-update-lock-file .#nixosConfigurations.{{host}}.config.specialisation.focus.configuration.system.build.toplevel.drvPath
    @echo

# Build the closure, then ask it whether it is the machine README.md describes:
# no browser is a system package in any closure, `study` has none of them at
# all and its radios are genuinely off, neither specialisation generates a
# `dhcpcd.service`, and the seforim stack agrees with EMACS_MODULE_GROUPS.

# Build the closure and assert what it claims about itself — slow, ~40m
closure:
    nix build --print-build-logs --no-update-lock-file .#checks.x86_64-linux.toplevel
    bash tools/check-closure.sh ./result

# What you run after adding an input to flake.nix. Nothing else will do it for
# you any more, on purpose — see the rule at the top of this file.

# Re-lock the inputs without changing their versions
lock:
    nix flake lock
    @git diff --stat flake.lock

# The config lives in its own repo (github:SYKhayyat/emacs-config); this is how
# its changes reach this machine.

# Bump the emacs-config input and show the move
update-emacs:
    nix flake update emacs-config
    @git diff --stat flake.lock

# No commit, no push, no input bump. Undo with `just update-emacs`.
#
# This is the one recipe without `--no-update-lock-file`, and it is safe:
# `--override-input` makes nix print "not writing modified lock file" and leave
# it alone. Verified, not assumed.

# Rebuild against a local emacs-config checkout, for a fast edit loop
emacs-dev path="/home/shaul/emacs-config":
    sudo nixos-rebuild switch --flake .#{{host}} \
        --override-input emacs-config path:{{path}}

# Idempotent: it checks for files, not directories, and skips what it finds.
# A timer also runs this 2 minutes after boot — this is for when you've just
# finished `rclone config`, or a fetch failed and you fixed the reason.

# Fetch ~/Documents from Google Drive + GitHub if it isn't there yet
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
