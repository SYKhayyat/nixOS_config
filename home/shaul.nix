# home/shaul.nix
#
# The whole user environment, for every session on this machine.
#
# It used to be three profiles — desktop.nix, niri.nix, study.nix — one per boot
# closure, and that is exactly how they drifted. None of the following was a
# decision; they were three files nobody diffed:
#
#   * p10k.nix and foot.nix were imported by desktop.nix only, while common.nix
#     loads the powerlevel10k plugin everywhere and sources ~/.p10k.zsh — which
#     only p10k.nix writes. niri and study booted with an unconfigured prompt,
#     and with `Mod+Return` bound to a foot that nothing configured.
#   * kdePackages.dolphin was installed by niri and study; Hyprland is the
#     session that binds Mod+E to it. Plasma ships it system-wide, so the gap
#     was invisible until you booted the one session that forced Plasma off.
#   * niri had no idle daemon (see modules/home/lock.nix) and yazi was
#     configured in the compositor sessions but not under Plasma, which was the
#     only session that installed the yazi *package*.
#
# One closure, one profile. Every compositor's config is present; the session
# you pick at the greeter reads its own and ignores the others. The only axis
# left is study mode, and it is a boot-time choice because the airgap is.
{
  lib,
  pkgs,
  myConfig,
  osConfig,
  ...
}:

let
  # Set by modules/system/study-offline.nix inside the `study` specialisation.
  study = osConfig.shaulos.study;
in
{
  imports = [
    ./common.nix # zsh, git, aliases, scripts
    ../modules/home/p10k.nix # the prompt common.nix sources
    ../modules/home/foot.nix # the terminal every compositor binds
    ../modules/home/emacs
    ../modules/home/wayland-common.nix # bar, launcher, lock, notifier, yazi
    ../modules/home/niri
    ../modules/home/hyprland
  ];

  stylix.targets.kde.enable = false;
  stylix.targets.qt.enable = false;
  stylix.targets.firefox.profileNames = [ myConfig.username ];
  stylix.fonts.sizes.applications = 9;
  stylix.fonts.sizes.desktop = 9;

  # Off in study mode. The firewall is the backstop, not the feature — the
  # feature is that the thing you open out of habit is not there.
  programs.firefox = {
    enable = !study;
    configPath = lib.mkForce ".mozilla/firefox";
    profiles.${myConfig.username} = {
      settings = {
        "layout.css.devPixelsPerPx" = "1.0";
        "browser.uidensity" = 1;
      };
    };
  };

  # Plasma is in the closure in every session now, so its dotfiles are managed
  # unconditionally. In a tiling session these are files nothing reads.
  # `overrideConfig` still means plasma-manager owns ~/.config/plasma* outright.
  programs.plasma = {
    enable = true;
    overrideConfig = true;

    configFile = {
      "kcmfonts"."General"."forceFontDPI" = 96;
      "kdeglobals"."KScreen"."ScaleFactor" = 1;
      "kdeglobals"."General"."font" = "Noto Sans,9,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."fixed" = "JetBrainsMono Nerd Font,9,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."menuFont" = "Noto Sans,9,-1,5,50,0,0,0,0,0";
      "kdeglobals"."General"."toolBarFont" = "Noto Sans,8,-1,5,50,0,0,0,0,0";
      "kdeglobals"."KDE"."widgetStyle" = "Breeze";
    };

    workspace = {
      lookAndFeel = "org.kde.breeze.desktop";
      theme = "breeze-dark";
      iconTheme = "breeze-dark";
      cursor = {
        theme = "Breeze_Snow";
        size = 24;
      };
    };

    panels = [
      {
        location = "bottom";
        height = 32;
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
        ];
      }
    ];
  };

  # Applications. Study mode gets a different list, not a subset — the whole
  # point of the specialisation is what is absent. (The session toolkit —
  # terminal, file manager, viewer, editor — comes from wayland-common.nix and
  # is present either way.)
  home.packages =
    with pkgs;
    if study then
      [
        ytfzf
        yt-dlp
        mpv
        pandoc
        libreoffice-qt-fresh
      ]
    else
      [
        libreoffice-qt-fresh
        kdePackages.calligra
        ansel
        texmacs
        sile
        gimp-with-plugins
        gimpPlugins.gmic
        gimpPlugins.resynthesizer
        krita
        krita-plugin-gmic
        inkscape-with-extensions
        pinta
        photoflare
        digikam
        rawtherapee
        darktable
        sly
        rapidraw
        graphicsmagick_q16
        art
        aaphoto
        graphite
        vlc
        audacity
        lmms
        scribus
        persepolis
        onedriver
        upscayl
        tor-browser
        qutebrowser
        nushell
        # Moved out of modules/home/hyprland: they were never Hyprland-specific,
        # and that module is imported by every session now.
        pcmanfm-qt
        thunar
      ];

  home.sessionVariables = {
    TERMINAL = "foot";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    GDK_SCALE = "1";
    GDK_DPI_SCALE = "1";
  };
}
