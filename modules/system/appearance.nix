# modules/system/appearance.nix
#
# How this machine looks. One file, and — for the first time — one definition.
#
# ── What was wrong ────────────────────────────────────────────────────────
#
# README.md said it already: "There is one place that decides how this machine
# looks: `stylix` in modules/system/core.nix. Everything else derives from it."
# That was true of the colours and the fonts, because ../home/palette.nix was
# built to make it true. It was false of everything else, and the Qt half was
# false in the most expensive way available: the statement that *would* have
# derived it was switched off, and its output was then written out by hand,
# three times, in two module systems, under `lib.mkForce`.
#
# Stylix's NixOS Qt target (`modules/qt/nixos.nix` in stylix) is nine lines:
#
#     qt.platformTheme = if plasma6.enable && !(gnome.enable || lxqt.enable)
#                        then "kde" else …;
#     qt.style         = { kde = "breeze"; gnome = …; qtct = "kvantum"; }
#                        .${config.qt.platformTheme};
#     qt.enable        = true;
#
# On this machine plasma6 is on and gnome/lxqt are not, so that computes
# `platformTheme = "kde"` and `style = "breeze"`. Here is what the repo had
# instead:
#
#   modules/system/desktop.nix   stylix.targets.qt.enable = false;   ← the target, off
#   modules/system/core.nix      qt.enable       = lib.mkForce true;
#                                qt.platformTheme = "kde";           ← its output, by hand
#                                qt.style         = "breeze";        ← its output, by hand
#   modules/system/core.nix      environment.sessionVariables.QT_STYLE_OVERRIDE
#                                  = lib.mkForce "breeze";           ← a second transcription
#                                environment.sessionVariables.QT_QPA_PLATFORMTHEME
#                                  = lib.mkForce "kde";
#   home/shaul.nix               home.sessionVariables.QT_STYLE_OVERRIDE
#                                  = lib.mkForce "breeze";           ← a third
#                                home.sessionVariables.QT_QPA_PLATFORMTHEME
#                                  = lib.mkForce "kde";
#
# Three `mkForce`s, and not one of them overrides anything:
#
#   * `qt.enable` — `services.desktopManager.plasma6.enable` already sets it to
#     `true` twenty lines away, and two definitions of `true` never conflicted.
#   * the two variables — nixpkgs' own `qt` module (nixos/modules/config/qt.nix)
#     exports them itself, from `qt.style` and `qt.platformTheme`, into
#     `environment.variables`. A `mkForce` in `environment.sessionVariables` is a
#     different option; it cannot override that one, it can only outrank it in
#     the session. Which is the actual damage: the hand-written pair *wins*, so
#     changing `qt.style` can never change what a Qt app sees.
#
# That is the palette lesson exactly (see ../home/palette.nix): a value copied by
# hand out of the thing that computes it, in a spelling nobody checks, kept in
# force by an operator that hides the copy. It cost four lines of config to say
# what zero lines would have said correctly.
#
# ── The rule ──────────────────────────────────────────────────────────────
#
# A fact about how this machine looks is stated **once**, here, and every other
# module derives it:
#
#   1. Colour and font — `stylix.base16Scheme` / `stylix.fonts`. Stylix's own
#      targets take it from there; ../home/palette.nix re-renders it into the
#      syntaxes hand-written config files need.
#   2. Qt — nothing states it. Stylix's NixOS target computes it from the desktop
#      that is enabled, and nixpkgs' `qt` module exports the variables. Turning
#      the target back on deleted eleven lines and one class of bug.
#   3. Cursor — `stylix.cursor`, which is the option all four consumers were
#      independently guessing at. See below.
#   4. Fonts on disk — `fonts.packages` here, minus anything `stylix.fonts`
#      already installs, because stylix's font-packages target puts its four
#      families in that same list.
#
# The two stylix targets that stay OFF are decisions, and both are argued where
# they are made (home/shaul.nix): `targets.kde` because plasma-manager owns
# Plasma's look, and the *home-manager* `targets.qt` because — unlike the NixOS
# one — it has no desktop detection at all, defaults `platform = "qtct"`, and
# would install kvantum and a qt5ct settings file over the Breeze this machine
# actually runs.
{ pkgs, ... }:

