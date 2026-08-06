# modules/system/hardware.nix
# Laptop hardware: firmware, Bluetooth, memory, and power management.
{ config, lib, pkgs, ... }:

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
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;   # ignored if the laptop lacks thresholds
    };
  };
}
