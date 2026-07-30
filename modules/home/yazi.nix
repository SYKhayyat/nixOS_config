# modules/home/yazi.nix
# Yazi is configured through TOML (yazi.toml / keymap.toml), driven here by the
# home-manager `programs.yazi` module. The previous version used a Lua API
# (`Manager.*`, `Opener:rule`) that yazi does not expose for configuration —
# that surface only exists inside plugins' init.lua. This is the supported one.
{ pkgs, config, lib, ... }:

{
  programs.yazi = {
    enable = true;

    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "mtime";
        sort_reverse = true;
      };

      opener = {
        edit = [
          { run = ''emacsclient -c -a "" "$@"''; block = true; desc = "Edit in Emacs"; }
        ];
        play = [
          { run = ''vlc "$@"''; orphan = true; desc = "Open in VLC"; }
        ];
        reveal = [
          { run = ''dolphin "$(dirname "$1")"''; orphan = true; desc = "Reveal in Dolphin"; }
        ];
        doc = [
          { run = ''libreoffice "$@"''; orphan = true; desc = "Open in LibreOffice"; }
        ];
        open = [
          { run = ''xdg-open "$@"''; desc = "System Default"; }
        ];
      };

      open.rules = [
        { name = "*.pdf"; use = "open"; }
        { name = "*.docx"; use = "doc"; }
        { mime = "video/*"; use = "play"; }
        { mime = "text/*"; use = "edit"; }
        { mime = "image/*"; use = "open"; }
      ];
    };

    keymap = {
      mgr.prepend_keymap = [
        { on = "O"; run = "open --interactive"; desc = "Open With..."; }
      ];
    };
  };
}
