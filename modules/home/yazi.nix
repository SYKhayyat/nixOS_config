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
            # `--no-wait` is what makes `block = true` below survivable.
            # Without it emacsclient waits for a completion reply that Emacs
            # 30.2's server never sends on this machine — the frame opens and
            # the client blocks in recvfrom() forever — so yazi would sit on
            # a subprocess that never returns and the file manager would look
            # frozen. Same reason as EDITOR/VISUAL in ../emacs/default.nix.
            #
            # It used to end in `-a ""' as well, with the same effect as
            # everywhere else it appeared: a cold start forked
            # `emacs --fg-daemon' into yazi's subprocess and printed Emacs's
            # whole startup into a file manager nobody can see stderr of.
            # A plain `"' string, and the `$' of `"$@"' is written `\$' —
            # a bare `$' not followed by `{' is a syntax error in one. It
            # cannot go back to `''…''`, because a leading `${' is the escape
            # for a literal `${' there and would interpolate nothing.
            run = "${myConfig.emacsFrame} \"\$@\"";
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
