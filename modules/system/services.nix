{ config, lib, pkgs, myConfig, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # OLLAMA (Local LLMs)
  # ══════════════════════════════════════════════════════════════════

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
  };

  # ══════════════════════════════════════════════════════════════════
  # ONEDRIVE
  # ══════════════════════════════════════════════════════════════════

  services.onedrive.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # FILE INDEXING (plocate)
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
  # ══════════════════════════════════════════════════════════════════

  systemd.services."recoll-index-${myConfig.username}" = {
    description = "Recoll indexer for ${myConfig.username}";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = myConfig.username;
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
