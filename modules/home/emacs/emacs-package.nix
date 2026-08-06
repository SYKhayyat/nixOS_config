# The Emacs binary and its package set, as a function of `pkgs' alone.
#
# This used to be a `let' binding inside default.nix, which meant it was
# reachable only from a fully-evaluated home-manager configuration.  It is
# factored out here so `nix flake check' can build the *same* Emacs the system
# installs and byte-compile the modules against it.  A verification job that
# compiles against a different package set than the one you run is not
# verifying your configuration -- it is verifying a lookalike.
#
# If the Emacs config is ever split into its own repository, this file goes
# with `default.nix' and stays here: it describes what NixOS installs, not what
# the config does.
{ pkgs }:

let
  emacs = pkgs.emacs30-pgtk or pkgs.emacs30 or pkgs.emacs29-pgtk;
in
(pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
  use-package dash s f seq cl-lib diminish
  doom-themes doom-modeline nerd-icons all-the-icons all-the-icons-dired pulsar shrink-path
  vertico orderless marginalia consult embark embark-consult corfu anzu deadgrep engine-mode
  undo-tree avy ace-window multiple-cursors expand-region move-text crux visual-regexp wgrep
  rainbow-delimiters goto-last-change beginend
  projectile consult-projectile dirvish
  org org-modern org-download org-roam org-roam-ui ox-pandoc citar citar-org-roam citeproc
  vterm pdf-tools jinx gptel
  # nov (EPUB) and pdf-view-restore are `use-package'd by the pdf module.  In
  # Nix mode `use-package-always-ensure' is nil, so a package that is not
  # listed here is not installed and not on the load-path -- the use-package
  # form is a silent no-op and the feature simply is not there.  Both were
  # missing, which is why opening a .epub did nothing.
  nov pdf-view-restore
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
])
