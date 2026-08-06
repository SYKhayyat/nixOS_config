{ config, lib, pkgs, myConfig, ... }:

# Home-manager wiring for Emacs. The *configuration* itself is no longer here —
# it lives in its own repo and arrives as the `emacs-config` flake input.
#
# What stayed: the packages Emacs shells out to, the daemon, recoll.conf, and
# the scaffolding of directories Emacs expects to exist. All of that describes
# what THIS MACHINE provides. What left: init.el, early-init.el, the 40 literate
# modules, and the tools that build them — those describe what the CONFIG is,
# and they run on Windows and macOS too.
#
# The thing that actually went away is the staging hop. This module used to
# install the modules read-only at ~/.config/emacs/modules-src and then run a
# 20-line activation script that was a hand-rolled mtime-gated `cp` into a
# *writable* ~/.config/emacs/modules, because the Nix store is read-only and
# Emacs tangles .el next to .org at runtime.
#
# That copy was a directory Nix did not own: it could not roll it back, could
# not garbage-collect it, and never deleted from it — the sync only ever added.
# The config looked pinned and behaved mutable. Now the modules are tangled at
# BUILD time by the input's own flake, so what lands here is an immutable store
# symlink and the hop has no reason to exist.

let
  # Both come from the emacs-config flake input, threaded via myConfig so this
  # module does not need `inputs` plumbed through four specialisations.
  emacs = myConfig.emacsPackage; # Emacs + the package set the config expects
  emacsConfig = myConfig.emacsConfig; # that repo, with every module pre-tangled

  seforimPath = myConfig.seforimPath;
  homeDir = config.home.homeDirectory;
in
{
  home.packages = [
    emacs
  ]
  ++ (with pkgs; [
    recoll
    plocate
    fd
    ripgrep
    ripgrep-all
    texlive.combined.scheme-full
    typst
    tinymist
    # pandoc backs `ox-pandoc` (Org export) *and* the Markdown live preview in
    # essentials/10-markdown — it is the converter that turns Markdown into the
    # HTML that Emacs then renders with shr.
    pandoc
    sqlite
    graphviz
    imagemagick
    tree-sitter
    hdate
    jdt-language-server
    nil
    rust-analyzer
    pyright
    lua-language-server
  ]);

  home.sessionVariables = {
    EDITOR = "emacsclient -c -a ''";
    VISUAL = "emacsclient -c -a ''";
  };

  services.emacs = {
    enable = true;
    package = emacs;
    client = {
      enable = true;
      # Each list element is a distinct argv token; "-a ''" as one token would
      # be passed to emacsclient literally and mis-parsed. Split them.
      arguments = [
        "-c"
        "-a"
        ""
      ];
    };
  };

  # ── The config, pinned ──────────────────────────────────────────────────
  # `${emacsConfig}` is the emacs-config repo after its flake ran tangle.sh, so
  # modules/ holds both the .org sources and the generated .el. Nothing tangles
  # at startup: init.el skips any module directory that is not writable, and
  # this one is a store path.
  #
  # ~/.config/emacs itself stays a real, writable directory — Emacs writes
  # custom.el, eln-cache, transient state and the org-roam db in there. Only
  # the three config entries are store symlinks.
  home.file.".config/emacs/init.el".source = "${emacsConfig}/init.el";
  home.file.".config/emacs/early-init.el".source = "${emacsConfig}/early-init.el";
  home.file.".config/emacs/modules".source = "${emacsConfig}/modules";

  home.file.".recoll/recoll.conf".text = ''
    topdirs = ${seforimPath}
    followLinks = 1
        noaspell = 1
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf
    unac_except_stripping = true
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000
  '';

  # ── One-time migration off the writable modules directory ───────────────
  # Before this change ~/.config/emacs/modules was a real directory that Nix
  # wrote into. It is now a symlink into the store, and home-manager's
  # `checkLinkTargets` refuses to replace an existing real directory — so move
  # it aside first, before the link step runs.
  #
  # MOVED, not deleted, and deliberately: the whole problem with the old scheme
  # was that a hand-edit in there could silently have become the live config
  # while the repo went stale. If that happened, those edits are the only copy.
  # Diff modules.pre-flake-input against the emacs-config repo before you throw
  # it away.
  home.activation.migrateEmacsModules = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    emacsDir="${homeDir}/.config/emacs"
    if [ -e "$emacsDir/modules" ] && [ ! -L "$emacsDir/modules" ]; then
      echo "emacs: ~/.config/emacs/modules is now a store symlink."
      echo "emacs: moving the old writable copy to modules.pre-flake-input —"
      echo "emacs: diff it against the emacs-config repo before deleting it."
      $DRY_RUN_CMD rm -rf "$emacsDir/modules.pre-flake-input"
      $DRY_RUN_CMD mv "$emacsDir/modules" "$emacsDir/modules.pre-flake-input"
    fi
    # modules-src was the read-only staging half of the same hack.
    if [ -e "$emacsDir/modules-src" ] && [ ! -L "$emacsDir/modules-src" ]; then
      $DRY_RUN_CMD rm -rf "$emacsDir/modules-src"
    fi
  '';

  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.cache/emacs/undo-tree-history"
    mkdir -p "${homeDir}/.cache/emacs/seforim"
    mkdir -p "${homeDir}/Documents/org"
    mkdir -p "${homeDir}/Documents/roam/daily"
    mkdir -p "${seforimPath}/Bavli"

    [ ! -f "${homeDir}/Documents/org/inbox.org" ] && echo -e "* Tasks\n* Notes" > "${homeDir}/Documents/org/inbox.org"
    [ ! -f "${homeDir}/Documents/org/journal.org" ] && echo "#+TITLE: Journal" > "${homeDir}/Documents/org/journal.org"
    [ ! -f "${homeDir}/Documents/org/research.org" ] && echo "#+TITLE: Research" > "${homeDir}/Documents/org/research.org"
    [ ! -f "${homeDir}/Documents/bibliography.bib" ] && echo "% Bibliography" > "${homeDir}/Documents/bibliography.bib"
    [ ! -f "${homeDir}/.cache/emacs/seforim/study-log.el" ] && echo "nil" > "${homeDir}/.cache/emacs/seforim/study-log.el"
    true
  '';
}
