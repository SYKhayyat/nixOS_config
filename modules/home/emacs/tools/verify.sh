#!/usr/bin/env bash
# Byte-compile the modules against the real installed package set to catch
# syntax errors, unresolvable `require's, and undefined-function / void-variable
# problems WITHOUT running :ensure (so nothing is downloaded).  Warnings are
# informational; only errors fail the run.
#
# Usage: verify.sh                       # init + early-init + every module
#        verify.sh 10-seforim-core init  # just these basenames
#        VERBOSE=1 verify.sh             # don't filter the noise
#
# Modules live in modules/<group>/.  Both group directories go on the load-path
# so a cross-group reference resolves during compilation the way it does at
# runtime.  Run tools/tangle.sh first -- this compiles .el, not .org.
#
# THIS SCRIPT USED TO BE INCAPABLE OF FAILING.
# --------------------------------------------
# It ended with `... | grep -vE "...|Cannot open load file.*no such|..." || true'.
# Three separate reasons that made it useless:
#
#   1. `|| true' pinned the exit status at 0 no matter what happened.
#   2. Even without it, the pipeline reports grep's status, not Emacs's.
#   3. The filter dropped "Cannot open load file" -- which is precisely the
#      message an unresolvable `(require '<module>)' produces.
#
# So the one tool that could have caught the pre-split `require' names both
# swallowed the diagnostic and reported success.  Wiring it into CI as it stood
# would have produced a green check over 1,569 lines of dead elisp.
#
# Now: Emacs's status is captured before any filtering, "Cannot open load file"
# is surfaced rather than hidden, and only genuine noise is filtered.
set -uo pipefail
EMACS="${EMACS:-emacs}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODROOT="$DIR/modules"
OUT="$(mktemp -d)"
LOG="$OUT/verify.log"
trap 'rm -rf "$OUT"' EXIT

command -v "$EMACS" >/dev/null 2>&1 || { echo "no emacs on PATH (set \$EMACS)" >&2; exit 1; }

# Emacs on Windows needs native paths (C:/...), not MSYS paths (/c/...).
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

# A package.el install, if there is one.  On Nix there is not: the packages are
# baked into the Emacs binary's own load-path by `emacsWithPackages', so
# `package-initialize' has nothing to add and must not be pointed at a
# non-existent directory.
ELPA="${ELPA:-$HOME/.emacs.d/elpa}"
if [ -d "$ELPA" ]; then
  PKGINIT="(progn (setq package-user-dir \"$(win "$ELPA")\")
                  (require 'package)
                  (package-initialize))"
else
  PKGINIT="(ignore)"
fi

shopt -s nullglob
GROUPDIRS=()
for d in "$MODROOT"/*/; do [ -d "$d" ] && GROUPDIRS+=("$(win "${d%/}")"); done

FILES=()
missing=0
if [ $# -ge 1 ]; then
  for b in "$@"; do
    case "$b" in
      init|early-init) FILES+=("$(win "$DIR/$b.el")") ;;
      *)
        found=0
        for f in "$MODROOT"/*/"$b".el; do FILES+=("$(win "$f")"); found=1; done
        # A named module that has no .el is a failure, not a note: either the
        # name is wrong or tangling did not run, and both mean this run did not
        # verify what it was asked to verify.
        if [ "$found" -eq 0 ]; then
          echo "ERROR: no compiled module named '$b' (run tools/tangle.sh first?)" >&2
          missing=1
        fi
        ;;
    esac
  done
else
  for f in "$DIR"/init.el "$DIR"/early-init.el "$MODROOT"/*/[0-9]*.el; do
    FILES+=("$(win "$f")")
  done
fi

[ "$missing" -eq 0 ] || exit 1
[ "${#FILES[@]}" -gt 0 ] || { echo "nothing to compile -- run tools/tangle.sh first" >&2; exit 1; }

LOADPATH=""
for d in "${GROUPDIRS[@]}"; do LOADPATH="$LOADPATH (add-to-list 'load-path \"$d\")"; done

# Capture Emacs's own exit status before anything touches the pipeline.
"$EMACS" --batch \
  --eval "(progn
            $PKGINIT
            $LOADPATH
            (setq byte-compile-error-on-warn nil)
            (setq byte-compile-dest-file-function
                  (lambda (f) (expand-file-name (concat (file-name-base f) \".elc\") \"$(win "$OUT")\"))))" \
  --eval "(let ((rc 0))
            (dolist (f command-line-args-left)
              (condition-case e
                  (unless (byte-compile-file f) (setq rc 1))
                (error (setq rc 1)
                       (message \"ERROR compiling %s: %s\" f (error-message-string e)))))
            (kill-emacs rc))" \
  "${FILES[@]}" >"$LOG" 2>&1
rc=$?

# Filter for readability only -- never for exit status, and never anything that
# could be a real failure.  "Cannot open load file" is deliberately NOT here.
if [ "${VERBOSE:-0}" = "1" ]; then
  cat "$LOG"
else
  grep -vE "^Loading |^Package .* is (obsolete|deprecated)|^Wrote |^Compiling |^Warning \(comp\)" "$LOG" || true
fi

if [ "$rc" -ne 0 ]; then
  echo >&2
  echo "verify: byte-compilation FAILED (${#FILES[@]} file(s) attempted)" >&2
  echo "verify: re-run with VERBOSE=1 for the unfiltered log" >&2
  exit 1
fi
echo "verify: ${#FILES[@]} file(s) byte-compiled clean"
