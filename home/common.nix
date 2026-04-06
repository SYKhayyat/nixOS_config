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
  # GTK & FORCE OVERWRITE (Fallback)
  # ══════════════════════════════════════════════════════════════════

  # Using the GTK module as the fallback. 
  # lib.mkDefault (Priority 1000) allows other modules to override these values.
  gtk = {
    enable = true;
    theme = {
      name = lib.mkDefault "Adwaita-dark";
      package = lib.mkDefault pkgs.gnome-themes-extra;
    };
  };

  # Advanced Git Overwrite Solution:
  # This script runs BEFORE Home Manager checks for collisions (checkLinkTargets).
  # It identifies specific files that are managed by Nix but currently exist 
  # as "real" files (from your Git repo). It deletes them so Nix can link them.
  home.activation.force-clean-git-files = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for file in ".gtkrc-2.0" ".bashrc"; do
      TARGET="$HOME/$file"
      if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
        echo "Cleanup: Removing $TARGET to allow Nix to manage it."
        $DRY_RUN_CMD rm -f "$TARGET"
      fi
    done
  '';

  # ══════════════════════════════════════════════════════════════════
  # SESSION PATH
  # Static paths available to both GUI and Terminal
  # ══════════════════════════════════════════════════════════════════

  home.sessionPath = [
    "${config.home.homeDirectory}/Scripts"
  ];

  # ══════════════════════════════════════════════════════════════════
  # BASH CONFIGURATION
  # Handles dynamic pathing and shell hooks
  # ══════════════════════════════════════════════════════════════════

  programs.bash = {
    enable = true;
    # This snippet runs every time you open a terminal
    initExtra = ''
      # Dynamically add all subdirectories of ~/Scripts to PATH
      if [ -d "$HOME/Scripts" ]; then
        # Find all directories, ignore hidden ones, and append with colon
        SCRIPTS_PATH=$(find "$HOME/Scripts" -type d -not -path '*/.*' -printf ":%p")
        export PATH="$PATH$SCRIPTS_PATH"
      fi
    '';
  };

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
  # Quick commands for common tasks
  # ══════════════════════════════════════════════════════════════════

  home.shellAliases = {
    # ── SYSTEM SWITCHING (Live) ─────────────────────────────────────
    to-niri = "sudo /run/current-system/specialisation/niri/bin/switch-to-configuration switch";
    to-plasma = "sudo /run/current-system/bin/switch-to-configuration switch";

    # ── NIXOS MANAGEMENT ────────────────────────────────────────────
    nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    nrt = "sudo nixos-rebuild test --flake ~/nixos-config#desktop";
    nrb = "sudo nixos-rebuild build --flake ~/nixos-config#desktop";

    # Switch to minimal
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
  # PROGRAMS & TOOLS
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
