# modules/home/emacs/default.nix
# Emacs configuration for Home Manager
# Uses Emacs 30 (pgtk) with comprehensive package set

{ config, lib, pkgs, myConfig, ... }:

let
  # ══════════════════════════════════════════════════════════════════
  # EMACS BUILD - Using Emacs 30 for best performance
  # ══════════════════════════════════════════════════════════════════

  # Use Emacs 30 with PGTK (Wayland support)
  emacs = pkgs.emacs30-pgtk or pkgs.emacs30 or pkgs.emacs29-pgtk;

  # Create emacs with all packages (none installed via :ensure)
emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
  # ══════════════════════════════════════════════════════════════════
  # CORE PACKAGES - Needed for base functionality
  # ══════════════════════════════════════════════════════════════════
  use-package
  dash
  s
  f
  seq
  cl-lib
  diminish

  # ══════════════════════════════════════════════════════════════════
  # UI & APPEARANCE
  # ══════════════════════════════════════════════════════════════════
  doom-themes
  doom-modeline
  nerd-icons
  all-the-icons
  all-the-icons-dired
  pulsar
  shrink-path  # Required by doom-modeline

  # ══════════════════════════════════════════════════════════════════
  # COMPLETION & SEARCH
  # ══════════════════════════════════════════════════════════════════
  vertico
  orderless
  marginalia
  consult
  embark
  embark-consult
  corfu
  anzu
  deadgrep
  engine-mode

  # ══════════════════════════════════════════════════════════════════
  # EDITING
  # ══════════════════════════════════════════════════════════════════
  undo-tree
  avy
  ace-window
  multiple-cursors
  expand-region
  move-text
  crux
  visual-regexp
  wgrep
  rainbow-delimiters
  goto-last-change
  beginend

  # ══════════════════════════════════════════════════════════════════
  # FILE & BUFFER MANAGEMENT
  # ══════════════════════════════════════════════════════════════════
  projectile
  consult-projectile
  dirvish
  # recentf and savehist are built into Emacs - do NOT list them here

  # ══════════════════════════════════════════════════════════════════
  # ORG & NOTES
  # ══════════════════════════════════════════════════════════════════
  org
  org-modern
  org-download
  org-roam
  org-roam-ui
  ox-pandoc
  citar
  citar-org-roam
  citeproc

  # ══════════════════════════════════════════════════════════════════
  # TERMINAL & TOOLS
  # ══════════════════════════════════════════════════════════════════
  vterm
  pdf-tools
  jinx
  gptel

  # ══════════════════════════════════════════════════════════════════
  # PROGRAMMING
  # ══════════════════════════════════════════════════════════════════
  magit
  git-gutter
  git-timemachine
  eglot
  eglot-java
  treesit-grammars.with-all-grammars
  treesit-auto
  rust-mode
  cargo
  nix-mode
  markdown-mode
  typst-ts-mode
  yasnippet
  yasnippet-snippets
  editorconfig
  envrc
  helpful
  which-key

  # ══════════════════════════════════════════════════════════════════
  # UTILITIES
  # ══════════════════════════════════════════════════════════════════
  gcmh
  hydra
  restart-emacs
  visual-fill-column
]);

  # Paths
  seforimPath = myConfig.seforimPath;
  homeDir = config.home.homeDirectory;

