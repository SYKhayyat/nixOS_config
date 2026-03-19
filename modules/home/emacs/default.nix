# modules/home/emacs/default.nix
# Emacs configuration for Home Manager
# Includes Emacs packages, LaTeX, Typst, Recoll config, and org setup

{ config, lib, pkgs, myConfig, ... }:

let
  # ══════════════════════════════════════════════════════════════════
  # EMACS BUILD
  # ══════════════════════════════════════════════════════════════════

  emacs = pkgs.emacs29-pgtk or pkgs.emacs-pgtk or pkgs.emacs29;

  emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: [
    # Packages that need native compilation or system dependencies
    epkgs.vterm
    epkgs.pdf-tools
    epkgs.jinx

    # Org-roam and dependencies
    epkgs.org-roam

    # Magit (Git integration)
    epkgs.magit
    epkgs.transient
    epkgs.with-editor

    # Tree-sitter grammars
    epkgs.treesit-grammars.with-all-grammars

    # Consult-projectile
    epkgs.consult-projectile
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
    # Emacs
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

    # Language servers
    jdt-language-server  # Java
  ];

  # ══════════════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ══════════════════════════════════════════════════════════════════

  home.sessionVariables = {
    EDITOR = "emacsclient -c";
    VISUAL = "emacsclient -c";
  };

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
  home.file.".emacs.d/undo-tree-history/.keep".text = "";

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
