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
    recoll # the seforim index; recoll.conf is written by ./emacs/default.nix
    xapian # recoll's backend, and its own CLI
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
    inkscape-with-extensions
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
    graphite
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
        "layout.css.devPixelsPerPx" = "1.0";
        "browser.uidensity" = 1;
      };
    };
  };

  # Named beside the profile it themes, for the same reason.
  stylix.targets.firefox.profileNames = [ myConfig.username ];
}
