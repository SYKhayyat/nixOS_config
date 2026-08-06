#!/usr/bin/env bash
# Static consistency check over the literate module tree.  No Emacs, no
# packages, no network -- pure text analysis of modules/<group>/*.org, so it
# runs identically in a `nix flake check` sandbox, in CI, and on a bare box.
#
# Usage: check-modules.sh [MODULES_ROOT]
# Exit:  0 = clean, 1 = at least one error.  Warnings never fail the run.
#
# WHY THIS EXISTS
# ---------------
# A module's identity is its ordering prefix: `10-seforim-core.org' tangles to
# `10-seforim-core.el', provides `10-seforim-core', and dependents say
# `(require QUOTE 10-seforim-core)'.  That couples identity to load order, so
# renumbering a module rewrites its name and every reference to it.
#
# The essentials/extras split renumbered most of the tree.  Five modules kept
# requiring the pre-split names (`14a-seforim-core' and friends).  Nothing
# provided those, `require' signalled, `init.el' caught it in `condition-case',
# and 1,569 of the seforim system's 1,775 lines stopped loading -- with no
# crash and no failing build.  The only symptom was `M-x seforim-mefarshim'
# quietly not existing.
#
# Every consistency rule the tooling could express was satisfied: tangle
# targets, `provide' forms and filenames all agreed.  The one rule that broke
# was the only one nothing checked.  This script checks it.
#
# It does not remove the coupling -- renumbering still rewrites names.  It
# makes breaking it loud: a renumber that misses a dependant now fails the
# build instead of silently deleting a subsystem.
#
# The analysis is ONE awk pass over every file rather than a shell loop
# spawning grep/sed/awk per module.  Not premature optimisation: the per-file
# version took ~90s under MSYS on the Windows half of this config, where fork()
# is expensive, and a check that slow is a check nobody runs.
#
# The awk program is fed from a quoted heredoc rather than a single-quoted
# argument, because it is full of elisp quote characters and the escaping was
# its own source of bugs.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODROOT="${1:-$DIR/modules}"
INIT="$DIR/init.el"

[ -d "$MODROOT" ] || { echo "check-modules: no modules dir at $MODROOT" >&2; exit 1; }

