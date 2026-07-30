#!/usr/bin/env bash
# Byte-compile modules against the real installed package set to catch syntax
# errors and undefined-function/void-variable problems WITHOUT running :ensure
# (so nothing is downloaded).  Warnings are informational; only errors fail.
#
# Usage: verify.sh                 # compile all NN-*.el + init.el + early-init.el
#        verify.sh 14a-seforim-core init  # compile just these basenames
set -uo pipefail
EMACS="${EMACS:-/c/msys64/mingw64/bin/emacs}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELPA="${ELPA:-$HOME/.emacs.d/elpa}"
OUT="$DIR/.claude/.build"
mkdir -p "$OUT"
# Emacs on Windows needs native paths (C:/...), not MSYS paths (/c/...).
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
WDIR="$(win "$DIR")"; WELPA="$(win "$ELPA")"; WOUT="$(win "$OUT")"

if [ $# -ge 1 ]; then
  FILES=(); for b in "$@"; do FILES+=("$(win "$DIR/$b.el")"); done
else
  FILES=(); for f in "$DIR"/init.el "$DIR"/early-init.el "$DIR"/[0-9]*.el; do FILES+=("$(win "$f")"); done
fi

"$EMACS" --batch \
  --eval "(progn
            (setq package-user-dir \"$WELPA\")
            (require 'package)
            (package-initialize)
            (add-to-list 'load-path \"$WDIR\")
            (setq byte-compile-dest-file-function
                  (lambda (f) (expand-file-name (concat (file-name-base f) \".elc\") \"$WOUT\"))))" \
  --eval "(let ((rc 0))
            (dolist (f command-line-args-left)
              (condition-case e
                  (unless (byte-compile-file f) (setq rc 1))
                (error (setq rc 1)
                       (message \"ERROR compiling %s: %s\" f (error-message-string e)))))
            (kill-emacs rc))" \
  "${FILES[@]}" 2>&1 | grep -vE "^Loading|^Package|obsolete|Cannot open load file.*no such|^Warning \(comp\)" || true

rm -rf "$OUT"/*.elc 2>/dev/null || true
