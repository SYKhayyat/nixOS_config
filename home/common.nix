# home/common.nix
{ config, lib, pkgs, myConfig, ... }:

{
  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    theme = {
      name = lib.mkDefault "Adwaita-dark";
      package = lib.mkDefault pkgs.gnome-themes-extra;
    };
  };

  home.activation.force-clean-git-files = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for file in ".gtkrc-2.0" ".bashrc"; do
      TARGET="$HOME/$file"
      if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
        echo "Cleanup: Removing $TARGET to allow Nix to manage it."
        $DRY_RUN_CMD rm -f "$TARGET"
      fi
    done
  '';

  home.sessionPath = [
    "${config.home.homeDirectory}/Scripts"
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      if [ -d "$HOME/Scripts" ]; then
        SCRIPTS_PATH=$(find "$HOME/Scripts" -type d -not -path '*/.*' -printf ":%p")
        export PATH="$PATH$SCRIPTS_PATH"
      fi
    '';
  };

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

  home.shellAliases = {
    # REMOVED: to-niri and to-plasma (Use Boot Menu instead)

    # ── NIXOS MANAGEMENT ────────────────────────────────────────────
    nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    nrt = "sudo nixos-rebuild test --flake ~/nixos-config#desktop";
    nrb = "sudo nixos-rebuild build --flake ~/nixos-config#desktop";

    nrs-minimal = "sudo nixos-rebuild switch --flake ~/nixos-config#minimal";
    nfu = "cd ~/nixos-config && nix flake update";
    nconf = "cd ~/nixos-config && $EDITOR .";
    ngc = "sudo nix-collect-garbage --delete-older-than 14d";

    # ── COMMON SHORTCUTS ────────────────────────────────────────────
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
  };

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
