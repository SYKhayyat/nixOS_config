# modules/system/hardware.nix
#
# Laptop hardware: firmware, graphics, memory, and power management.
#
# The Lamdan report could not tell from the repo whether that first word was
# true, and said so — one of two questions it closed with. The host is called
# `desktop`, it lives in hosts/desktop/, and hardware-configuration.nix shows a
# swap *partition* and `kvm-intel` with nothing battery-shaped anywhere in it.
# Against that, this file said "Laptop hardware", configured TLP with
# `START/STOP_CHARGE_THRESH_BAT0`, enabled thermald and `powerManagement`, and
# the Hyprland config used to hardcode a 1366x768 panel. If it were a desktop,
# the charge-threshold block would be configuring hardware that does not exist.
#
# **Answered: it is a laptop.** The name is just a name — one of several
# machines, some of which live on mains and some of which do not. So every
# option below stays, including the 40/80 thresholds, which are the half that
# only pays off on a box that spends its life plugged in and would otherwise
# hold a full charge at 100% until the cells swell.
#
# Two consequences worth writing down rather than acting on:
#
#   * `hosts/desktop/` and `networking.hostName = "desktop"` are now known to be
#     misnomers. Renaming means a new hostname on a live machine — ssh host
#     keys, `known_hosts`, `myConfig.flakePath` — and is a deliberate act, not
#     tidying. Left alone on purpose.
#   * "several machines" is the other half of the report's closing question. If
#     a second one ever gets a config in here, this file is the first thing that
#     has to stop being a singleton: it is written for *this* laptop's battery
#     and this laptop's RAM. `hosts/<name>/` plus a shared `modules/system/` is
#     the shape, and none of it is worth building for a host count of one.
{ lib, ... }:

{
  # ── Firmware (Wi-Fi/Bluetooth blobs, Intel microcode via hardware-config) ──
  hardware.enableRedistributableFirmware = true;

  # ── Graphics ────────────────────────────────────────────────────────────
  # Mesa and the 32-bit/VA-API plumbing every Wayland session needs. It was in
  # core.nix, which is where settings went when there was no rule about where
  # settings go; this is the hardware file.
  hardware.graphics.enable = true;

  # Bluetooth moved to ./desktop.nix, next to KDE Connect. It reads like
  # hardware and it is not: `hardware.enableRedistributableFirmware` above is
  # the part that is true of the machine, and it stays. `bluetoothd` and the
  # blueman tray are a *feature* — a running daemon and a pairing UI, of a
  # piece with the phone pairing already in that file — and features are what
  # the `focus` closure declines by not importing the file they are in. This
  # one had to move for the same reason ./network.nix exists: `focus` wants
  # this laptop's graphics, zram and TLP, so it imports this file, and it could
  # not have taken the radio away without a `mkForce`.

  # ── Memory: compressed swap in RAM (helps this low-RAM laptop) ───────────
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ── The two knobs that decide whether the block above does anything ──────
  #
  # nixpkgs' zram module (nixos/modules/config/zram.nix) sets exactly one thing
  # beyond creating the device: `swap-priority = 5`, so zram outranks the disk
  # swap partition, which sits at -2. It sets no `vm.*` sysctl at all, and
  # neither did anything else in this repo — so zram comes up on kernel
  # defaults, and the kernel's defaults are tuned for swap that lives on a
  # spinning disk. Both of them are actively wrong once swap is compressed RAM:
  #
  #   `swappiness` is the balance between reclaiming anonymous pages (swap) and
  #     dropping file-backed ones (page cache). The default of 60 is a hedge
  #     against swap being slow. Here the anonymous page costs one zstd
  #     compression at RAM speed, and the file page it would evict instead
  #     costs a future NVMe read — so swapping is the *cheaper* of the two and
  #     should be preferred, which is what values above 100 express. 180 is
  #     what systemd's zram-generator documents and what Fedora ships with the
  #     same setup. Lower it toward 120 if `/proc/swaps` shows the disk
  #     partition filling up: that means zram is full and the overflow is
  #     landing on the SSD, which is the situation this whole block exists to
  #     avoid.
  #
  #   `page-cluster` is swap readahead, as a power of two — the default of 3
  #     faults in 8 pages at a time. Readahead is how you amortise a seek, and
  #     zram has no seek. All the default buys is 8 decompressions to serve the
  #     one page that was actually asked for. 0 is the standard value for zram.
  #
  # Worth stating plainly, because it is why these are separate from the fix
  # they support: this is NOT what has been thrashing the machine. zram had
  # simply never run — the config above was correct and the *running*
  # generation predated it, so `/proc/swaps` had only the NVMe partition and
  # 1.34 TB was paged in off it across five days of uptime, with `io` pressure
  # stalled 15% of the time. Building this closure is what fixes that. These
  # two lines are what stop the fix from arriving half-configured.
  #
  # In ./hardware.nix rather than in the specialisations because it is true of
  # this laptop in every closure — `focus` imports this file, and so does the
  # base system that will still be running Plasma and Firefox.
  #
  # (`vm.watermark_scale_factor` is the documented third knob — raising it from
  # 10 makes kswapd start reclaiming earlier and trade direct-reclaim stalls
  # for background work. Deliberately not set: unlike the two above it is not a
  # correction of an assumption zram invalidates, it is a guess at a workload,
  # and this repo has enough of those to unwind already.)
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  # Wipe /tmp on boot. NOT tmpfs — Nix builds use /tmp and RAM is tight here.
  boot.tmp.cleanOnBoot = true;

  # ── Power management (Intel laptop) ──────────────────────────────────────
  powerManagement.enable = true;
  services.thermald.enable = true; # Intel thermal daemon

  # TLP for battery life. It conflicts with power-profiles-daemon, so make sure
  # the latter (sometimes pulled in by desktop modules) is off.
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Charge to 80%, don't start again until 40%. This is the setting the
      # report flagged as possibly configuring hardware that isn't there; it is
      # there. It buys cell life on a machine that sits on mains, at the price
      # of a fifth of the runtime on the days it doesn't — which is the right
      # side of that trade here, and the two numbers to change if it stops
      # being. Silently ignored on a battery whose firmware has no thresholds,
      # which is a real possibility and not a reason to leave it out.
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };
}
