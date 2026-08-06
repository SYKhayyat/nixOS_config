{ config, lib, pkgs, myConfig, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # OLLAMA (Local LLMs)
  # ══════════════════════════════════════════════════════════════════

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
  };

  # OneDrive moved to modules/system/data.nix, which owns every answer to
  # "how does my data get onto this machine" — there used to be three of them
  # in three files, and the `onedriver` package was a second client for the
  # same remote.

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
