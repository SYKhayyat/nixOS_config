# modules/system/services.nix
# System services: Ollama, OneDrive, file indexing

{ config, lib, pkgs, myConfig, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # OLLAMA (Local LLMs)
  # ══════════════════════════════════════════════════════════════════

  services.ollama = {
    enable = true;
    # Fix: acceleration is now handled via the package variant
    package = pkgs.ollama-cpu;
  };

  # ══════════════════════════════════════════════════════════════════
  # ONEDRIVE
  # ══════════════════════════════════════════════════════════════════

  services.onedrive.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # FILE INDEXING (plocate)
  # Fast file search with 'locate' command
  # ══════════════════════════════════════════════════════════════════

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

  # ══════════════════════════════════════════════════════════════════
  # RECOLL INDEXING SERVICE
  # Runs periodically to index your documents
  # ══════════════════════════════════════════════════════════════════

  systemd.services."recoll-index-${myConfig.username}" = {
    description = "Recoll indexer for ${myConfig.username}";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = myConfig.username;
      Environment = "HOME=${myConfig.homeDir}";
      ExecStart = "${pkgs.recoll}/bin/recollindex";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers."recoll-index-${myConfig.username}" = {
    description = "Recoll indexing timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
  };
}
