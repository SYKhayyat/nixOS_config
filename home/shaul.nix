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
  ...
}:

let
  inherit (config.shaulos.palette) font cursor;
  inherit (config.shaulos.keys) keyboard;

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

  # ── The two stylix targets that stay off, and why ────────────────────────
  #
  # `targets.kde` is off, so stylix does not theme Plasma and plasma-manager
  # writes the fonts below itself. That is a decision; the four hardcoded font
  # strings it used to write were not. Deriving them keeps one source of truth
  # for the family and size without turning the KDE target back on.
  #
  # `targets.qt` is off *here* and on at the system level, which looks
  # inconsistent and is not. They are different modules with different logic:
  # stylix's NixOS Qt target reads `plasma6.enable` and computes
  # `platformTheme = "kde"` / `style = "breeze"`, which is exactly this machine
  # (see ../modules/system/appearance.nix, where the hand-written copy of that
  # answer used to live). The home-manager one has no desktop detection at all —
  # its `platform` option simply defaults to `"qtct"`, from which it picks
  # `style.name = "kvantum"`, installs a Kvantum theme built from the base16
  # scheme and writes qt5ct/qt6ct settings files. That is a coherent look; it is
  # just not Breeze, and Breeze is what Plasma renders. Turning this one on
  # would have Qt apps disagree with the desktop they sit in.
  stylix.targets.kde.enable = false;
  stylix.targets.qt.enable = false;

  # `stylix.fonts.sizes.applications`, `.desktop` and `.terminal` used to be
  # stated here, at 9, 9 and 10. They are in ../modules/system/appearance.nix
  # now, derived from one `uiSize` — that file is where you change how big text
  # is, and its header says so.
  #
  # This was not a free move: stylix's home-manager integration already copies
  # all four sizes down from the system config with `mkDefault`, so these three
  # lines were overriding the value they were meant to inherit. The `9` here and
  # the `9` there would have been two facts the day one of them changed. What
  # reads them below — `uiSize`, and the toolbar font a point under it — did not
  # have to change at all, which is the point of having read them from stylix.

  # Firefox moved to ../modules/home/toolkit.nix, beside the other three
  # browsers, so "no browsers" is a claim you can check by reading one list.

  # Plasma is in the closure in every session now, so its dotfiles are managed
  # unconditionally. In a tiling session these are files nothing reads.
  # `overrideConfig` still means plasma-manager owns ~/.config/plasma* outright.
  programs.plasma = {
    enable = true;
    overrideConfig = true;

    # ── The keyboard, which Plasma had never been told about ────────────────
    #
    # This is the one that had been quietly broken the whole time, and it is
    # worth spelling out because the symptom looked like flakiness rather than
    # like a missing statement.
    #
    # KWin does not read `services.xserver.xkb`. NixOS does not export
    # `XKB_DEFAULT_*` from it either — doing that by hand is a documented
    # workaround precisely because the console and some Wayland compositors
    # ignore the option. KWin reads `kxkbrc`, and `overrideConfig = true` three
    # lines up means plasma-manager owns `kxkbrc` outright: it is reset on every
    # activation, and nothing here declared a keyboard.
    #
    # So Plasma — the *default* session — fell back to bare `us` with no
    # options. Set it in System Settings and it survived exactly until the next
    # `just switch`, which is what "it works sometimes" actually was.
    #
    # plasma-manager writes `LayoutList` and `Options` and sets
    # `ResetOldOptions = true`, so this is now the whole statement for KWin.
    # `layouts` wants a list of submodules; niri and Hyprland want the joined
    # string. Both come off `myConfig.keyboard` via ../modules/home/keys.nix,
    # which is the module both compositors already read.
    input.keyboard = {
      layouts = map (l: { layout = l; }) keyboard.layouts;
      inherit (keyboard) options repeatDelay repeatRate;
    };

    configFile = {
      # 96, and it should stay 96: it is the denominator that makes a point mean
      # 4/3 of a pixel, not a size knob. Text size is `uiSize` in
      # ../modules/system/appearance.nix. Lowering this instead would shrink
      # text by scaling every point size Qt is handed, which is the same effect
      # arrived at twice — and it would move Qt without moving GTK or foot.
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
      # Was `theme = "Breeze_Snow"; size = 24;`. Both hand-written, and the
      # theme name was wrong: KDE renamed that cursor set to `Breeze_Light` in
      # Plasma 6 and ships no `Breeze_Snow`, so Plasma has been falling back to
      # the default pointer. Now from `stylix.cursor`, which niri and Hyprland
      # read too — the three of them used to disagree about the size as well.
      cursor = {
        theme = cursor.name;
        inherit (cursor) size;
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

  # `QT_STYLE_OVERRIDE`, `QT_QPA_PLATFORMTHEME`, `GDK_SCALE` and `GDK_DPI_SCALE`
  # used to be here as well, all four also set at the system level and the first
  # two under `lib.mkForce` in both places. Those are the third and fourth
  # transcriptions of a value nixpkgs' own `qt` module exports from `qt.style`
  # and `qt.platformTheme` — see ../modules/system/appearance.nix. One statement
  # of a fact, in the layer that owns it; this layer owns none of those four.
  home.sessionVariables = {
    TERMINAL = "foot";
  };
}
