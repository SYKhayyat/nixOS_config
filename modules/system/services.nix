{
  pkgs,
  ...
}:

{
  # ── Ollama (local LLMs) ──────────────────────────────────────────────────
  # It idles small but loads gigabytes on the first request, on a machine that
  # swaps. `MemoryHigh` makes the kernel throttle it first rather than choosing
  # a victim somewhere else in the session.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
  };
  systemd.services.ollama.serviceConfig.MemoryHigh = "4G";

  # ── File indexing (plocate) ──────────────────────────────────────────────
  # Daily, not hourly. The old interval woke the disk 24×/day to rebuild an
  # index of names that changes slowly; plocate supports incremental updates,
  # but the interval is the cheap fix.
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
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
}
