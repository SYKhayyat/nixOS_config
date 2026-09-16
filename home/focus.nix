# home/focus.nix
#
# The user environment inside the `focus` closure: Emacs, a shell, and the
# handful of programs Emacs shells out to.
#
# This is a *different* profile from ./shaul.nix, not a subset of it, and that
# is only possible because ../modules/system/focus.nix is built with
# `inheritParentConfig = false`. ../modules/system/profile.nix explains at
# length why the `study` mode could not do this — `home-manager.users.<name>`
# is a submodule, so a second `imports` merges with the parent's instead of
# replacing it, and study ended up with the entire desktop profile underneath
# the one it declared. `shaulos.study` is a boolean precisely to avoid that.
#
# No parent, no merge, no flag. Everything below is here because it was named
# here.
{ pkgs, ... }:

{
  imports = [
    ./common.nix # zsh, git, aliases — and, since the split, nothing else
    ../modules/home/p10k.nix # the prompt common.nix sources
    ../modules/home/emacs # the daemon, the module groups, Emacs's shell-outs
    ../modules/home/yazi.nix
  ];

  # ── What is deliberately not imported ────────────────────────────────────
  #
  # ../modules/home/toolkit.nix    sixty applications, and it reads
  #                                `osConfig.shaulos.study` — a flag that
  #                                belongs to the other closure's axis.
  # ../modules/home/wayland-common.nix   the session stack: waybar, mako,
  #                                fuzzel, awww, foot, dolphin, kate, okular,
  #                                udiskie, the screenshot chain — and
  #                                ../modules/home/lock.nix's idle daemon.
  # ../modules/home/scripts.nix    every one of them drives `niri msg` or
  #                                `hyprctl`. It used to be imported by
  #                                ./common.nix, which is why that import
  #                                moved; see the note there.
  # ../modules/home/niri, hyprland, keys.nix, palette.nix
  #                                configs for compositors this closure has
  #                                no binary for.
  # programs.plasma                there is no Plasma here to configure.

  # Emacs is the only graphical client, so it is the only thing that needs to
  # find a font. The system half — the families, and `culmus` for Hebrew — is
  # ../modules/system/appearance.nix, which ../modules/system/focus.nix
  # imports; this is the per-user cache and the profile's font directory,
  # which ../modules/home/wayland-common.nix sets for the other profile.
  fonts.fontconfig.enable = true;

  # Off for the same reason ./shaul.nix turns it off, arrived at from the
  # other end. There it would install Kvantum and a qt5ct settings file over
  # the Breeze that Plasma actually renders. Here there is no Plasma and no Qt
  # application at all, so the target would install a theme engine for nobody.
  stylix.targets.qt.enable = false;
  stylix.targets.kde.enable = false;

  # ── The programs ─────────────────────────────────────────────────────────
  #
  # ../modules/home/toolkit.nix's rule still holds: a package is declared in
  # exactly one list, and `git`, `bat` and `fzf` are not here because
  # ./common.nix's `programs.*` modules install them as part of configuring
  # them — likewise `yazi` from ../modules/home/yazi.nix, and Emacs itself
  # plus texlive, typst, sqlite, graphviz, imagemagick and the language
  # servers from ../modules/home/emacs. (`hdate` was in that list until it
  # went off with `extras`; it had exactly one caller and it was Hebrew.)
  #
  # What is left is text search and the document toolchain, because that is
  # what this mode is for.
  #
  # That sentence used to read "the search stack, because that is what this
  # mode is for", and it named the *seforim* index. It was the single least
  # true comment in this repo: ../modules/home/emacs sets
  # EMACS_MODULE_GROUPS = "essentials", so this closure booted `cage` with one
  # Emacs frame that could not run a single `seforim-' command, over a profile
  # provisioned with recoll and xapian to serve it.
  #
  # Both are commented out below, on the rule that repo now applies
  # everywhere: machinery for code that does not load gets switched off, not
  # annotated. The mode is not diminished by it — `focus` is Emacs with
  # nothing else running, and grep over a text library is `rg` and `rga`,
  # which are still here.
  home.packages = with pkgs; [
    fd
    ripgrep
    ripgrep-all
    tre

    # Off with `extras`, and see ../modules/system/services.nix for the part
    # that surprised: the four-hourly index this pair fed was never the index
    # seforim search read. Uncomment both together with `extras`.
    # recoll
    # xapian

    # Stays. `poppler-utils` is not a seforim package — essentials/11-pdf.org
    # probes `pdfinfo` to decide whether pdf-tools is usable, and Org export
    # goes through `pdftotext`. It was listed beside recoll, which is the only
    # reason it looks like it belongs to that group.
    poppler-utils

    pandoc
    jq
    ncdu
  ];
}
