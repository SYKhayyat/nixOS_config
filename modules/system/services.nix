{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

{
  # ══════════════════════════════════════════════════════════════════
  # OLLAMA (Local LLMs)
  # ══════════════════════════════════════════════════════════════════

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
  };

  # OneDrive used to be declared here. "How does my data get onto this machine"
  # is answered once, in modules/system/data.nix — and the OneDrive half of the
  # answer is now that it does not: three clients became one and then none, on
  # the grounds that nothing had ever given any of them credentials. See that
  # file's header.

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
