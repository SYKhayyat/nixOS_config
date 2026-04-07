# modules/home/emacs/default.nix
# Full Seforim-Ready Emacs configuration for Home Manager
# Uses Emacs 30 (pgtk) with exhaustive package set and system tools

{ config, lib, pkgs, myConfig, ... }:

let
  # ══════════════════════════════════════════════════════════════════
  # EMACS BUILD - Using Emacs 30 for best performance
  # ══════════════════════════════════════════════════════════════════

  emacs = pkgs.emacs30-pgtk or pkgs.emacs30 or pkgs.emacs29-pgtk;

  emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
    # CORE PACKAGES
    use-package dash s f seq cl-lib diminish

    # UI & APPEARANCE
    doom-themes doom-modeline nerd-icons all-the-icons all-the-icons-dired
    pulsar shrink-path

    # COMPLETION & SEARCH (Enhanced for Seforim 2.0)
    vertico orderless marginalia consult embark embark-consult
    corfu anzu deadgrep engine-mode

    # EDITING
    undo-tree avy ace-window multiple-cursors expand-region
    move-text crux visual-regexp wgrep rainbow-delimiters
    goto-last-change beginend

    # FILE & BUFFER MANAGEMENT
    projectile consult-projectile dirvish

    # ORG & NOTES
    org org-modern org-download org-roam org-roam-ui
    ox-pandoc citar citar-org-roam citeproc

    # TERMINAL & TOOLS
    vterm pdf-tools jinx gptel

    # PROGRAMMING
    magit git-gutter git-timemachine eglot eglot-java
    treesit-grammars.with-all-grammars treesit-auto
    rust-mode cargo nix-mode markdown-mode typst-ts-mode
    yasnippet yasnippet-snippets editorconfig envrc helpful which-key

    # UTILITIES
    gcmh hydra restart-emacs visual-fill-column
  ]);

  seforimPath = myConfig.seforimPath;
  homeDir = config.home.homeDirectory;

