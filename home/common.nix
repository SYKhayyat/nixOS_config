{ config, lib, pkgs, myConfig, ... }:

let
  plasmaWipe = pkgs.writeShellScriptBin "plasma-wipe" ''
    echo "══════════════════════════════════════════════════════════════"
    echo "          KDE PLASMA 6 NUCLEAR WIPE SCRIPT"
    echo "══════════════════════════════════════════════════════════════"
    read -p "Proceed? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        killall -u ${myConfig.username} kwin_wayland plasmashell 2>/dev/null || true
        rm -rf ~/.config/plasma* ~/.config/kde* ~/.config/kdeglobals ~/.config/kwin*
        rm -rf ~/.local/share/plasma* ~/.local/share/desktop-directories
        rm -rf ~/.cache/plasma* ~/.cache/kde* ~/.cache/kwin*
        rm -f ~/.config/zsh/.p10k.zsh ~/.p10k.zsh
        echo "Wipe complete. Rebooting..."
        sudo reboot
    fi
  '';
in
{
  imports = [ ./../modules/home/scripts.nix ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # FIX: Silence GTK4 warning
  gtk.gtk4.theme = null;

  home.activation.force-clean-git-files = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    for file in ".gtkrc-2.0" ".bashrc"; do
      TARGET="$HOME/$file"
      if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
        echo "Cleanup: Removing $TARGET to allow Nix to manage it."
        $DRY_RUN_CMD rm -f "$TARGET"
      fi
    done
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # FIX: Absolute path logic for NixOS 25.11 to silence deprecation warning
dotDir = lib.mkForce "${config.home.homeDirectory}/.config/zsh";
    oh-my-zsh = {
      enable = true;
      theme = "";
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
    nrs = "sudo nixos-rebuild switch --flake ${myConfig.flakePath}#${myConfig.hostname}";
    nrt = "sudo nixos-rebuild test --flake ${myConfig.flakePath}#${myConfig.hostname}";
    nfu = "nix flake update --flake ${myConfig.flakePath}";
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
  };

  # Only the script this file defines. Everything else that used to be on this
  # line — pamixer, brightnessctl, playerctl, libsecret, jq, fd, fzf — was a
  # tool, and tools live in modules/home/toolkit.nix now, where the `study` flag
  # can reach them. Two of them (`fd`, `fzf`) were also already in
  # modules/system/cli-tools.nix, and `fzf` was a third time over: `programs.fzf`
  # below installs the package as part of configuring it, exactly as
  # `programs.bat` and `programs.git` do.
  home.packages = [ plasmaWipe ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        email = myConfig.email;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.fzf.enable = true;
  programs.bat.enable = true;
  xdg.enable = true;
}
