# modules/home/toolkit.nix
#
# Every program you type the name of, in one place — and the one axis that is
# allowed to take them away.
#
# ── What was wrong ────────────────────────────────────────────────────────
#
# There was no rule about where a package goes, so the answer defaulted to
# `environment.systemPackages`. modules/system/cli-tools.nix and
# development.nix between them installed about sixty user applications
# machine-wide.
#
# That is not untidy, it is load-bearing. A specialisation *inherits* its
# parent: anything in the system closure is present in `study`, and there is no
# expression that removes it. modules/system/profile.nix already records the
# home-manager half of this lesson — `home-manager.users.<name>` is a submodule,
# so a second `imports` merges rather than replaces, which is how the old study
# mode ended up with the full desktop profile bolted underneath it. This is the
# same fault one layer down, and it survived the fix to the other one.
#
# The bill, all of it visible in the tree before this commit:
#
#   * **`lynx` is a browser and it was on $PATH in the "offline airgap, no
#     browsers" specialisation.** The Lamdan report caught `firefox` and fixed
#     it with a `mkForce false` in study-offline.nix. `lynx` was two words away
#     on the same line of the same file. A patch aimed at the package instead of
#     at the drawer leaves the drawer, and the next thing you put in it.
#
#   * `programs.firefox.enable` was stated in two module systems — the NixOS
#     option in cli-tools.nix and the home-manager option in home/shaul.nix —
#     plus a third statement in study-offline.nix that existed only to cancel
#     the first. One fact, three statements, two of them corrections.
#
#   * home/shaul.nix's study branch described itself as "a different list, not a
#     subset" and listed ytfzf, yt-dlp, mpv, pandoc and libreoffice. Four of
#     those five were already in systemPackages, so naming them changed nothing
#     — and leaving them out of the other branch removed nothing either. The one
#     entry the branch genuinely controlled, libreoffice, was written out in
#     both arms. A conditional in which one side is a no-op and the other is a
#     copy is not a decision, it is a shape.
#
#   * Two of those five need the network the specialisation had just switched
#     off. `ytfzf` and `yt-dlp` are YouTube clients, in the airgap.
#
#   * Thirteen packages were declared twice, in a system list and a home list:
#     fd, ripgrep, ripgrep-all, plocate, recoll, pandoc, fzf, jq, libsecret,
#     wl-clipboard, networkmanagerapplet, nil, rust-analyzer. Plus `bat`, `fzf`
#     and `git`, which home-manager's own `programs.*` modules install and which
#     were listed as packages beside them.
#
# ── The rule ──────────────────────────────────────────────────────────────
#
#   1. A package is declared in exactly ONE list.
#
#   2. modules/system/base-tools.nix holds only what has to work when
#      home-manager is broken, absent, or not yours: the tools you repair a bad
#      generation with, and what a system service or a machine-wide environment
#      variable needs. That set is small and it is argued in that file.
#
#   3. Everything a person types lives in home-manager, in the module that owns
#      it — the session stack in ./wayland-common.nix, Emacs's shell-outs in
#      ./emacs/default.nix, the shell in home/common.nix — and everything else
#      here, where `study` can reach it.
#
#   4. A script that calls a program by store path (`${pkgs.grim}/bin/grim`)
#      needs no list entry at all: it is in the closure already. It is listed
#      only if you also want to type its name.
#
# ── What study removes, and why exactly those ─────────────────────────────
#
# Browsers, anything whose job is to fetch over the network, and the creative
# and media suite. Nothing else.
#
# The airgap is two claims, not one. The firewall and the dead radios are the
# backstop — they mean nothing gets out. The feature is that the thing you would
# open out of habit is not there, and "out of habit" covers both the browser you
# would reach for and the raster editor you would disappear into for an hour.
# Neither claim is served by removing `ncdu`, so study keeps the search tools,
# the file managers, the editors, the document toolchain, the compilers and a
# local media player. It loses the things it exists to lose, and that list is
# now one attribute you can read.
{
  lib,
  pkgs,
  myConfig,
  osConfig,
  ...
}:

let
  # Set by modules/system/study-offline.nix inside the `study` specialisation.
  # See modules/system/profile.nix for why it is a flag and not a second import.
  inherit (osConfig.shaulos) study;

  # Present in every session, `study` included.
  #
  # Not here, and deliberately: `git`, `bat` and `fzf` come from their
  # `programs.*` modules in home/common.nix, which install the package as part
  # of configuring it; `yazi` likewise from ./yazi.nix and `foot` from
  # ./wayland-common.nix. Listing the package beside the module that already
  # installs it is the same duplicate one line further apart.
  always = with pkgs; [
    # ── Search ────────────────────────────────────────────────────────────
    # Yes, this is a lot of them, and that is on purpose — trying search tools
    # out is what a config like this is for. What it is not for is having them
    # in the base system closure where nothing can decide against them.
    fd
    ripgrep
    ripgrep-all
    fzy
    skim
    ugrep
    plocate # `locate` itself comes from the setgid wrapper services.locate makes
    # recoll and xapian are off with `extras`. Every `recoll' call site in the
    # Emacs config is in `extras/', and ./emacs/default.nix sets
    # EMACS_MODULE_GROUPS = "essentials" — so the only caller is gone. The
    # recoll.conf that comment used to point at is commented out in the same
    # file, and ../system/services.nix's four-hourly indexer with it; see that
    # file for the part nobody had noticed, which is that the index it built
    # was never the one seforim search read.
    #
    # Uncomment both with `extras`. They are a pair — xapian is recoll's
    # backend — and the ten other search tools above are why nothing else in
    # this list depends on them.
    # recoll
    # xapian
    fsearch
    kdePackages.kfind
    television
    docfd
    tre

    # ── File management ───────────────────────────────────────────────────
    nnn
    ranger
    mc
    pcmanfm-qt
    thunar
    fdupes
    ncdu
    peazip

    # ── Documents ─────────────────────────────────────────────────────────
    pandoc # also Org export and the Markdown preview — see ./emacs/default.nix
    # `poppler` was listed here too, and the pair did not merely duplicate — it
    # made the home profile impossible to build:
    #
    #   pkgs.buildEnv error: two given paths contain a conflicting subpath:
    #     .../poppler-utils-26.06.0/lib/libpoppler-cpp.so.3
    #     .../poppler-glib-26.06.0/lib/libpoppler-cpp.so.3
    #
    # `pkgs.poppler` is poppler-glib, and it ships **no binaries at all** — it
    # is the library, and a library in a *user profile* is a thing you cannot
    # type and nothing links against at runtime. `poppler-utils` is the half
    # that carries the thirteen commands (`pdftotext`, `pdfinfo`, `pdfimages`,
    # `pdftoppm`, …), which is what rule 3 at the top of this file is about, and
    # both halves ship the same `libpoppler-cpp.so.3`.
    #
    # So this line was not costing a duplicate. It was costing the thirteen
    # tools, plus every other package in this list, because `home-manager-path`
    # is one buildEnv and one collision fails the lot. That is the difference
    # between the eval gate and the build gate, in one line: this evaluates
    # perfectly and has never once produced a profile.
    poppler-utils
    antiword
    catdoc
    libreoffice-qt-fresh

    # ── Editors, other than the one this whole repo is about ──────────────
    neovim
    helix

    # ── Terminal odds and ends ────────────────────────────────────────────
    jq
    navi
    # ./scripts.nix and ./lock.nix drive all three by store path, so by rule 4
    # none of them needs to be here. They are here because `brightnessctl set
    # 50%` is a thing you type — and listing one of the three and not the other
    # two, which is what the old home/common.nix line amounted to, is not a
    # decision anyone would defend out loud.
    pamixer
    brightnessctl
    playerctl
    libsecret # `secret-tool`, against the gnome-keyring in wayland.nix
    wayland-utils # `wayland-info`, for when the session is lying to you
    nushell
    mpv # one local media player. The rest of the media suite is below.

    # ── Development ───────────────────────────────────────────────────────
    # Offline-safe, so study keeps them. That is now a choice made in one place
    # rather than a consequence of which file they happened to be listed in.
    # The language servers are not here: they exist because an editor calls
    # them, so ./emacs/default.nix owns them.
    gcc
    gnumake
    cmake
    pkg-config
    jdk
    maven
    gradle
    go
    rustc
    cargo
    clippy
    (python3.withPackages (
      ps: with ps; [
        python-docx
        textual
        pip
        virtualenv
      ]
    ))
  ];

  # Gone in study.
  offInStudy = with pkgs; [
    # ── Browsers ──────────────────────────────────────────────────────────
    # The whole list, in one place, so "no browsers" is a claim you can check.
    # `firefox` is the fourth and it is below, because it comes with a profile.
    lynx
    qutebrowser
    tor-browser

    # ── Things whose job is to fetch ──────────────────────────────────────
    aria2
    persepolis
    ytfzf
    yt-dlp
    opencode
    # `rclone config` — the one rclone command you run by hand. The
    # shaulos-data-bootstrap unit in modules/system/data.nix names rclone in its
    # own PATH=, so the service does not depend on this entry, and study turns
    # that unit off anyway.
    rclone

    # ── The creative and media suite ──────────────────────────────────────
    kdePackages.calligra
    scribus
    texmacs
    sile
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.resynthesizer
    krita
    krita-plugin-gmic

    # ── The two that are not downloads ────────────────────────────────────
    #
    # Everything else in this section is in cache.nixos.org, so it costs a
    # download and nothing else. These two are not, and "not cached" means
    # *your machine compiles them*, from source, every time the nixpkgs pin
    # moves. Measured against the pinned nixpkgs (445d861c) by asking
    # cache.nixos.org for each derivation's .narinfo:
    #
    #   graphite                    404 — no substitute, Rust, builds locally
    #   inkscape / -with-extensions 404 — no substitute, C++, builds locally
    #
    # `graphite` was caught doing exactly this: 19 minutes into a closure
    # build, still compiling, with nothing else left to do. It is an
    # `0-unstable-2026-05-02` snapshot of a browser-based vector editor, which
    # is also why it has no substitute — unstable snapshots are not built by
    # Hydra.
    #
    # `inkscape-with-extensions` is the same story and the plain `inkscape`
    # attribute is no better; both were checked, both 404. So this is not a
    # case where dropping the wrapper buys anything.
    #
    # Commented rather than deleted, per the rule this repo already follows
    # for the Emacs `extras` machinery: uncomment either line and it comes
    # back, at the price named above.
    #
    #   inkscape                    krita, pinta, photoflare and gimp all
    #                               overlap it for raster work; for vector,
    #                               it is the one real loss here.
    #   graphite                    an alpha-stage editor that duplicates
    #                               inkscape's job less completely.
    #
    # NOT applied to texlive.combined.scheme-full in ../emacs/default.nix,
    # which is the largest single thing in the closure and also never
    # substituted. That one is load-bearing: essentials/07-latex.org is a
    # whole AUCTeX module and essentials/05-org.org sets `org-latex-compiler'
    # to lualatex with an `org-latex-pdf-process' that shells out to
    # `latexmk'. Both are LOADED under EMACS_MODULE_GROUPS = "essentials", so
    # removing TeX would leave live code calling a binary that is not there —
    # the same defect as the seforim one, pointing the other way.
    # inkscape-with-extensions
    pinta
    photoflare
    ansel
    digikam
    rawtherapee
    darktable
    sly
    rapidraw
    art
    aaphoto
    # See "The two that are not downloads" above — uncached, compiles locally.
    # graphite
    graphicsmagick_q16
    upscayl
    vlc
    audacity
    lmms
  ];