in
{
  # ══════════════════════════════════════════════════════════════════
  # PACKAGES
  # ══════════════════════════════════════════════════════════════════

  home.packages = with pkgs; [
    emacsWithPackages

    # Search Engines & Seforim Dependencies
    recoll          # Content search & snippets
    plocate         # Ultra-fast filename search
    fd              # Fast file traversal
    ripgrep         # Fast text search
    sqlite          # For org-roam
    hdate           # Hebrew calendar utils

    # LaTeX (full installation)
    texlive.combined.scheme-full

    # Typst (modern typesetting)
    typst
    tinymist

    # Utilities for Emacs
    graphviz        # For org diagrams
    imagemagick     # Image manipulation
    tree-sitter     # Syntax parsing
    recoll          # Full-text search for seforim

    # Language servers
    jdt-language-server  # Java
    nil                 # Nix LSP
    rust-analyzer       # Rust LSP
    pyright             # Python LSP
    lua-language-server # Lua LSP
  ];

  home.sessionVariables = {
    EDITOR = "emacs";
    VISUAL = "emacs";
  };

  # ══════════════════════════════════════════════════════════════════
  # EMACS CONFIGURATION FILES
  # ══════════════════════════════════════════════════════════════════

  home.file.".config/emacs/early-init.el".text = ''
    ;;; early-init.el - Optimizations before package loading
    (setq package-enable-at-startup nil)
    (setq load-prefer-newer t)
    (setq native-comp-eln-load-path (list (expand-file-name "~/.cache/emacs/eln-cache/")))
    (setq gc-cons-threshold most-positive-fixnum gc-cons-percentage 0.6)
    (setq native-comp-async-report-warnings-errors 'silent native-comp-jit-compilation t)
    (setq warning-suppress-types '((comp) (bytecomp)))
    (defvar my--file-name-handler-alist file-name-handler-alist)
    (setq file-name-handler-alist nil)
    (add-hook 'emacs-startup-hook (lambda () (setq file-name-handler-alist my--file-name-handler-alist)))
  '';

  home.file.".config/emacs/init.el".text = ''
    ;; init.el --- Modular Emacs configuration -*- lexical-binding: t; -*-
    (defvar my/modules-dir (expand-file-name "modules" user-emacs-directory))
    (add-to-list 'load-path my/modules-dir)

    (defun my/tangle-modules ()
      "Tangle org files if newer than el files."
      (when (file-directory-p my/modules-dir)
        (require 'ob-tangle)
        (dolist (org-file (directory-files my/modules-dir t "\\.org$"))
          (let* ((base (file-name-base org-file))
                 (el-file (expand-file-name (concat base ".el") my/modules-dir)))
            (when (or (not (file-exists-p el-file))
                      (file-newer-than-file-p org-file el-file))
              (message "Tangling %s..." base)
              (org-babel-tangle-file org-file))))))

    (condition-case err (my/tangle-modules) (error (message "Tangling failed: %s" err)))

    (dolist (module '("00-core" "01-ui" "02-hebrew" "03-completion" "04-editing"
                      "05-navigation" "06-org" "07-org-roam" "08-latex" "09-typst"
                      "10-context" "11-pdf" "12-programming" "13-magit" "14-seforim"
                      "15-rich-footnotes" "16-hydras" "17-utils" "18-academic"
                      "19-hebrew-extra" "20-projectile" "21-local-ai" "22-dirvish"
                      "23-vterm-pro" "24-scholar-search" "25-nix-system"))
      (condition-case err (require (intern module)) (error (message "Failed to load %s: %s" module err))))
    (message "Emacs configuration loaded!")
  '';

  # ══════════════════════════════════════════════════════════════════
  # RECOLL CONFIGURATION
  # ══════════════════════════════════════════════════════════════════

  home.file.".recoll/recoll.conf".text = ''
    topdirs = ${seforimPath}
    followLinks = 1
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf application/epub+zip application/vnd.openxmlformats-officedocument.wordprocessingml.document application/msword application/vnd.oasis.opendocument.text
    [ext]
    org = text/x-org
    skippedNames = .git .svn node_modules .cache __pycache__ *.elc *.pyc *.gz *.zip
    indexstemminglanguages = hebrew english
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000
    unac_except_stripping = true
  '';

  home.file.".recoll/mimeview".text = ''
    [view]
    text/x-org = emacsclient -n %f
    text/org = emacsclient -n %f
    text/plain = emacsclient -n %f
    application/pdf = emacsclient -n %f
    application/epub+zip = emacsclient -n %f
    application/vnd.openxmlformats-officedocument.wordprocessingml.document = emacsclient -n %f
    application/msword = emacsclient -n %f
    application/vnd.oasis.opendocument.text = emacsclient -n %f
  '';

  # ══════════════════════════════════════════════════════════════════
  # ACTIVATION SCRIPTS
  # ══════════════════════════════════════════════════════════════════

  home.file.".cache/emacs/undo-tree-history/.keep".text = "";

  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.config/emacs/modules"
    mkdir -p "${homeDir}/.cache/emacs/seforim"
    mkdir -p "${homeDir}/Documents/org"
    mkdir -p "${homeDir}/Documents/roam/daily"
    mkdir -p "${seforimPath}/Bavli"

    if [ ! -f "${homeDir}/Documents/org/inbox.org" ]; then
      cat > "${homeDir}/Documents/org/inbox.org" << 'ORGEOF'
#+TITLE: Inbox
#+FILETAGS: inbox
* Tasks
* Notes
ORGEOF
    fi

    if [ ! -f "${homeDir}/Documents/org/journal.org" ]; then
      echo "#+TITLE: Journal" > "${homeDir}/Documents/org/journal.org"
    fi

    if [ ! -f "${homeDir}/Documents/org/research.org" ]; then
      cat > "${homeDir}/Documents/org/research.org" << 'ORGEOF'
#+TITLE: Research
#+FILETAGS: research
* Inbox
ORGEOF
    fi

    if [ ! -f "${homeDir}/Documents/bibliography.bib" ]; then
      echo "% Bibliography" > "${homeDir}/Documents/bibliography.bib"
    fi

    if [ ! -f "${homeDir}/.cache/emacs/seforim/study-log.el" ]; then
      echo "nil" > "${homeDir}/.cache/emacs/seforim/study-log.el"
    fi
  '';
}