let
  # ── The one number ────────────────────────────────────────────────────────
  #
  # TO MAKE ALL TEXT SMALLER OR BIGGER: change this, then `just switch`.
  #
  # It is a size in points. `forceFontDPI` (home/shaul.nix) pins this display at
  # 96 DPI and the scale factors at the bottom of this file are all 1, so a
  # point is exactly 4/3 of a pixel and nothing multiplies it a second time:
  # 8pt is 10.67px, and that is the whole conversion.
  #
  # 8 is about the floor. At 7 (9.3px) Noto Sans starts dropping stems to
  # hinting on this panel. Go up if anything strains; the surfaces below all
  # move together either way.
  #
  #   uiSize      → Plasma menus and window titles, every GTK app, dunst,
  #                 waybar, the toolbar font a point under it, and Emacs's
  #                 default face (as `uiSize * 10`, Emacs counting in tenths)
  #   uiSize + 1  → both terminals — foot and konsole — and the fontconfig
  #                 default further down
  #   uiSize / 10 → Firefox's devPixelsPerPx (../home/toolkit.nix)
  #
  # ── Why it was too big, which was never a DPI problem ─────────────────────
  #
  # The panel is 1366x768 over 344x193 mm. That is 101 real DPI against the 96
  # this machine forces, so a point was already rendering *smaller* than its
  # physical size. Nothing was mis-scaled, and no amount of looking at scale
  # factors was going to find it.
  #
  # The problem was a pixel budget. 768 rows is not many, and three of the four
  # surfaces you read all day derived their size from nothing at all — they sat
  # at their vendors' defaults, every one of which is 12pt or 16px against the
  # 9pt the desktop ran:
  #
  #   Emacs     got fontconfig's own built-in default of 12.0 — a third larger
  #             than everything around it — but NOT for the reason first
  #             written here, and the correction is the interesting part.
  #             `01-ui.el` in the emacs-config repo does state a size,
  #             `:height 90`. It is wrapped in `(when (display-graphic-p) …)`
  #             evaluated at load time, and in `emacs --fg-daemon` there is no
  #             frame yet, so the block never runs and every `emacsclient -c`
  #             frame — i.e. every frame, since EDITOR is emacsclient — fell
  #             through to fontconfig. A grep for a font size finds that file;
  #             only running the thing shows the statement never executes.
  #             See ../home/emacs/default.nix.
  #   Firefox   `layout.css.devPixelsPerPx = "1.0"`, a literal, while the
  #             desktop around it ran at three quarters of stylix's default.
  #   waybar    `font-size: 12px`, under a comment arguing it was a deliberate
  #             exception for Nerd Font glyphs. It was not an exception: 9pt
  #             *is* 12px at 96 DPI, so that literal was the derived value all
  #             along, written in the other unit and pinned by hand.
  #
  # Which is this repo's own rule broken three times in the one dimension no
  # pass had looked at. "Everything is too big" was exact, and the fix is the
  # rule: state it once, here, and derive it everywhere.
  #
  # A fourth turned up when the first three were already fixed, and it is the
  # worst of them: konsole. Not a hardcoded size — no statement of any kind.
  # `grep -rni konsole` over the tree returned nothing, `~/.local/share/konsole`
  # was empty, and it is the terminal the Plasma session actually opens. Three
  # bad literals are findable; a program nobody wrote down is not. It is
  # declared in ../home/konsole.nix now, and the lesson is in its header.
  uiSize = 8;
in

