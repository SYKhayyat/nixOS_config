# home/common.nix
# Common Home Manager settings for all profiles

# home/common.nix
# Common Home Manager settings for all profiles

{ config, lib, pkgs, myConfig, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # HOME MANAGER BASICS
  # ══════════════════════════════════════════════════════════════════

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # SESSION PATH
  # Adds your Scripts directories to PATH
  # ══════════════════════════════════════════════════════════════════

  home.sessionPath = [
    "${config.home.homeDirectory}/Scripts"
    "${config.home.homeDirectory}/Scripts/docx_to_org_regular"
    "${config.home.homeDirectory}/Scripts/docx_to_org_enhanced"
    "${config.home.homeDirectory}/Scripts/finder"
  ];

  # ══════════════════════════════════════════════════════════════════
  # XDG DIRECTORIES
  # Standard user directories
  # ══════════════════════════════════════════════════════════════════

  xdg.enable = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
  };

  # ══════════════════════════════════════════════════════════════════
  # SHELL ALIASES
  # ══════════════════════════════════════════════════════════════════

  home.shellAliases = {
    # ── SYSTEM SWITCHING (Live) ─────────────────────────────────────
    # Switches to the Niri environment without rebooting
    to-niri = "sudo /run/current-system/specialisation/niri/bin/switch-to-configuration switch";
    # Returns to the standard KDE Plasma environment
    to-plasma = "sudo /run/current-system/bin/switch-to-configuration switch";

    # ── NIXOS MANAGEMENT ────────────────────────────────────────────
    nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    nrt = "sudo nixos-rebuild test --flake ~/nixos-config#desktop";
    nrb = "sudo nixos-rebuild build --flake ~/nixos-config#desktop";

    # Switch to minimal profile
    nrs-minimal = "sudo nixos-rebuild switch --flake ~/nixos-config#minimal";

    # Update flake inputs
    nfu = "cd ~/nixos-config && nix flake update";

    # Edit configuration
    nconf = "cd ~/nixos-config && $EDITOR .";

    # Garbage collection
    ngc = "sudo nix-collect-garbage --delete-older-than 14d";

    # ── COMMON SHORTCUTS ────────────────────────────────────────────
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
  };

  # ══════════════════════════════════════════════════════════════════
  # PROGRAMS
  # ══════════════════════════════════════════════════════════════════

  programs.git = {
    enable = true;
    settings = {
      user.name = myConfig.fullName;
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
