#!/usr/bin/env bash
# Publish this canonical config to a user-emacs-directory.
#   init.el, early-init.el          -> <target>/
#   modules/<group>/NN-*.{el,org}   -> <target>/modules/<group>/   (clean mirror)
# The previous init/early-init/modules are backed up first.
#
# Usage: deploy.sh [target-emacs-dir]
#   default target: ~/.emacs.d on Windows, ~/.config/emacs elsewhere.
#
# Do NOT point this at ~/.config/emacs on NixOS: home-manager owns init.el there
# as a read-only store symlink and the copy will fail or fight it.
#
# The module copy used to glob "$DIR"/[0-9]*.{el,org} -- the config root, which
# has held no modules since they moved into modules/ -- so it deployed the
# loader and nothing else, then reported a module count from the OLD target.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODROOT="$DIR/modules"

if [ $# -ge 1 ]; then
  TARGET="$1"
elif [ "${OS:-}" = "Windows_NT" ]; then
  TARGET="$HOME/.emacs.d"
else
  TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
fi

[ -d "$MODROOT" ] || { echo "no modules dir at $MODROOT" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$TARGET/.backup-$STAMP"
mkdir -p "$TARGET/modules" "$BACKUP"

echo "Deploying $DIR -> $TARGET  (backup: $BACKUP)"

# Back up whatever is there now.
for f in init.el early-init.el; do
  [ -f "$TARGET/$f" ] && cp -p "$TARGET/$f" "$BACKUP/"
done
[ -d "$TARGET/modules" ] && cp -rp "$TARGET/modules" "$BACKUP/modules" 2>/dev/null || true

# Publish loader.
cp -p "$DIR/init.el" "$DIR/early-init.el" "$TARGET/"

shopt -s nullglob
count=0
for src in "$MODROOT"/*/; do
  group="$(basename "$src")"
  dest="$TARGET/modules/$group"
  mkdir -p "$dest"
  # Clean-mirror: drop stale generated files in this group, then copy fresh.
  find "$dest" -maxdepth 1 -type f \
       \( -name '[0-9]*.el' -o -name '[0-9]*.org' -o -name '[0-9]*.elc' \) -delete
  for f in "$src"[0-9]*.el "$src"[0-9]*.org; do
    cp -p "$f" "$dest/"
  done
  n=$(find "$dest" -maxdepth 1 -name '[0-9]*.org' | wc -l)
  echo "  $group: $n module(s)"
  count=$((count + n))
done

echo "done. ($count modules in $(find "$TARGET/modules" -mindepth 1 -maxdepth 1 -type d | wc -l) group(s))"
