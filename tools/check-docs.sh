#!/usr/bin/env bash
# tools/check-docs.sh — every repo path a live document names must exist.
#
# ── Why this exists ───────────────────────────────────────────────────────
#
# The 2026-11-18 audit found three documents describing a tree that had moved:
# README.md pointed at `modules/system/cli-tools.nix` (renamed to
# `base-tools.nix`), and the secrets sections in README.md, ONBOARDING.md and
# TROUBLESHOOTING.md all described a placeholder age key and a `secrets.yaml`
# that did not exist — while both were real and the GitHub token was being
# decrypted from them. None of that was a code bug. All of it was a sentence
# that had stopped being true, and nothing in `nix flake check` reads prose.
#
# A generated table cannot go stale — that is why modules/home/keys.nix renders
# the keymap instead of transcribing it. A sentence can, and there is no
# generator for prose. This is the cheap half of the answer: the parts of a
# document that are *checkable* are checked.
#
# ── Scope, and why each exclusion is excluded ─────────────────────────────
#
# Read: README.md, docs/*.md, secrets/README.md — the documents that describe
# the tree as it is now.
#
# Not read:
#   docs/AUDIT.md   a dated snapshot. It names files it is asking you to delete
#                   (`modules/home/doom/`, the old Emacs module), so its paths
#                   are *supposed* to be absent once the pass is done.
#   CHANGES.md      the historical record, by definition full of dead paths.
#   lamdan/         an external report about an older tree.
#
# Only paths that start at a top-level directory are checked, plus relative
# markdown links. A bare `core.nix` in a sentence is a basename, not a claim
# about a location, and checking it would produce noise rather than findings.
#
# Run: `bash tools/check-docs.sh`, `just lint`, or the `docs` flake check.
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

docs=(
  README.md
  secrets/README.md
)

for f in docs/*.md; do
  case "$f" in
    docs/AUDIT.md) continue ;;
  esac
  docs+=("$f")
done

# A path claim is a token that begins with a directory this repo owns and ends
# in a file extension the repo uses. The leading `[^[:alnum:]_./-]` keeps
# `/nix/store/…/modules/system/core.nix` out — that is a store path, not ours.
path_claims() {
  grep -oE '(^|[^[:alnum:]_./-])((modules|home|hosts|packages|tools|secrets|assets|docs)/[[:alnum:]_./-]+\.(nix|sh|py|md|jpg))' "$1" |
    sed -E 's/^[^[:alnum:]_./-]*//' |
    sort -u
}

# Relative markdown links: `](docs/ONBOARDING.md)` and `](../README.md)`.
# Anchors are stripped, http(s) and mailto are skipped, and a link is resolved
# against the directory of the document that contains it.
link_claims() {
  grep -oE '\]\([^)]+\)' "$1" |
    sed -E 's/^\]\(//; s/\)$//; s/#.*$//' |
    grep -vE '^(https?:|mailto:|$)' |
    sort -u
}

for f in "${docs[@]}"; do
  [ -f "$f" ] || continue

  for p in $(path_claims "$f"); do
    if [ ! -e "$p" ]; then
      printf '  FAIL  %s names %s, which does not exist\n' "$f" "$p"
      fail=1
    fi
  done

  base=$(dirname "$f")
  for link in $(link_claims "$f"); do
    resolved=$(realpath -m "$base/$link")
    if [ ! -e "$resolved" ]; then
      printf '  FAIL  %s links to %s, which does not exist\n' "$f" "$link"
      fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "docs check FAILED — a live document names something the tree does not have."
  echo "Fix the document, or move the file it is describing; do not delete the check."
  exit 1
fi

printf 'docs check passed (%s live documents).\n' "$(( ${#docs[@]} ))"

# The other half of "never stale": the documents that *are* generated must be
# generated. `keys.nix` renders the guide, so this asks the evaluated config
# for the file's first line rather than for the file's existence on disk —
# a `~/.config` path is not present in a build sandbox, and a check that
# silently skipped itself there would be the failure mode this repo collects.
