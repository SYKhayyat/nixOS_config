# modules/home/yazi.nix
{ pkgs, ... }: {
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "mtime";
        sort_reverse = true;
      };
      opener = {
        # Custom "Open With" commands
        edit = [ { run = ''''${EDITOR:-block} "$@"''; block = true; desc = "Edit in Terminal"; } ];
        play = [ { run = ''vlc "$@"''; orphan = true; desc = "Open in VLC"; } ];
        gui_open = [ { run = ''dolphin "$(dirname "$1")"''; orphan = true; desc = "Reveal in Dolphin"; } ];
        doc = [ { run = ''libreoffice "$@"''; orphan = true; desc = "Open in LibreOffice"; } ];
        default = [ { run = ''xdg-open "$@"''; desc = "System Default"; } ];
      };
      open = {
        rules = [
          { name = "*.pdf"; use = [ "default" "gui_open" ]; }
          { name = "*.docx"; use = [ "doc" "gui_open" ]; }
          { mime = "video/*"; use = [ "play" "gui_open" ]; }
          { mime = "text/*"; use = [ "edit" "gui_open" ]; }
          { mime = "image/*"; use = [ "default" "gui_open" ]; }
        ];
      };
    };
    # Keybindings
    keymap = {
      manager.prepend_keymap = [
        # Shift+O triggers the interactive "Open With" menu
        { on = [ "O" ]; run = "open --interactive"; desc = "Open With..."; }
      ];
    };
  };
}
