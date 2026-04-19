# home/desktop.nix
{ config, lib, pkgs, myConfig, unstable, ... }:

{
  imports = [
    ./common.nix
    ../modules/home/emacs
    ../modules/home/niri
  ];

  # ══════════════════════════════════════════════════════════════════
  # DESKTOP APPLICATIONS
  # ══════════════════════════════════════════════════════════════════

  home.packages = with pkgs; [
    libreoffice-qt-fresh
    kdePackages.calligra
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.resynthesizer
    krita
    krita-plugin-gmic
    inkscape-with-extensions
    pinta
    photoflare
    pixeluvo
    digikam
    rawtherapee
    darktable
    sly
    rapidraw
    graphicsmagick_q16
    vlc
    audacity
    lmms
    scribus
    persepolis
    onedriver
    tor-browser
  ];
}
