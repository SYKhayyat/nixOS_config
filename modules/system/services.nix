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
  # RECOLL INDEXING SERVICE — off, and it indexed for nobody
  # ══════════════════════════════════════════════════════════════════
  #
  # Switched off with `extras`. modules/home/emacs/default.nix sets
  # EMACS_MODULE_GROUPS = "essentials", and every `recoll' call site in the
  # Emacs config lives in `extras/'. That alone is the rule this repo now
  # applies everywhere: machinery that serves code which does not load gets
  # switched off in the same commit, not left running with a comment that has
  # quietly become false.
  #
  # But the stronger reason is the one that would still hold with `extras` on,
  # and it is worth writing down because nothing in this repo had noticed it:
  #
  #   **this timer's index was never the one Emacs searched.**
  #
  # `extras/15-seforim-dream.org' keeps a *private* recoll config directory at
  # ~/.cache/emacs/seforim/recoll, writes its own recoll.conf into it, and runs
  # `recollindex -c <that dir>' — deliberately, so that it "never touches a
  # system-wide recoll setup". `seforim-recoll-search' queries the same private
  # index. This unit ran `recollindex` with no `-c`, so it read
  # ~/.recoll/recoll.conf (also now commented out, in emacs/default.nix) and
  # wrote ~/.recoll/xapiandb — a second index over the same corpus that no
  # caller has ever opened.
  #
  # So this was a four-hourly, nice-19 walk of the whole seforim library,
  # producing an artifact with no reader, since the day it was written. Turning
  # `extras' back on does not justify uncommenting it; `M-x seforim-recoll-index'
  # is what maintains the index that search actually uses.
  #
  # systemd.services."recoll-index-${myConfig.username}" = {
  #   description = "Recoll indexer for ${myConfig.username}";
  #   after = [ "network.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     User = myConfig.username;
  #     ExecStart = "${pkgs.recoll}/bin/recollindex";
  #     Nice = 19;
  #     IOSchedulingClass = "idle";
  #   };
  # };
  #
  # systemd.timers."recoll-index-${myConfig.username}" = {
  #   description = "Recoll indexing timer";
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnBootSec = "5min";
  #     OnUnitActiveSec = "4h";
  #     Persistent = true;
  #   };
  # };
}
