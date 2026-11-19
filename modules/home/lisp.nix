# modules/home/lisp.nix
#
# Common Lisp. `sbcl` is installed by ./toolkit.nix (rule 3:
# things a person types); this file installs Quicklisp and wires up the pair,
# which is the part that is easy to miss and impossible to guess.
#
# ── The problem this file exists to solve ────────────────────────────────
#
# `sbcl` alone is not a Lisp environment. It compiles Lisp and has no package
# manager, so there is nothing to install a library with — the standard library
# is ANSI CL and stops there. Quicklisp is what fills that in, and its interface
# is two forms:
#
#   (load "…/quicklisp/setup.lisp")
#   (ql:quickload "alexandria")
#
# So a REPL needs the first to have already run, and *that* is the whole job of
# this file. There is no wrapper that saves you from it, and a wrapped `sbcl`
# is deliberately not provided: CIDER, SLIME and anything that execs `sbcl` by
# name expect the real one.
#
# ── Why the store path cannot be used directly ───────────────────────────
#
# Because Quicklisp writes into its own install directory at runtime. Not
# optionally — this was measured, and the list is not short:
#
#   dists/quicklisp/systems.cdb-tmp    every quickload that resolves a system
#   dists/quicklisp/releases.cdb-tmp   same, on a release query
#   local-projects/system-index.txt    every load (see below)
#   cache/asdf-fasls/…                 the ASDF fasl, compiled on first use
#   dists/quicklisp/software/…         the downloaded libraries themselves
#
# Against /nix/store that is SIMPLE-FILE-ERROR "Error opening … systems.cdb-tmp"
# on the first `ql:quickload`, every time, with no workaround short of not
# using the store path. Local-projects is the subtle one: `local-projects.lisp`
# registers a directory scanner, and `register-local-projects` writes
# system-index.txt unconditionally — so it fails even when you have no local
# projects, which is the common case.
#
# So Quicklisp lives in ~/.local/share/quicklisp, installed there once by the
# pinned bootstrap (packages/quicklisp.nix) and only ever written by Quicklisp.
#
# ── Why that is still not the stray it looks like ───────────────────────
#
# The instinct is that a directory nobody declared is exactly what the rest of
# this repo exists to prevent, and for a plain `git clone` into $HOME it is. The
# difference is what created it and what it holds: it is installed by a pinned
# bootstrap rather than cloned ad hoc, it contains only a cache Quicklisp
# regenerates on demand, and it is stated here in the Nix config rather than
# being discovered later. A `home.file` cannot own it — it is written
# continuously — so it is declared as a directory, installed once, and left alone.
#
# The alternative was a writable Quicklisp in the *system* profile so `study`
# could take it away. That was rejected: study removes browsers and fetchers,
# not compilers (see toolkit.nix), and the SBCL in the profile is usable without
# Quicklisp — you get ANSI CL and lose `(ql:quickload)`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The writable install. Quicklisp's own home directory is this, and every
  # path Quicklisp computes is relative to it.
  quicklispHome = "${config.home.homeDirectory}/.local/share/quicklisp";
in

{
  # The install. packages/quicklisp.nix is only the bootstrap file, so the
  # first switch on a machine runs it into the writable directory above — a
  # network fetch, like `emacs-install` for elpa/. It runs only while
  # setup.lisp is missing, so every switch after the first costs nothing, and a
  # failed install (no network yet at boot) leaves no setup.lisp and is retried
  # on the next switch, in the same directory — nothing here deletes it.
  #
  # stdin is /dev/null because the bootstrap *prompts* between phases; with no
  # terminal the prompt reads EOF and moves on. No init files, because
  # ~/.sbclrc loads an existing Quicklisp and the bootstrap then reports
  # "already set up" and installs nothing. `timeout` so a dead network
  # cannot hold up a switch. `run` so `--dry-run` does not fetch.
  home.activation.seedQuicklisp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${quicklispHome}/setup.lisp" ]; then
      run mkdir -p "${quicklispHome}"
      if ! run ${pkgs.coreutils}/bin/timeout 300 ${pkgs.sbcl}/bin/sbcl \
          --no-sysinit --no-userinit --non-interactive \
          --load "${pkgs.quicklisp}/share/quicklisp/quicklisp.lisp" \
          --eval '(quicklisp-quickstart:install :path "${quicklispHome}/")' \
          < /dev/null > /dev/null; then
        echo "quicklisp: install failed; it is retried on the next switch" >&2
      fi
    fi
  '';

  # `~/.sbclrc`. SBCL reads this before the REPL, so `(ql:quickload …)` works at
  # the first prompt with nothing typed first. The `probe-file` guard means the
  # activation above has already run; without it, loading setup.lisp out of a
  # half-installed directory fails on a first login after a rebuild that only
  # added the directory.
  home.file.".sbclrc".text = ''
    ;;; .sbclrc --- generated by modules/home/lisp.nix -*- lexical-binding: t; -*-
    ;; Do not edit: home-manager owns this file. Put your own Lisp in
    ;; ~/.config/common-lisp/user.lisp, which is loaded after this.

    (when (probe-file "${quicklispHome}/setup.lisp")
      (load "${quicklispHome}/setup.lisp"))
  '';

  # `~/.config/common-lisp/user.lisp` is where your own code belongs, and SBCL
  # loads it after .sbclrc — so QL is already available in it. Created so there
  # is somewhere obvious to put the first thing you write.
  home.file.".config/common-lisp/user.lisp".text = ''
    ;;;; user.lisp --- your Lisp goes here. -*- lexical-binding: t; -*-
    ;;;; Loaded after ~/.sbclrc, so (ql:quickload "...") works in this file.
  '';
}
