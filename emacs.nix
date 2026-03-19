# emacs.nix
#
# Complete NixOS module for Emacs with Hebrew/RTL support

{ config, pkgs, lib, ... }:

let
  # ══════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ══════════════════════════════════════════════════════════════════

  username = "shaul";
  seforimPath = "/home/${username}/Documents/seforim";

  # ══════════════════════════════════════════════════════════════════
  # EMACS BUILD
  # ══════════════════════════════════════════════════════════════════

  emacs = pkgs.emacs29-pgtk or pkgs.emacs-pgtk or pkgs.emacs29;

  emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: [
    # Nix-provided packages (use :ensure nil in config.org)
    epkgs.vterm
    epkgs.pdf-tools
    epkgs.jinx

    # Org-roam and dependencies
    epkgs.org-roam

    # Magit
    epkgs.magit
    epkgs.transient
    epkgs.with-editor

    # Tree-sitter grammars
    epkgs.treesit-grammars.with-all-grammars

    # Consult-projectile
    epkgs.consult-projectile
  ]);

  # ══════════════════════════════════════════════════════════════════
  # SPELL CHECKING
  # ══════════════════════════════════════════════════════════════════

  hunspellDicts = with pkgs.hunspellDicts; [ en_US he_IL ];
  hunspellWithDicts = pkgs.hunspellWithDicts hunspellDicts;

  # ══════════════════════════════════════════════════════════════════
  # RECOLL CONFIGURATION
  # ══════════════════════════════════════════════════════════════════

  recollConf = ''
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

  recollMimeview = ''
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

  # Nerdfonts - handle different NixOS versions
  nerdFontsPkg =
    if builtins.hasAttr "nerd-fonts" pkgs
    then [ pkgs.nerd-fonts.symbols-only pkgs.nerd-fonts.jetbrains-mono ]
    else [ (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" "JetBrainsMono" ]; }) ];

in
{
  # ════════════════════════════════════════════════════════════════════
  # SYSTEM PACKAGES
  # ════════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    # Emacs
    emacsWithPackages

    # Document Systems
    texlive.combined.scheme-full
    typst
    tinymist

    # PDF
    poppler
    poppler-utils

    # Spell Checking
    enchant
    hunspellWithDicts
    (aspellWithDicts (dicts: with dicts; [ en en-computers he ]))

    # Search & Indexing
    plocate
    fd
    ripgrep
    ripgrep-all
    recoll
    xapian

    # Document Converters
    pandoc
    antiword
    catdoc
    unzip

    # Programming Languages
    python3
    python3Packages.python-lsp-server
    rustc
    cargo
    rust-analyzer
    clippy
    jdk
    jdt-language-server
    nil
    nixpkgs-fmt

    # Tree-sitter
    tree-sitter

    # Utilities
    git
    sqlite
    graphviz
    imagemagick
    direnv
  ];

  # ════════════════════════════════════════════════════════════════════
  # FONTS
  # ════════════════════════════════════════════════════════════════════

  fonts.packages = with pkgs; [
    culmus
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts
    jetbrains-mono
    fira-code
    fira-code-symbols
    emacs-all-the-icons-fonts
    source-serif
    source-sans
    source-code-pro
    libertinus
  ] ++ nerdFontsPkg;

  fonts.fontDir.enable = true;

  # ════════════════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ════════════════════════════════════════════════════════════════════

  environment.sessionVariables = {
    DICPATH = lib.mkForce "${hunspellWithDicts}/share/hunspell";
    EDITOR = "emacsclient -c";
    VISUAL = "emacsclient -c";
  };

  environment.variables = {
    OSFONTDIR = "/run/current-system/sw/share/X11/fonts";
  };

  # ════════════════════════════════════════════════════════════════════
  # PROGRAMS
  # ════════════════════════════════════════════════════════════════════

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ════════════════════════════════════════════════════════════════════
  # USER CONFIGURATION
  # ════════════════════════════════════════════════════════════════════

  users.users.${username} = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkAfter [ "plocate" ];
  };

  # ════════════════════════════════════════════════════════════════════
  # PLOCATE (Updated for newer NixOS - no localuser option)
  # ════════════════════════════════════════════════════════════════════

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "hourly";
    # localuser removed in newer NixOS versions
    pruneBindMounts = true;
    prunePaths = [
      "/tmp" "/var/tmp" "/var/cache" "/var/lock" "/var/run" "/var/spool"
      "/nix/store" "/nix/var"
      "/home/*/.cache" "/home/*/.local/share/Trash"
    ];
  };

  # ════════════════════════════════════════════════════════════════════
  # RECOLL SETUP
  # ════════════════════════════════════════════════════════════════════

  system.activationScripts.emacsSetup = let
    confFile = pkgs.writeText "recoll.conf" recollConf;
    mimeFile = pkgs.writeText "mimeview" recollMimeview;
    userHome = "/home/${username}";
  in ''
    USER_GROUP=$(${pkgs.coreutils}/bin/id -gn ${username} 2>/dev/null || echo "users")

    ${pkgs.coreutils}/bin/mkdir -p "${seforimPath}"
    ${pkgs.coreutils}/bin/mkdir -p "${userHome}/.recoll"
    ${pkgs.coreutils}/bin/mkdir -p "${userHome}/Documents/org"
    ${pkgs.coreutils}/bin/mkdir -p "${userHome}/Documents/roam/daily"
    ${pkgs.coreutils}/bin/mkdir -p "${userHome}/.emacs.d/undo-tree-history"

    ${pkgs.coreutils}/bin/cp -f ${confFile} "${userHome}/.recoll/recoll.conf"
    ${pkgs.coreutils}/bin/cp -f ${mimeFile} "${userHome}/.recoll/mimeview"

    if [ ! -f "${userHome}/Documents/bibliography.bib" ]; then
      echo "% Bibliography" > "${userHome}/Documents/bibliography.bib"
    fi

    if [ ! -f "${userHome}/Documents/org/inbox.org" ]; then
      cat > "${userHome}/Documents/org/inbox.org" << 'EOF'
#+TITLE: Inbox
#+FILETAGS: inbox

* Tasks

* Notes
EOF
    fi

    if [ ! -f "${userHome}/Documents/org/journal.org" ]; then
      echo "#+TITLE: Journal" > "${userHome}/Documents/org/journal.org"
    fi

    if [ ! -f "${userHome}/Documents/org/research.org" ]; then
      cat > "${userHome}/Documents/org/research.org" << 'EOF'
#+TITLE: Research
#+FILETAGS: research

* Inbox
EOF
    fi

    ${pkgs.coreutils}/bin/chown -R ${username}:"$USER_GROUP" "${seforimPath}"
    ${pkgs.coreutils}/bin/chown -R ${username}:"$USER_GROUP" "${userHome}/.recoll"
    ${pkgs.coreutils}/bin/chown -R ${username}:"$USER_GROUP" "${userHome}/Documents"
    ${pkgs.coreutils}/bin/chown -R ${username}:"$USER_GROUP" "${userHome}/.emacs.d"
  '';

  # ════════════════════════════════════════════════════════════════════
  # RECOLL INDEXING SERVICE
  # ════════════════════════════════════════════════════════════════════

  systemd.services."recoll-index-${username}" = {
    description = "Recoll indexer for ${username}";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Environment = "HOME=/home/${username}";
      ExecStart = "${pkgs.recoll}/bin/recollindex";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers."recoll-index-${username}" = {
    description = "Recoll indexing timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
  };
}
