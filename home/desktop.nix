# home/desktop.nix
# Full desktop Home Manager configuration
# All your desktop applications go here

# home/desktop.nix
# Full desktop Home Manager configuration
# All your desktop applications go here

{ config, lib, pkgs, myConfig, unstable, ... }:

{
  imports = [
    ./common.nix
    ../modules/home/emacs
    ../modules/home/niri    # New: This module provides Niri + Yazi + Wayland tools
  ];

  # ══════════════════════════════════════════════════════════════════
  # DESKTOP APPLICATIONS
  # ══════════════════════════════════════════════════════════════════

  home.packages = with pkgs; [

    # ────────────────────────────────────────────────────────────────
    # OFFICE
    # ────────────────────────────────────────────────────────────────
    libreoffice-qt-fresh
    kdePackages.calligra

    # ────────────────────────────────────────────────────────────────
    # GRAPHICS - Image Editing
    # ────────────────────────────────────────────────────────────────
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.resynthesizer
    krita
    krita-plugin-gmic
    inkscape-with-extensions
    pinta
    photoflare
    pixeluvo

    # ────────────────────────────────────────────────────────────────
    # GRAPHICS - Photo Management
    # ────────────────────────────────────────────────────────────────
    digikam
    rawtherapee
    darktable
    sly
    rapidraw

    # ────────────────────────────────────────────────────────────────
    # GRAPHICS - Utilities
    # ────────────────────────────────────────────────────────────────
    graphicsmagick_q16

    # ────────────────────────────────────────────────────────────────
    # MEDIA - Video
    # ────────────────────────────────────────────────────────────────
    vlc

    # ────────────────────────────────────────────────────────────────
    # MEDIA - Audio
    # ────────────────────────────────────────────────────────────────
    audacity
    lmms

    # ────────────────────────────────────────────────────────────────
    # PUBLISHING
    # ────────────────────────────────────────────────────────────────
    scribus

    # ────────────────────────────────────────────────────────────────
    # UTILITIES - Downloads
    # ────────────────────────────────────────────────────────────────
    persepolis

    # ────────────────────────────────────────────────────────────────
    # UTILITIES - Cloud Storage
    # ────────────────────────────────────────────────────────────────
    onedriver

    # ────────────────────────────────────────────────────────────────
    # UTILITIES - Privacy
    # ────────────────────────────────────────────────────────────────
    tor-browser
  ];
}