{
  # `stylix.targets.gtk.enable = true` used to be stated here. Every stylix
  # target auto-enables, so that line said what was already true — and the NixOS
  # half of that target is two lines, `programs.dconf.enable = true`, which is
  # what home-manager's GTK settings need to take effect. Stating a default is a
  # third way of saying nothing, and the file it was in had two others.
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    image = ../../wallpaper.jpg;
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };

      # These four were `stylix.fonts.sizes.applications`, `.desktop` and
      # `.terminal` in home/shaul.nix, which is a layer that does not own them:
      # stylix's own home-manager integration copies all four down from this
      # config with `mkDefault` (homeManagerIntegration.followSystem, on by
      # default), so the home-side statements were shadowing the value they were
      # supposed to be receiving. Deleting them there changes nothing except
      # which file you edit — and now there is one.
      sizes = {
        applications = uiSize;
        desktop = uiSize;
        popups = uiSize;
        # Monospace reads smaller than sans at equal points, so the terminal
        # gets the point back. This is the only size expressed as a difference,
        # and it is the relation the config already had (9 and 10).
        terminal = uiSize + 1;
      };
    };

    # ── The cursor, which had three sizes and a name that no longer exists ──
    #
    # `stylix.cursor` was never set, so the four surfaces that need a cursor
    # each answered for themselves and no two agreed:
    #
    #   core.nix            XCURSOR_SIZE = "24"
    #   home/shaul.nix      plasma-manager: theme "Breeze_Snow", size 24
    #   niri/config.kdl     cursor { xcursor-size 12 }
    #   hyprland.conf       (nothing at all)
    #
    # So the pointer was 12 px in one session and 24 in the others, and under
    # Hyprland it was whatever the default happened to be. And the one statement
    # that named a *theme* named one that Plasma 6 does not ship: KDE's breeze
    # repo installs `share/icons/breeze_cursors` and `share/icons/Breeze_Light`
    # — `Breeze_Snow` was the Plasma 5 spelling and is gone on the 6.5 branch
    # nixpkgs 26.05 builds. Plasma silently falls back when a cursor theme is
    # missing, which is why nobody found out.
    #
    # Setting it here does four things at once: stylix's home-manager side turns
    # it into `home.pointerCursor` (which writes ~/.local/share/icons and sets
    # the GTK and X11 cursor), and ../home/palette.nix hands the same name and
    # size to plasma-manager, to niri's KDL and to hyprland.conf. The literal
    # `XCURSOR_SIZE = "24"` that used to sit in the system environment is gone:
    # it was a fifth statement of the same fact, read by only some of the four.
    # (Hyprland's config does still export XCURSOR_THEME/XCURSOR_SIZE, because
    # that is how a Hyprland session tells its clients — but it interpolates
    # them from here rather than repeating a number.)
    cursor = {
      package = pkgs.kdePackages.breeze;
      name = "Breeze_Light";
      size = 24;
    };
  };

  # ── Fonts on disk ────────────────────────────────────────────────────────
  # Stylix's font-packages target sets `fonts.packages` to the four families
  # named above, so this list is only what nothing else installs. It used to
  # repeat three of them — `noto-fonts`, `noto-fonts-color-emoji` and
  # `nerd-fonts.jetbrains-mono` — which is the rule from base-tools.nix ("a
  # package is declared in exactly one list") broken in the one list that pass
  # did not look at. Repeating them was harmless until the day you change
  # `stylix.fonts.monospace`, at which point this list quietly keeps installing
  # the family you stopped using. `jetbrains-mono` was here too, beside the Nerd
  # Font patch of the same typeface, which is the same duplicate with a
  # different family name.
  fonts.fontDir.enable = true;

  fonts.packages = with pkgs; [
    culmus # Hebrew
    noto-fonts-cjk-sans
    liberation_ttf
    dejavu_fonts
    fira-code
    fira-code-symbols
    source-code-pro
    source-serif
    source-sans
    libertinus
    emacs-all-the-icons-fonts
    nerd-fonts.symbols-only # glyphs for waybar/p10k without a second monospace
  ];

  # ── The size for everything that never asked ─────────────────────────────
  #
  # An app that names no size gets fontconfig's built-in default, which is
  # 12.0pt and is not configurable through any NixOS option — `fonts.fontconfig`
  # has families (stylix sets those) and hinting, and no size at all. So every
  # unconfigured GUI ran a third larger than the desktop it sat in, and Emacs —
  # which sets no font in any of its 30 files, and is the app this machine is
  # mostly for — was the one you felt.
  #
  # `mode="append"` is what makes this a *default* rather than an override. It
  # adds our size after any the app already asked for, and fontconfig reads
  # index 0, so a request that named a size keeps it and a request that named
  # none finds ours before FcDefaultSubstitute can supply 12.0. Checked both
  # ways with `FONTCONFIG_FILE=… fc-match -v`: an unsized "Monospace" resolves
  # to this number, and "Monospace-14" still resolves to 14.
  #
  # It is the terminal size rather than uiSize because the things that reach
  # here are text editors and terminals, not chrome.
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <edit name="size" mode="append"><double>${toString (uiSize + 1)}</double></edit>
      </match>
    </fontconfig>
  '';

  # Where non-fontconfig consumers look. TeX and a couple of Emacs paths read
  # this; it is a path, not a preference, but it belongs beside the font list
  # rather than in the middle of the display-manager module where it was.
  environment.variables.OSFONTDIR = "/run/current-system/sw/share/X11/fonts";

  # ── Scale ────────────────────────────────────────────────────────────────
  # Everything here says "1": no fractional scaling, on any toolkit. That is a
  # decision about a 1366x768 panel and it is the only appearance fact that is
  # not derived from stylix, because stylix has no opinion about scale.
  #
  # Leave them at 1, and leave `forceFontDPI` at 96, when you change `uiSize`.
  # Text size has exactly one knob on this machine and it is the point size at
  # the top of this file; a scale factor here would multiply it a second time,
  # and then "how big is the text" would be a question with two answers again.
  #
  # QT_STYLE_OVERRIDE and QT_QPA_PLATFORMTHEME used to be in this attrset. They
  # are exported by nixpkgs' `qt` module from `qt.style` / `qt.platformTheme`,
  # which stylix now computes — see the header.
  environment.sessionVariables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    QT_SCALE_FACTOR = "1";
    GDK_SCALE = "1";
    GDK_DPI_SCALE = "1";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=1";
  };
}