in
{
  home.packages = always ++ lib.optionals (!study) offInStudy;

  # The fourth browser. It lives here rather than in home/shaul.nix so that
  # every "which browsers exist" decision is in one file, and it is the only
  # statement of it anywhere: the NixOS-level `programs.firefox.enable = true`
  # in cli-tools.nix is gone, and so is the `mkForce false` in study-offline.nix
  # that existed to undo it.
  programs.firefox = {
    enable = !study;
    configPath = lib.mkForce ".mozilla/firefox";
    profiles.${myConfig.username} = {
      settings = {
        # The one surface where the size knob cannot be a point size. Firefox
        # sizes neither its chrome nor a web page in points: the CSS default is
        # 16px and every site that styles its own text overrides
        # `font.size.variable.*` anyway, so setting those prefs would shrink
        # roughly the sites that needed it least. `devPixelsPerPx` is the only
        # one that moves all of it — chrome, content, and the sites with
        # opinions.
        #
        # The ratio is against 10, which is stylix's default `desktop` size and
        # therefore the density Firefox's chrome and that 16px are drawn for. So
        # this asks for the same relative size as the rest of the desktop rather
        # than a zoom level someone liked: uiSize 8 gives 0.8, and 16px body
        # text lands at 12.8. It was the literal "1.0", which is why the browser
        # stayed at full size while everything around it was at three quarters.
        "layout.css.devPixelsPerPx" = builtins.toJSON (osConfig.stylix.fonts.sizes.applications / 10.0);
        "browser.uidensity" = 1;
      };
    };
  };

  # Named beside the profile it themes, for the same reason.
  stylix.targets.firefox.profileNames = [ myConfig.username ];
}
