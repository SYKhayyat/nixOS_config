#!/usr/bin/env bash
# Tangle literate .org modules -> .el, forcing LF (utf-8-unix) output.
#
# Usage: tangle.sh                    # tangle every module in every group
#        tangle.sh 00-core            # tangle just that module, whichever group
#        tangle.sh essentials         # tangle every module in one group
#
# The modules live in modules/<group>/, where <group> is essentials or extras.
# This script used to `cd` to the config root and glob *.org there, which has
# matched nothing since the modules moved into modules/ -- it reported "done."
# having tangled zero files.
set -euo pipefail
EMACS="${EMACS:-emacs}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODROOT="$DIR/modules"

command -v "$EMACS" >/dev/null 2>&1 || { echo "no emacs on PATH (set \$EMACS)" >&2; exit 1; }
[ -d "$MODROOT" ] || { echo "no modules dir at $MODROOT" >&2; exit 1; }

tangle_one() {
  local org="$1"
  echo "tangling ${org#"$MODROOT"/}"
  "$EMACS" --batch --eval "(progn
    (require 'org)
    (setq org-confirm-babel-evaluate nil)
    (let ((coding-system-for-write 'utf-8-unix))
      (org-babel-tangle-file \"$org\")))" 2>&1 | sed 's/^/  /'
}

shopt -s nullglob
count=0
if [ $# -ge 1 ]; then
  arg="$1"
  if [ -d "$MODROOT/$arg" ]; then                    # a whole group
    for org in "$MODROOT/$arg"/*.org; do tangle_one "$org"; count=$((count+1)); done
  else                                               # a single module basename
    for org in "$MODROOT"/*/"$arg".org; do tangle_one "$org"; count=$((count+1)); done
    [ "$count" -gt 0 ] || { echo "no module named $arg in any group" >&2; exit 1; }
  fi
else
  for org in "$MODROOT"/*/*.org; do tangle_one "$org"; count=$((count+1)); done
fi
echo "done. ($count file(s))"
