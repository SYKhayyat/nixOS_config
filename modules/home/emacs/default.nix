# modules/home/emacs/default.nix
# Full Seforim-Ready Emacs configuration for Home Manager
{ config, lib, pkgs, myConfig, ... }:

let
  # Use Emacs 30 with PGTK (Wayland support)
  emacs = pkgs.emacs30-pgtk or pkgs.emacs30 or pkgs.emacs29-pgtk;

  # Exhaustive package list from your original configuration
  emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
    # CORE
    use-package dash s f seq cl-lib diminish
    # UI & APPEARANCE
    doom-themes doom-modeline nerd-icons all-the-icons all-the-icons-dired pulsar shrink-path
    # COMPLETION & SEARCH
    vertico orderless marginalia consult embark embark-consult corfu anzu deadgrep engine-mode
    # EDITING
    undo-tree avy ace-window multiple-cursors expand-region move-text crux visual-regexp wgrep
    rainbow-delimiters goto-last-change beginend
    # FILE & BUFFER MANAGEMENT
    projectile consult-projectile dirvish
    # ORG & NOTES
    org org-modern org-download org-roam org-roam-ui ox-pandoc citar citar-org-roam citeproc
    # TERMINAL & TOOLS
    vterm pdf-tools jinx gptel
    # PROGRAMMING
    magit git-gutter git-timemachine eglot eglot-java treesit-grammars.with-all-grammars
    treesit-auto rust-mode cargo nix-mode markdown-mode typst-ts-mode yasnippet
    yasnippet-snippets editorconfig envrc helpful which-key
    # UTILITIES
    gcmh hydra restart-emacs visual-fill-column
  ]);

  seforimPath = myConfig.seforimPath;
  homeDir = config.home.homeDirectory;
in
{
  # ══════════════════════════════════════════════════════════════════
  # SYSTEM PACKAGES
  # ══════════════════════════════════════════════════════════════════
  home.packages = with pkgs; [
    emacsWithPackages
    # Search Engines (Required for Seforim 2.0)
    recoll plocate fd ripgrep
    # LaTeX & Typesetting
    texlive.combined.scheme-full typst tinymist
    # Utilities
    sqlite graphviz imagemagick tree-sitter hdate
    # Language servers
    jdt-language-server nil rust-analyzer pyright lua-language-server
  ];

  home.sessionVariables = {
    EDITOR = "emacs";
    VISUAL = "emacs";
  };

  # ══════════════════════════════════════════════════════════════════
  # EMACS CONFIG FILES
  # ══════════════════════════════════════════════════════════════════

  home.file.".config/emacs/early-init.el".text = ''
    ;;; early-init.el - Performance
    (setq package-enable-at-startup nil load-prefer-newer t)
    (setq native-comp-eln-load-path (list (expand-file-name "~/.cache/emacs/eln-cache/")))
    (setq gc-cons-threshold most-positive-fixnum gc-cons-percentage 0.6)
    (setq native-comp-async-report-warnings-errors 'silent native-comp-jit-compilation t)
    (setq warning-suppress-types '((comp) (bytecomp)))
    (defvar my--file-name-handler-alist file-name-handler-alist)
    (setq file-name-handler-alist nil)
    (add-hook 'emacs-startup-hook (lambda () (setq file-name-handler-alist my--file-name-handler-alist)))
  '';

  home.file.".config/emacs/init.el".text = ''
    ;; init.el --- Modular Loader
    (defvar my/modules-dir (expand-file-name "modules" user-emacs-directory))
    (add-to-list 'load-path my/modules-dir)
    (defun my/tangle-modules ()
      (when (file-directory-p my/modules-dir)
        (require 'ob-tangle)
        (dolist (org-file (directory-files my/modules-dir t "\\.org$"))
          (let* ((base (file-name-base org-file))
                 (el-file (expand-file-name (concat base ".el") my/modules-dir)))
            (when (or (not (file-exists-p el-file)) (file-newer-than-file-p org-file el-file))
              (message "Tangling %s..." base)
              (org-babel-tangle-file org-file))))))
    (condition-case err (my/tangle-modules) (error (message "Tangling failed: %s" err)))
    (dolist (module '("00-core" "01-ui" "02-hebrew" "03-completion" "04-editing" "05-navigation"
                      "06-org" "07-org-roam" "08-latex" "09-typst" "10-context" "11-pdf"
                      "12-programming" "13-magit" "14-seforim" "15-rich-footnotes" "16-hydras"
                      "17-utils" "18-academic" "19-hebrew-extra" "20-projectile" "21-local-ai"
                      "22-dirvish" "23-vterm-pro" "24-scholar-search" "25-nix-system"))
      (condition-case err (require (intern module)) (error (message "Failed: %s: %s" module err))))
  '';

  # ══════════════════════════════════════════════════════════════════
  # RECOLL CONFIGURATION
  # ══════════════════════════════════════════════════════════════════
  home.file.".recoll/recoll.conf".text = ''
    topdirs = ${seforimPath}
    followLinks = 1
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf
    indexstemminglanguages = hebrew english
    unac_except_stripping = true
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000
  '';

  # ══════════════════════════════════════════════════════════════════
  # ACTIVATION SCRIPTS
  # ══════════════════════════════════════════════════════════════════
  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.config/emacs/modules"
    mkdir -p "${homeDir}/.cache/emacs/undo-tree-history"
    mkdir -p "${homeDir}/.cache/emacs/seforim"
    mkdir -p "${homeDir}/Documents/org"
    mkdir -p "${homeDir}/Documents/roam/daily"
    mkdir -p "${seforimPath}/Bavli"

    # Files creation
    [ ! -f "${homeDir}/Documents/org/inbox.org" ] && echo -e "* Tasks\n* Notes" > "${homeDir}/Documents/org/inbox.org"
    [ ! -f "${homeDir}/Documents/org/journal.org" ] && echo "#+TITLE: Journal" > "${homeDir}/Documents/org/journal.org"
    [ ! -f "${homeDir}/Documents/org/research.org" ] && echo "#+TITLE: Research" > "${homeDir}/Documents/org/research.org"
    [ ! -f "${homeDir}/Documents/bibliography.bib" ] && echo "% Bibliography" > "${homeDir}/Documents/bibliography.bib"

    # Study log history placeholder
    if [ ! -f "${homeDir}/.cache/emacs/seforim/study-log.el" ]; then
      echo "nil" > "${homeDir}/.cache/emacs/seforim/study-log.el"
    fi
  '';
}
