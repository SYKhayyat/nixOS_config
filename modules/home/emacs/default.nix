{ config, lib, pkgs, myConfig, ... }:

let
  emacs = pkgs.emacs30-pgtk or pkgs.emacs30 or pkgs.emacs29-pgtk;
  emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
    use-package dash s f seq cl-lib diminish
    doom-themes doom-modeline nerd-icons all-the-icons all-the-icons-dired pulsar shrink-path
    vertico orderless marginalia consult embark embark-consult corfu anzu deadgrep engine-mode
    undo-tree avy ace-window multiple-cursors expand-region move-text crux visual-regexp wgrep
    rainbow-delimiters goto-last-change beginend
    projectile consult-projectile dirvish
    org org-modern org-download org-roam org-roam-ui ox-pandoc citar citar-org-roam citeproc
    vterm pdf-tools jinx gptel
    magit git-gutter git-timemachine eglot eglot-java treesit-grammars.with-all-grammars
    treesit-auto rust-mode cargo nix-mode markdown-mode typst-ts-mode yasnippet
    yasnippet-snippets editorconfig envrc helpful which-key
    gcmh hydra restart-emacs visual-fill-column
    valign focus olivetti
    centaur-tabs
    # typst-preview is an *Emacs* package, so it belongs on the Emacs
    # load-path — not in `home.packages`, where it was previously listed and
    # therefore could never be `require`d.  It talks to `tinymist preview`
    # over a websocket, hence the explicit websocket dependency.
    typst-preview websocket
  ]);

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
    if [ -d "${homeDir}/.config/emacs/modules-src" ]; then
      for org in "${homeDir}/.config/emacs/modules-src"/*.org; do
        [ -e "$org" ] || continue
        dest="${homeDir}/.config/emacs/modules/$(basename "$org")"
        if [ ! -f "$dest" ] || [ "$org" -nt "$dest" ]; then
          $DRY_RUN_CMD install -m 0644 "$org" "$dest"
        fi
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