in
{
  # ══════════════════════════════════════════════════════════════════
  # PACKAGES
  # ══════════════════════════════════════════════════════════════════

  home.packages = with pkgs; [
    emacsWithPackages

    # LaTeX (full installation)
    texlive.combined.scheme-full

    # Typst (modern typesetting)
    typst
    tinymist


    # Utilities for Emacs
    sqlite          # For org-roam
    graphviz        # For org diagrams
    imagemagick     # Image manipulation
    tree-sitter     # Syntax parsing
    fd              # Fast file search
    ripgrep         # Fast text search
    recoll          # Full-text search for seforim

    # Language servers
    jdt-language-server  # Java
    nil                 # Nix LSP
    rust-analyzer       # Rust LSP
    pyright             # Python LSP
    lua-language-server # Lua LSP

    # Tools for emacs packages
    plocate           # For seforim fast search
    hdate
  ];

  # ══════════════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ══════════════════════════════════════════════════════════════════

  home.sessionVariables = {
  EDITOR = "emacs";
  VISUAL = "emacs";
};
  # ══════════════════════════════════════════════════════════════════
  # EMACS CONFIGURATION FILES
  # ══════════════════════════════════════════════════════════════════

  # early-init.el - Runs before package system initializes
  home.file.".config/emacs/early-init.el".text = ''
    ;;; early-init.el - Optimizations before package loading
    ;; This runs before package.el and before init.el

    (setq package-enable-at-startup nil)
    (setq load-prefer-newer t)

    (setq native-comp-eln-load-path
      (list (expand-file-name "~/.cache/emacs/eln-cache/")))

    ;; Performance tuning
    (setq gc-cons-threshold most-positive-fixnum
          gc-cons-percentage 0.6)

    ;; Native compilation
    (setq native-comp-async-report-warnings-errors 'silent
          native-comp-jit-compilation t)

    ;; Silence warnings
    (setq warning-suppress-types '((comp) (bytecomp)))

    ;; Defer file name handler
    (defvar my--file-name-handler-alist file-name-handler-alist)
    (setq file-name-handler-alist nil)
    (add-hook 'emacs-startup-hook
              (lambda () (setq file-name-handler-alist my--file-name-handler-alist)))
  '';

 home.file.".config/emacs/init.el".text = ''
  ;; init.el --- Modular Emacs configuration -*- lexical-binding: t; -*-

  ;; Modules directory (where .org and .el files live)
  (defvar my/modules-dir (expand-file-name "modules" user-emacs-directory))

  ;; Add to load-path
  (add-to-list 'load-path my/modules-dir)

  ;; Tangle function
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

  ;; Tangle on startup
  (condition-case err
      (my/tangle-modules)
    (error (message "Tangling failed: %s" err)))

  ;; Load modules
  (dolist (module '("00-core"
                    "01-ui"
                    "02-hebrew"
                    "03-completion"
                    "04-editing"
                    "05-navigation"
                    "06-org"
                    "07-org-roam"
                    "08-latex"
                    "09-typst"
                    "10-context"
                    "11-pdf"
                    "12-programming"
                    "13-magit"
                    "14-seforim"
                    "15-rich-footnotes"
                    "16-hydras"
                    "17-utils"
                    "18-academic"
                    "19-hebrew-extra"
                    "20-projectile"
                    "21-local-ai"
                    "22-dirvish"
                    "23-vterm-pro"
                    "24-scholar-search"
                    "25-nix-system"))
    (condition-case err
        (require (intern module))
      (error (message "Failed to load %s: %s" module err))))

  (message "Emacs configuration loaded!")
'';

  # Master config.org that will tangle all modules
  # home.file.".config/emacs/config.org".source = ./config.org;

  # Create modules directory
  home.activation.createEmacsModules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.config/emacs/modules"
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
  # DIRECTORY CREATION
  # ══════════════════════════════════════════════════════════════════

  # Create undo-tree history directory
home.file.".cache/emacs/undo-tree-history/.keep".text = "";

  # ══════════════════════════════════════════════════════════════════
  # ORG FILES AND DIRECTORIES
  # Creates directories and default files if they don't exist
  # ══════════════════════════════════════════════════════════════════

  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Create directories
    mkdir -p "${homeDir}/Documents/org"
    mkdir -p "${homeDir}/Documents/roam/daily"
    mkdir -p "${seforimPath}"

    # Create inbox.org if it doesn't exist
    if [ ! -f "${homeDir}/Documents/org/inbox.org" ]; then
      cat > "${homeDir}/Documents/org/inbox.org" << 'ORGEOF'
#+TITLE: Inbox
#+FILETAGS: inbox

* Tasks

* Notes
ORGEOF
    fi

    # Create journal.org if it doesn't exist
    if [ ! -f "${homeDir}/Documents/org/journal.org" ]; then
      echo "#+TITLE: Journal" > "${homeDir}/Documents/org/journal.org"
    fi

    # Create research.org if it doesn't exist
    if [ ! -f "${homeDir}/Documents/org/research.org" ]; then
      cat > "${homeDir}/Documents/org/research.org" << 'ORGEOF'
#+TITLE: Research
#+FILETAGS: research

* Inbox
ORGEOF
    fi

    # Create bibliography.bib if it doesn't exist
    if [ ! -f "${homeDir}/Documents/bibliography.bib" ]; then
      echo "% Bibliography" > "${homeDir}/Documents/bibliography.bib"
    fi
  '';
}
