# modules/system/hardware.nix
#
# Laptop hardware: firmware, Bluetooth, memory, and power management.
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

  # ── Bluetooth ──────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;   # battery % for some devices
  };
  # Tray applet for the Wayland (niri/hyprland) sessions; Plasma has bluedevil.
  services.blueman.enable = true;

  # ── Memory: compressed swap in RAM (helps this low-RAM laptop) ───────────
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Wipe /tmp on boot. NOT tmpfs — Nix builds use /tmp and RAM is tight here.
  boot.tmp.cleanOnBoot = true;

  # ── Power management (Intel laptop) ──────────────────────────────────────
  powerManagement.enable = true;
  services.thermald.enable = true;          # Intel thermal daemon

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
