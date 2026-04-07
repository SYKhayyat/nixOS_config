# modules/home/yazi.nix
{ pkgs, config, lib, ... }:

{
  # Disable the built-in Yazi module (we'll write configs manually)
  programs.yazi.enable = false;

  # Write yazi.toml with the new [mgr] section
  home.file.".config/yazi/yazi.toml".text = ''
    [mgr]
    show_hidden = true
    sort_by = "mtime"
    sort_reverse = true

    [open]
    rules = [
      { name = "*.pdf",   use = [ "default" "gui_open" ] }
      { name = "*.docx",  use = [ "doc" "gui_open" ] }
      { mime = "video/*", use = [ "play" "gui_open" ] }
      { mime = "text/*",  use = [ "edit" "gui_open" ] }
      { mime = "image/*", use = [ "default" "gui_open" ] }
    ]

    [opener]
    edit = [ { run = "emacs \"$@\"", block = true, desc = "Edit in Emacs" } ]
    play = [ { run = "vlc \"$@\"", orphan = true, desc = "Open in VLC" } ]
    gui_open = [ { run = "dolphin \"$(dirname \"$1\")\"", orphan = true, desc = "Reveal in Dolphin" } ]
    doc = [ { run = "libreoffice \"$@\"", orphan = true, desc = "Open in LibreOffice" } ]
    default = [ { run = "xdg-open \"$@\"", desc = "System Default" } ]
  '';

  # Write keymap.toml using the new [[keymap]] format
  home.file.".config/yazi/keymap.toml".text = ''
    [[keymap]]
    on = [ "O" ]
    run = "open --interactive"
    desc = "Open With..."
  '';
}
