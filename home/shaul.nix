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
# left is study mode, and it is a boot-time choice because the airgap is — this
# file no longer reads that flag at all: ../modules/home/toolkit.nix owns the
# package set and is the one place the flag subtracts from.
{
  config,
  lib,
  ...
}:

let
  inherit (config.shaulos.palette) font;

  # Plasma stores a font as `family,size,-1,5,weight,italic,underline,strikeout,
  # fixed,0`. Building the string means the family and the size come from
  # stylix — see the note on stylix.targets.kde below for why they otherwise
  # would not.
  qtFont = family: size: "${family},${toString size},-1,5,50,0,0,0,0,0";
  uiSize = font.sizes.applications;
in
{
  imports = [
    ./common.nix # zsh, git, aliases, scripts
    ../modules/home/p10k.nix # the prompt common.nix sources
    ../modules/home/foot.nix # the terminal every compositor binds
    ../modules/home/emacs
    ../modules/home/toolkit.nix # every program you type the name of
    ../modules/home/palette.nix # the stylix scheme, per-syntax
    ../modules/home/wayland-common.nix # bar, launcher, lock, notifier, yazi
    ../modules/home/niri
    ../modules/home/hyprland
  ];

  # `targets.kde` is off, so stylix does not theme Plasma and plasma-manager
  # writes the fonts below itself. That is a decision; the four hardcoded font
  # strings it used to write were not. Deriving them keeps one source of truth
  # for the family and size without turning the KDE target back on.
  stylix.targets.kde.enable = false;
  stylix.targets.qt.enable = false;
  stylix.fonts.sizes.applications = 9;
  stylix.fonts.sizes.desktop = 9;
  # Was `lib.mkForce "…:size=10"` inside modules/home/foot.nix, overriding the
  # font stylix derives for its foot target. Sizes belong with the other sizes.
  stylix.fonts.sizes.terminal = 10;

  # Firefox moved to ../modules/home/toolkit.nix, beside the other three
  # browsers, so "no browsers" is a claim you can check by reading one list.

  # Plasma is in the closure in every session now, so its dotfiles are managed
  # unconditionally. In a tiling session these are files nothing reads.
  # `overrideConfig` still means plasma-manager owns ~/.config/plasma* outright.
  programs.plasma = {
    enable = true;
    overrideConfig = true;

    configFile = {
      "kcmfonts"."General"."forceFontDPI" = 96;
      "kdeglobals"."KScreen"."ScaleFactor" = 1;
      "kdeglobals"."General"."font" = qtFont font.sans uiSize;
      "kdeglobals"."General"."fixed" = qtFont font.mono uiSize;
      "kdeglobals"."General"."menuFont" = qtFont font.sans uiSize;
      # Toolbars a point down, which is Plasma's own convention.
      "kdeglobals"."General"."toolBarFont" = qtFont font.sans (uiSize - 1);
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

  # Applications moved to ../modules/home/toolkit.nix. What was here was an
  # `if study then [ … ] else [ … ]` describing itself as "a different list, not
  # a subset" — and four of the five entries on the study side were already in
  # environment.systemPackages, so that side named things it did not install and
  # the other side omitted things it did not remove. The one package the branch
  # actually controlled was written out in both arms.

  home.sessionVariables = {
    TERMINAL = "foot";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    GDK_SCALE = "1";
    GDK_DPI_SCALE = "1";
  };
}