shopt -s nullglob
ORGS=("$MODROOT"/*/*.org)
[ "${#ORGS[@]}" -gt 0 ] || { echo "check-modules: no .org modules under $MODROOT" >&2; exit 1; }

AWKIN=("${ORGS[@]}")
[ -f "$INIT" ] && AWKIN+=("$INIT")

PROG=$(cat <<'AWK_PROGRAM'
function err(m)  { errs[++ne]  = "ERROR   " m }
function warn(m) { warns[++nw] = "warning " m }

# POSIX awk has no match(s, re, arr), so pull the match out via RSTART/RLENGTH.
function grab(s, re) {
  if (!match(s, re)) return ""
  return substr(s, RSTART, RLENGTH)
}

FNR == 1 {
  isinit = (FILENAME == initfile)
  if (isinit) { ingate = 0; next }
  n = split(FILENAME, p, "/")
  fname = p[n]
  grp   = p[n-1]
  base  = fname; sub(/\.org$/, "", base)
  order[++nf] = base
  relof[base] = grp "/" fname
  grpof[base] = grp
  in_src = 0
}

# -- init.el: the capability gates inside my/module-enabled-p ---------------
FILENAME == initfile {
  if ($0 ~ /defun my\/module-enabled-p/) { ingate = 1; next }
  if (ingate) {
    if ($0 ~ /^[[:space:]]*$/) { ingate = 0; next }
    t = grab($0, "^[[:space:]]*\\(\"[a-z0-9-]+\"")
    if (t != "") { gsub(/[^a-z0-9-]/, "", t); if (t != "") gates[++ng] = t }
  }
  next
}

# -- the ";;; name.el ---" header sits inside a src block but IS a comment,
#    so match it on the raw line, before the comment filter below.
header[base] == "" && /^;;;[[:space:]]+[^[:space:]]+\.el/ {
  header[base] = grab($0, "[^[:space:]]+\\.el")
}

# -- the tangle property sits outside src blocks ----------------------------
# Take the token *after* ":tangle", not $NF -- the line may carry further
# header args (":mkdirp yes :comments no"), and $NF picked those up.
tangle[base] == "" && /^#\+PROPERTY:[[:space:]]+header-args:emacs-lisp[[:space:]]+:tangle[[:space:]]/ {
  for (fi = 1; fi < NF; fi++)
    if ($fi == ":tangle") { tangle[base] = $(fi + 1); break }
}

tolower($0) ~ /^[[:space:]]*#\+begin_src[[:space:]]+emacs-lisp/ { in_src = 1; next }
tolower($0) ~ /^[[:space:]]*#\+end_src/                        { in_src = 0; next }

# Ignore prose and elisp comments, so a require mentioned in a docstring is not
# read as a real dependency.  Deliberately crude: this is a linter, not a reader.
!in_src { next }
/^[[:space:]]*;/ { next }

{
  t = grab($0, "^\\(provide '[A-Za-z0-9_-]+")
  if (t != "") {
    sub(/^\(provide '/, "", t)
    nprov[base]++
    provlist[base] = provlist[base] " " t
    if (provider[t] != "")
      err(relof[base] ": feature \"" t "\" is already provided by " relof[provider[t]])
    else
      provider[t] = base
  }

  rest = $0
  while ((t = grab(rest, "\\(require '[A-Za-z0-9_-]+")) != "") {
    rest = substr(rest, RSTART + RLENGTH)
    sub(/^\(require '/, "", t)
    # Only module-shaped names (NN-foo / NNa-foo) are ours; everything else is
    # a real Emacs library and none of this script's business.
    if (t ~ /^[0-9]+[a-z]?-/ && index(" " reqlist[base] " ", " " t " ") == 0)
      reqlist[base] = reqlist[base] " " t
  }
}

END {
  # -- per-file identity ---------------------------------------------------
  for (i = 1; i <= nf; i++) {
    b = order[i]; r = relof[b]

    if (nprov[b] == 0)     err(r ": no top-level (provide ...) form")
    else if (nprov[b] > 1) err(r ": " nprov[b] " top-level (provide ...) forms; expected exactly one")
    else {
      split(provlist[b], pv, " ")
      if (pv[1] != b) err(r ": provides \"" pv[1] "\" but the filename says \"" b "\"")
    }

    # ":tangle yes" derives the name from the .org and so is correct by
    # construction; only an explicit target can drift.
    if (tangle[b] == "")
      err(r ": no \"#+PROPERTY: header-args:emacs-lisp :tangle ...\" line")
    else if (tangle[b] != "yes" && tangle[b] != b ".el")
      err(r ": tangles to \"" tangle[b] "\" but the filename says \"" b ".el\"")

    if (header[b] == "")           warn(r ": no \";;; " b ".el --- ...\" header line")
    else if (header[b] != b ".el") err(r ": header line says \"" header[b] "\" but the filename says \"" b ".el\"")
  }

  # -- dependencies --------------------------------------------------------
  for (i = 1; i <= nf; i++) {
    b = order[i]; r = relof[b]
    m = split(reqlist[b], rq, " ")
    for (j = 1; j <= m; j++) {
      f = rq[j]
      if (provider[f] == "") { err(r ": requires \"" f "\", which no module provides"); continue }
      if (f == b)            { err(r ": requires itself"); continue }
      pg = grpof[provider[f]]
      # extras layers on top of essentials, and init.el loads essentials
      # first, so the reverse edge could never resolve at runtime anyway.
      if (grpof[b] == "essentials" && pg == "extras") {
        err(r ": essentials requires \"" f "\" from extras -- the dependency may only point the other way")
        continue
      }
      # Within a group, load order is the filename sort.
      if (grpof[b] == pg && f >= b)
        err(r ": requires \"" f "\", which loads after it")
    }
  }

  # -- capability gates must name a module that exists ---------------------
  # my/module-enabled-p gates on the module NAME with the ordinal stripped, so
  # a gate whose name no module carries silently gates nothing at all.
  for (i = 1; i <= nf; i++) { s = order[i]; sub(/^[0-9]+[a-z]?-/, "", s); names[s] = 1 }
  for (i = 1; i <= ng; i++)
    if (!(gates[i] in names))
      err("init.el: my/module-enabled-p gates on \"" gates[i] "\", which no module is named")

  for (i = 1; i <= ne; i++) print errs[i]  > "/dev/stderr"
  for (i = 1; i <= nw; i++) print warns[i] > "/dev/stderr"
  if (nw > 0) printf "check-modules: %d warning(s)\n", nw > "/dev/stderr"
  if (ne > 0) exit 1
}
AWK_PROGRAM
)

awk -v initfile="$INIT" "$PROG" "${AWKIN[@]}"
errors=$?

# ---------------------------------------------------------------------------
# Generated output must not be left orphaned by a rename.
# ---------------------------------------------------------------------------
for el in "$MODROOT"/*/*.el; do
  b="$(basename "$el" .el)"; g="$(basename "$(dirname "$el")")"
  if [ ! -f "$MODROOT/$g/$b.org" ]; then
    echo "ERROR   $g/$b.el is orphaned -- no $b.org produces it (stale rename?)" >&2
    errors=1
  fi
done

# ---------------------------------------------------------------------------
# Every module must be tracked by git.
# `nix build' copies the *git tree* to the store, so an untracked .org is
# absent on every machine except the one it was written on -- and the writable
# ~/.config/emacs/modules sync never deletes, so the author's box keeps a copy
# from an earlier deploy and never notices.  Skipped in a build sandbox, where
# untracked files are already gone and there is nothing left to detect.
# ---------------------------------------------------------------------------
if command -v git >/dev/null 2>&1 && git -C "$MODROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    echo "ERROR   $f is not tracked by git -- it will not exist in the Nix store build" >&2
    errors=1
  done < <(git -C "$MODROOT" ls-files --others --exclude-standard -- '*.org')
else
  echo "check-modules: not a git work tree, skipping the tracked-file check" >&2
fi

if [ "$errors" -ne 0 ]; then
  echo "check-modules: FAILED over ${#ORGS[@]} modules" >&2
  exit 1
fi
echo "check-modules: ${#ORGS[@]} modules OK"
