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
  # Quick commands for common tasks
  # ══════════════════════════════════════════════════════════════════

  home.shellAliases = {
    # NixOS rebuild shortcuts
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

    # Common shortcuts
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
  };

  # ══════════════════════════════════════════════════════════════════
  # GIT
  # ══════════════════════════════════════════════════════════════════

  programs.git = {
    enable = true;
    
    settings = {
      user.name = myConfig.fullName;
      # user.email = "your.email@example.com";  # Add your email
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
  # ══════════════════════════════════════════════════════════════════
  # FZF (Fuzzy Finder)
  # ══════════════════════════════════════════════════════════════════

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  # ══════════════════════════════════════════════════════════════════
  # BAT (Better cat)
  # ══════════════════════════════════════════════════════════════════

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  # ══════════════════════════════════════════════════════════════════
  # DIRENV
  # Automatic environment loading
  # ══════════════════════════════════════════════════════════════════

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
