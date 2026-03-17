{ config, pkgs, lib, ... }:

let
  # Change this to your username
  username = "shaul";

  # Change this to your seforim path
  seforimPath = "/home/${username}/Documents/seforim";

  # Define the content of the config files as strings here
  recollConfContent = ''
    # Seforim library indexing configuration
    topdirs = ${seforimPath}

    # Follow symlinks
    followLinks = 1

    # Index these MIME types
    indexedmimetypes = text/x-org text/org text/plain text/markdown application/pdf

    # Treat .org as org-mode
    [ext]
    org = text/x-org

    # Skip junk directories
    skippedNames = .git .svn node_modules .cache __pycache__ *.elc *.pyc *.gz *.zip

    # Hebrew + English stemming
    indexstemminglanguages = hebrew english

    # More context in snippets
    snippetMaxPosWalk = 1000000
    maxTermExpand = 10000

    # Handle Hebrew characters properly
    unac_except_stripping = true
  '';

  recollMimeviewContent = ''
    [view]
    text/x-org = emacsclient -n %f
    text/org = emacsclient -n %f
    text/plain = emacsclient -n %f
    application/pdf = emacsclient -n %f
  '';

in
{
  # ===========================================================================
  # PACKAGES
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # Core search tools
    ripgrep
    fd
    plocate

    # Full-text indexing
    recoll
    xapian

    # For recoll to index various file types
    poppler-utils    # pdftotext
    antiword         # .doc
    catdoc           # .xls
    unzip            # .docx, .odt
  ];

  # ===========================================================================
  # USER GROUP MEMBERSHIP
  # ===========================================================================
  users.users.${username} = {
    extraGroups = [ "plocate" ];
  };

  # ===========================================================================
  # PLOCATE SERVICE (file path indexing)
  # ===========================================================================
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

  # ===========================================================================
  # RECOLL SETUP (full-text indexing)
  # ===========================================================================

  # Create recoll config directory and files for user
  system.activationScripts.recollConfig = let
    confFile = pkgs.writeText "recoll.conf" recollConfContent;
    mimeFile = pkgs.writeText "mimeview" recollMimeviewContent;
  in ''
    mkdir -p /home/${username}/.recoll
    cp -f ${confFile} /home/${username}/.recoll/recoll.conf
    cp -f ${mimeFile} /home/${username}/.recoll/mimeview
    chown -R ${username}:users /home/${username}/.recoll
    chmod 644 /home/${username}/.recoll/recoll.conf
    chmod 644 /home/${username}/.recoll/mimeview
  '';

  # Create seforim directory if it doesn't exist
  system.activationScripts.seforimDir = ''
    mkdir -p ${seforimPath}
    chown ${username}:users ${seforimPath}
  '';

  # ===========================================================================
  # SYSTEMD USER SERVICE (recoll indexing timer)
  # ===========================================================================
  systemd.user.services.recoll-index = {
    description = "Recoll full-text indexer";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.recoll}/bin/recollindex";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.recoll-index = {
    description = "Run recoll indexing periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
  };
}
