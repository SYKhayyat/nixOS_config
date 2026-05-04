{ config, lib, pkgs, myConfig, ... }:

let
  plasmaWipe = pkgs.writeShellScriptBin "plasma-wipe" ''
    echo "KDE PLASMA 6 NUCLEAR WIPE"
    read -p "Proceed? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        killall -u ${myConfig.username} kwin_wayland plasmashell 2>/dev/null || true
        rm -rf ~/.config/plasma* ~/.config/kde* ~/.config/kdeglobals ~/.config/kwin*
        rm -rf ~/.local/share/plasma* ~/.local/share/desktop-directories
        rm -rf ~/.cache/plasma* ~/.cache/kde* ~/.cache/kwin* ~/.cache/kscreen
        echo "Wipe complete. Rebooting..."
        sudo reboot
    fi
  '';
in
{
  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  gtk.gtk4.theme = null;
  xdg.userDirs.setSessionVariables = true;

  home.activation.force-clean-git-files = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for file in ".gtkrc-2.0" ".bashrc"; do
      TARGET="$HOME/$file"
      if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
        $DRY_RUN_CMD rm -f "$TARGET"
      fi
    done
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # FIX: Silences the 25.11 deprecation warning by defining the path clearly
    dotDir = ".config/zsh";

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "systemd" "command-not-found" "sudo" "extract" ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh

      if [ -d "$HOME/Scripts" ]; then
        export PATH="$PATH$(find "$HOME/Scripts" -maxdepth 2 -type d -not -path '.*' -printf ":%p")"
      fi
    '';
  };

  home.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    ll = "ls -la";
  };

  home.packages = with pkgs; [
    pamixer brightnessctl playerctl libsecret plasmaWipe
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        email = "shaul@example.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.fzf.enable = true;
  programs.bat.enable = true;
  programs.direnv.enable = true;
  xdg.enable = true;
}
