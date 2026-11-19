# modules/home/toolkit.nix
#
# Every program you type the name of, in one place — and the one axis allowed
# to take them away.
#
# Rule: a package is declared in exactly one list. `base-tools.nix` holds only
# what must work when home-manager is broken; everything a person types lives
# here, in the module that owns it, or comes from a `programs.*` module that
# installs it as part of configuring it (git, bat, fzf, yazi, foot).
#
# `offInStudy` is study's subtraction: browsers, anything whose job is to fetch
# over the network, and the creative and media suite. Study keeps the search
# tools, the file managers, the editors, the document toolchain, the compilers
# and a local media player.
{
  lib,
  pkgs,
  myConfig,
  osConfig,
  ...
}:
let
  # Vocalinux's overlay is the set of blue lines that float over every window
  # with a "vocalinux dictation" hover label. It is a setting in the app's own
  # JSON config, so the file is sourced from the repository with show_overlay
  # turned off, rather than edited in place (where the next switch would put it
  # back). One checked-in file is the one statement of the app's settings.
  vocalinuxConfig = ../../assets/vocalinux-config.json;

  inherit (osConfig.shaulos) study;

  always = with pkgs; [
    # ── Search ────────────────────────────────────────────────────────────
    fd
    ripgrep
    ripgrep-all
    plocate # `locate` itself comes from the setgid wrapper services.locate makes

    # ── File management ───────────────────────────────────────────────────
    fdupes
    ncdu
    peazip
    p7zip

    # ── Documents ─────────────────────────────────────────────────────────
    pandoc
    poppler-utils
    antiword
    catdoc
    libreoffice-qt-fresh

    # ── Editors other than the one this repo is about ─────────────────────
    neovim
    helix

    # ── Terminal odds and ends ────────────────────────────────────────────
    jq
    pamixer
    brightnessctl
    playerctl

    # ── Dictation ─────────────────────────────────────────────────────────
    # Transcribing speech is not fetching. Study takes the first-run model
    # download away by having no network; warm the model before switching in.
    vocalinux

    libsecret
    wayland-utils
    mpv # the one local media player

    # ── Development ───────────────────────────────────────────────────────
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

    # ── JavaScript runtimes ───────────────────────────────────────────────
    nodejs_22
    bun

    # ── Lisp ──────────────────────────────────────────────────────────────
    # sbcl has no package manager. Quicklisp is its library installer, and
    # modules/home/lisp.nix installs it from the pinned bootstrap and wires up
    # the init file that loads it — the bootstrap is not a command, so it is
    # not in this list.
    sbcl

    # Plain interpreter; per-project dependencies belong in direnv/venvs.
    python3
  ];

  offInStudy = with pkgs; [
    # ── Browsers ──────────────────────────────────────────────────────────
    # `firefox` is the fourth and lives below with its profile.
    google-chrome

    # ── Things whose job is to fetch ──────────────────────────────────────
    aria2
    persepolis
    ytfzf
    yt-dlp

    # Coding agents are network-bound by definition.
    llm-agents.opencode2
    # opencode v1, beside v2, for plugins that only run on the v1 API. Its own
    # XDG_DATA_HOME keeps v1's database out of v2's — the two schemas diverged.
    (llm-agents.opencode.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        sed -i '2i export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode-v1"' $out/bin/opencode
      '';
    }))
    llm-agents.freebuff
    llm-agents.kilocode-cli
    llm-agents.cline
    clixad
    neon-cli
    ob1
    free-pi-cli
    omnirush
    omnirush-gui
    deepai-code
    otzaria
    gh
    rclone

    # ── The creative and media suite ──────────────────────────────────────
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.resynthesizer
    darktable
    digikam
    geeqie
    sly
    rapidraw
    art
    graphicsmagick_q16
    upscayl
    audacity
    lmms
  ];
in
{
  home.packages = always ++ lib.optionals (!study) offInStudy;

  xdg.configFile."vocalinux/config.json".source = vocalinuxConfig;

  # The fourth browser. It lives here so every "which browsers exist"
  # decision is in one file.
  programs.firefox = {
    enable = !study;
    configPath = lib.mkForce ".mozilla/firefox";
    profiles.${myConfig.username} = {
      settings = {
        # Firefox sizes neither its chrome nor a web page in points. The
        # ratio is against 10, stylix's default desktop size, so this asks for
        # the same relative size as the rest of the desktop.
        "layout.css.devPixelsPerPx" = builtins.toJSON (osConfig.stylix.fonts.sizes.applications / 10.0);
        "browser.uidensity" = 1;

        # Firefox 110+ dropdown popups (Google account menu, search-bar
        # suggestions) close as soon as the pointer leaves the button. Mozilla
        # bug 1819206: Firefox misreads the pointer-leave event that sway sends
        # and tears the popup down. `ignore-bogus-leave-notify=1` suppresses that
        # event, which is enough on a compositor (sway is not a bare WM).
        #
        # `widget.gtk.grab-pointer=1` also fixed the dropdowns, but it grabs the
        # pointer after the popup is already mapped, which makes gdk log "you
        # may find oddities ahead" and made tab-close buttons flicker instead
        # of closing. Left at Firefox's default (2) — do not turn it on again.
        "widget.gtk.ignore-bogus-leave-notify" = 1;

        # The tab hover-preview is a separate popup (not a GTK menu). On sway it
        # appears over the tab on hover and then takes the click meant for the
        # tab, so clicking a tab previews it but never switches to it. Disabling
        # the preview removes the popup and the click goes to the tab.
        "browser.tabs.hoverPreview.enabled" = false;
      };
    };
  };

  stylix.targets.firefox.profileNames = [ myConfig.username ];
}
