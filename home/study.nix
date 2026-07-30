{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ./common.nix                                                 # zsh, p10k, git, aliases, scripts
    (import ../modules/home/wayland-common.nix { xdgDesktop = "hyprland"; })
    ../modules/home/emacs
    ../modules/home/hyprland                                     # launches waybar/mako/udiskie/swww itself
  ];

  # ── Force browsers OFF (study/offline mode) ─────────────────
  programs.firefox.enable = lib.mkForce false;

  # ── Study-specific extras (beyond the shared Wayland toolkit) ─
  home.packages = with pkgs; [
    ytfzf
    yt-dlp
    mpv
    kdePackages.dolphin          # used by the yazi "reveal" opener
    libreoffice-qt-fresh
    pandoc
  ];
}
