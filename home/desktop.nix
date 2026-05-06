{ config, lib, pkgs, myConfig, desktopEnvironment ? "plasma", unstable, ... }:

{
  imports = [
    ./common.nix
    ../modules/home/emacs
    ../modules/home/p10k.nix
  ] ++ (if desktopEnvironment == "niri" then [
    ../modules/home/niri
  ] else if desktopEnvironment == "hyprland" then [
    ../modules/home/hyprland
  ] else []);

  # FIX: Disable Stylix KDE/Qt and link Firefox profile for theming
  stylix.targets.kde.enable = false;
  stylix.targets.qt.enable = false;
  stylix.targets.firefox.profileNames = [ myConfig.username ]; # FIX: Stylix profile warning
  stylix.fonts.sizes.applications = 9;
  stylix.fonts.sizes.desktop = 9;

  programs.firefox = {
    enable = true;
    # FIX: Silence the .mozilla/firefox path migration warning
    configPath = ".mozilla/firefox";
    profiles.${myConfig.username} = {
      settings = {
        "layout.css.devPixelsPerPx" = "1.0";
        "browser.uidensity" = 1; # Compact mode for 768p
      };
    };
  };

  programs.plasma = {
    enable = (desktopEnvironment == "plasma");
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

  home.packages = with pkgs; [
    libreoffice-qt-fresh kdePackages.calligra
    gimp-with-plugins gimpPlugins.gmic gimpPlugins.resynthesizer
    krita krita-plugin-gmic inkscape-with-extensions
    pinta photoflare pixeluvo digikam rawtherapee darktable
    sly rapidraw graphicsmagick_q16
    vlc audacity lmms scribus persepolis onedriver
    tor-browser qutebrowser firefox
  ];

  home.sessionVariables = {
    TERMINAL = "foot";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    GDK_SCALE = "1";
    GDK_DPI_SCALE = "1";
  };
}
