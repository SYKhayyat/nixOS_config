# emacs.nix
#
# Complete NixOS module for Emacs with Hebrew/RTL support
#
# Import from configuration.nix:
#   imports = [ ./emacs.nix ];

{ config, pkgs, lib, ... }:

let
  username = "shaul";
  seforimPath = "/home/${username}/Documents/seforim";

  emacs = pkgs.emacs-pgtk;
  epkgs = pkgs.emacsPackagesFor emacs;

  hunspellDictsList = [
    pkgs.hunspellDicts.en_US
    pkgs.hunspellDicts.he_IL
  ];
  dicts = pkgs.hunspellWithDicts hunspellDictsList;

  recollConfContent = ''
    # Seforim library indexing
    topdirs = ${seforimPath}
    followLinks = 1

    # Supported MIME types (single line - Nix doesn't support backslash continuation)
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf application/epub+zip application/vnd.openxmlformats-officedocument.wordprocessingml.document application/msword application/vnd.oasis.opendocument.text

    # Map .org extension
    [ext]
    org = text/x-org

    # Skip patterns
    skippedNames = .git .svn node_modules .cache __pycache__ *.elc *.pyc *.gz *.zip

    # Stemming languages
    indexstemminglanguages = hebrew english

    # Context settings
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000
    unac_except_stripping = true
  '';

  recollMimeviewContent = ''
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

in
{
  # ================================================================
  # EMACS DAEMON
  # ================================================================

  services.emacs = {
    enable = true;
    package = emacs;
    defaultEditor = true;
  };

  # ================================================================
  # PACKAGES
  # ================================================================

  environment.systemPackages = with pkgs; [
    # Emacs with Nix-provided packages
    (epkgs.emacsWithPackages (p: [
      p.jinx
      p.exec-path-from-shell
      p.pdf-tools
    ]))

    # Document systems
    (texlive.combine { inherit (texlive) scheme-full; })
    typst
    tinymist

    # PDF
    poppler
    poppler-utils

    # Spell checking
    enchant2
    dicts

    # Search & indexing
    plocate
    fd
    recoll
    xapian
    ripgrep
    ripgrep-all

    # Document converters (for recoll & ripgrep-all)
    pandoc
    antiword
    catdoc
    unzip
    calibre

    # Programming
    python3
    python3Packages.python-lsp-server
    rustc
    cargo
    rust-analyzer
    jdk
    jdt-language-server

    # Utilities
    git
    sqlite
    graphviz
  ];

  # ================================================================
  # FONTS
  # ================================================================

  fonts.packages = with pkgs; [
    culmus                    # Hebrew
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    liberation_ttf
    dejavu_fonts
    jetbrains-mono
    fira-code
    fira-code-symbols
    emacs-all-the-icons-fonts
    source-serif-pro
    source-sans-pro
    source-code-pro
    libertinus
  ];

  fonts.fontDir.enable = true;

  # ================================================================
  # ENVIRONMENT
  # ================================================================

  environment.sessionVariables = {
    DICPATH = lib.mkForce "${dicts}/share/hunspell";
  };

  environment.variables = {
    OSFONTDIR = "/run/current-system/sw/share/X11/fonts";
  };

  # ================================================================
  # USER
  # ================================================================

  users.users.${username} = {
    extraGroups = [ "plocate" ];
    linger = true;  # Enable user services to run without login
  };

  # ================================================================
  # PLOCATE
  # ================================================================

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "hourly";
    pruneBindMounts = true;
    prunePaths = [
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/var/lock"
      "/var/run"
      "/var/spool"
      "/nix/store"
      "/nix/var"
      "/home/*/.cache"
      "/home/*/.local/share/Trash"
    ];
  };

  # ================================================================
  # RECOLL SETUP
  # ================================================================

  system.activationScripts.seforimSetup = let
    confFile = pkgs.writeText "recoll.conf" recollConfContent;
    mimeFile = pkgs.writeText "mimeview" recollMimeviewContent;
  in ''
    # Create directories
    mkdir -p ${seforimPath}
    mkdir -p /home/${username}/.recoll

    # Write config files
    cp -f ${confFile} /home/${username}/.recoll/recoll.conf
    cp -f ${mimeFile} /home/${username}/.recoll/mimeview

    # Fix permissions
    chown -R ${username}:users ${seforimPath}
    chown -R ${username}:users /home/${username}/.recoll
    chmod 644 /home/${username}/.recoll/recoll.conf
    chmod 644 /home/${username}/.recoll/mimeview
  '';

  # ================================================================
  # RECOLL INDEXING (System service running as user)
  # ================================================================

  systemd.services."recoll-index@${username}" = {
    description = "Recoll indexer for ${username}";
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = "${pkgs.recoll}/bin/recollindex";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers."recoll-index@${username}" = {
    description = "Recoll indexing timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
  };
}
