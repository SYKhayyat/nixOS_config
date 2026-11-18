# modules/home/yazi.nix
# Yazi is configured through TOML (yazi.toml / keymap.toml), driven here by the
# home-manager `programs.yazi` module. The previous version used a Lua API
# (`Manager.*`, `Opener:rule`) that yazi does not expose for configuration —
# that surface only exists inside plugins' init.lua. This is the supported one.
# `myConfig` is here for `emacsFrame`, so the Emacs opener below cannot drift
# away from $EDITOR or from the menu entry. See ../../flake.nix.
{
  myConfig,
  ...
}:

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
            # `myConfig.emacsFrame' plus the file yazi is opening — the same
            # command as $EDITOR and as the menu entry, so this cannot drift
            # from either of them.
            #
            # `launch.sh` starts the notes daemon if it is not running and
            # passes the file list through, so yazi needs no emacsclient
            # flags of its own. A plain `"' string, and the `$' of `"$@"' is
            # written `\$' — a bare `$' not followed by `{' is a syntax error
            # in one. It cannot go back to `''…''`, because a leading `${' is
            # the escape for a literal `${' there and would interpolate
            # nothing.
            run = "${myConfig.emacsFrame} \"\$@\"";
            block = true;
            desc = "Edit in Emacs";
          }
        ];
        # mpv, the only media player installed. It is in `always`, so the
        # video opener also works in the study airgap.
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
