{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

# Doom Emacs, in parallel with the vanilla emacs-config.
#
# The build is `nix-doom-emacs-unstraightened`: Doom's source, its module tree
# and every package it resolves are pinned in flake.lock, and the DOOMDIR it
# bundles is the combination built in flake.nix (`myConfig.doomDir`) — the
# GitHub doom-config repo plus the shared Hebrew-core modules from the
# emacs-config input. Nothing runs `doom sync`, and no writable config tree is
# produced.
#
# It is deliberately NOT `provideEmacs`: the vanilla Emacs daemon is still what
# $EDITOR, `emacsclient -c`, yazi and the focus session use. Doom gets its own
# `doom-emacs` binary and its own launcher, so the two cannot steal each
# other's server socket or init directory.

{
  programs.doom-emacs = {
    enable = true;
    provideEmacs = false;
    emacs = myConfig.emacs31;
    inherit (myConfig) doomDir;
    doomLocalDir = "${config.xdg.dataHome}/nix-doom";
  };

  # The second start-menu entry. No MimeType: file associations stay with the
  # vanilla Emacs entry, so "open this .org file" keeps going to the daemon.
  xdg.desktopEntries.doom-emacs = {
    name = "Doom Emacs";
    genericName = "Text Editor";
    comment = "Doom Emacs with Hebrew and RTL support";
    startupNotify = true;
    exec = "${config.programs.doom-emacs.finalDoomPackage}/bin/doom-emacs %F";
    icon = "${myConfig.emacs31}/share/icons/hicolor/scalable/apps/emacs.svg";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
    ];
  };
}
