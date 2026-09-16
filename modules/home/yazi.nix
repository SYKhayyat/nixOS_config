# modules/home/yazi.nix
# Yazi is configured through TOML (yazi.toml / keymap.toml), driven here by the
# home-manager `programs.yazi` module. The previous version used a Lua API
# (`Manager.*`, `Opener:rule`) that yazi does not expose for configuration —
# that surface only exists inside plugins' init.lua. This is the supported one.
_:

{
  programs.yazi = {
    enable = true;

    # home-manager 26.05 changed this default from `yy` to `y`, and warns on
    # every evaluation until the profile says which one it wants — the profile's
    # `home.stateVersion` is 25.11, so it was getting the legacy value plus the
    # warning. Stated explicitly, which keeps `yy` (the wrapper that cds the
    # shell to yazi's last directory) and takes the warning off every rebuild.
    shellWrapperName = "yy";

    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "mtime";
        sort_reverse = true;
      };

      opener = {
        edit = [
          {
            run = ''emacsclient -c -a "" "$@"'';
            block = true;
            desc = "Edit in Emacs";
          }
        ];
        # mpv, not vlc. Both are installed, but vlc is in ../home/toolkit.nix's
        # `offInStudy` list and mpv is in `always` — it is the "one local media
        # player" study is documented to keep. Naming vlc here meant the file
        # manager's video opener was the one binding in this config that broke
        # precisely when you booted the specialisation, silently: yazi shells
        # out, gets "command not found", and shows you nothing.
        #
        # Every other opener below already names something in `always`
        # (libreoffice, dolphin, emacsclient, xdg-open). This was the only one
        # that reached across the study line.
        play = [
          {
            run = ''mpv "$@"'';
            orphan = true;
            desc = "Open in mpv";
          }
        ];
        reveal = [
          {
            run = ''dolphin "$(dirname "$1")"'';
            orphan = true;
            desc = "Reveal in Dolphin";
          }
        ];
        doc = [
          {
            run = ''libreoffice "$@"'';
            orphan = true;
            desc = "Open in LibreOffice";
          }
        ];
        open = [
          {
            run = ''xdg-open "$@"'';
            desc = "System Default";
          }
        ];
      };

      open.rules = [
        {
          name = "*.pdf";
          use = "open";
        }
        {
          name = "*.docx";
          use = "doc";
        }
        {
          mime = "video/*";
          use = "play";
        }
        {
          mime = "text/*";
          use = "edit";
        }
        {
          mime = "image/*";
          use = "open";
        }
      ];
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "O";
          run = "open --interactive";
          desc = "Open With...";
        }
      ];
    };
  };
}
