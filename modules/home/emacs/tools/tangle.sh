#!/usr/bin/env bash
# Tangle one or all literate .org modules -> .el, forcing LF (utf-8-unix) output.
# Usage: tangle.sh            # tangle every *.org in the repo
#        tangle.sh 00-core    # tangle just 00-core.org (basename, no extension)
set -euo pipefail
EMACS="${EMACS:-/c/msys64/mingw64/bin/emacs}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

tangle_one() {
  local org="$1"
  "$EMACS" --batch --eval "(progn
    (require 'org)
    (setq org-confirm-babel-evaluate nil)
    (let ((coding-system-for-write 'utf-8-unix))
      (org-babel-tangle-file \"$org\")))" 2>&1 | sed 's/^/  /'
}

if [ $# -ge 1 ]; then
  tangle_one "$1.org"
else
  for org in *.org; do
    echo "tangling $org"
    tangle_one "$org"
  done
fi
echo "done."
