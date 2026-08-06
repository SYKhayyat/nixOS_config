{ config, lib, pkgs, myConfig, ... }:

let
  # The package set lives in its own file so `nix flake check' can build the
  # identical Emacs and byte-compile the modules against it.  See the header
  # comment there for why that matters.
  emacsWithPackages = import ./emacs-package.nix { inherit pkgs; };

  seforimPath = myConfig.seforimPath;
  homeDir = config.home.homeDirectory;
in
{
  home.packages = with pkgs; [
    emacsWithPackages
    recoll plocate fd ripgrep ripgrep-all
    texlive.combined.scheme-full typst tinymist
    # pandoc backs `ox-pandoc` (Org export) *and* the Markdown live preview in
    # module 28 — it is the converter that turns Markdown into the HTML that
    # Emacs then renders with shr.
    pandoc
    sqlite graphviz imagemagick tree-sitter hdate
    jdt-language-server nil rust-analyzer pyright lua-language-server
  ];

  home.sessionVariables = {
    EDITOR = "emacsclient -c -a ''";
    VISUAL = "emacsclient -c -a ''";
  };

  services.emacs = {
    enable = true;
    package = emacsWithPackages;
    client = {
      enable = true;
      # Each list element is a distinct argv token; "-a ''" as one token would
      # be passed to emacsclient literally and mis-parsed. Split them.
      arguments = [ "-c" "-a" "" ];
    };
  };

  # ── The loader: ONE copy, shared by every machine ───────────────────────
  # These used to be Nix strings duplicating the portable repo's init.el /
  # early-init.el.  Two copies of the same loader is exactly how the Nix and
  # portable configs drifted apart, so they are now the *same files* — real
  # elisp you can edit, byte-compile and lint, consumed verbatim here and
  # copied as-is to a non-Nix box by tools/deploy.sh.
  home.file.".config/emacs/early-init.el".source = ./early-init.el;

  # init.el — the same self-assembling glob loader used on every machine.  It
  # loads every NN-*.el in filename order rather than a hand-maintained list,
  # so new modules are picked up automatically and can never be silently
  # dropped.  Package sourcing is auto-detected in 00-core: on Nix the packages
  # are already on the load-path (nothing is downloaded); on a bare box the
  # identical file self-installs from MELPA.
  home.file.".config/emacs/init.el".source = ./init.el;

  # ── Literate Emacs modules, version-controlled ──────────────────────────
  # The org sources live in the repo (modules/home/emacs/modules/*.org) and are
  # staged read-only here. The activation below copies them into a *writable*
  # ~/.config/emacs/modules so init.el can tangle .el files next to them. This
  # is what makes a fresh install reproduce your Emacs instead of booting broken.
  home.file.".config/emacs/modules-src" = {
    source = ./modules;
    recursive = true;
  };

  home.file.".recoll/recoll.conf".text = ''
    topdirs = ${seforimPath}
    followLinks = 1
        noaspell = 1
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf
    unac_except_stripping = true
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000
  '';

  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.config/emacs/modules"

    # Sync repo-managed org modules into the writable modules dir (only when
    # newer), so runtime tangling can write .el alongside them.
    #
    # The modules live in TWO group directories -- essentials/ and extras/ --
    # and the group structure is reproduced here, because init.el loads group
    # by group to guarantee essentials is in place before extras layers on it.
    # A flat glob over modules-src/*.org would now match nothing at all.
    if [ -d "${homeDir}/.config/emacs/modules-src" ]; then
      for src in "${homeDir}/.config/emacs/modules-src"/*/; do
        [ -d "$src" ] || continue
        group=$(basename "$src")
        mkdir -p "${homeDir}/.config/emacs/modules/$group"
        for org in "$src"*.org; do
          [ -e "$org" ] || continue
          dest="${homeDir}/.config/emacs/modules/$group/$(basename "$org")"
          if [ ! -f "$dest" ] || [ "$org" -nt "$dest" ]; then
            $DRY_RUN_CMD install -m 0644 "$org" "$dest"
          fi
        done
      done
    fi

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
  '';
}
