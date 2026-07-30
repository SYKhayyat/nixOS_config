#!/usr/bin/env bash
# Publish this canonical config to a user-emacs-directory.
#   init.el, early-init.el      -> <target>/
#   NN-*.el, NN-*.org           -> <target>/modules/   (clean mirror)
# The previous init/early-init/modules are backed up first.
#
# Usage: deploy.sh [target-emacs-dir]
#   default target: ~/.emacs.d on Windows, ~/.config/emacs elsewhere.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -ge 1 ]; then
  TARGET="$1"
elif [ "${OS:-}" = "Windows_NT" ]; then
  TARGET="$HOME/.emacs.d"
else
  TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
fi

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

# Clean-mirror the modules dir: remove stale generated files, copy fresh.
find "$TARGET/modules" -maxdepth 1 -type f \( -name '[0-9]*.el' -o -name '[0-9]*.org' -o -name '[0-9]*.elc' \) -delete
cp -p "$DIR"/[0-9]*.el "$DIR"/[0-9]*.org "$TARGET/modules/"

echo "done. ($(ls "$TARGET/modules"/[0-9]*.el | wc -l) modules)"
