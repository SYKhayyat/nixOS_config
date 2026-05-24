# modules/home/yazi.nix
{ pkgs, config, lib, ... }:

{
  # Yazi is now configured via Lua, not TOML
  xdg.configFile."yazi/yazi.lua".text = ''
    -- Manager options
    Manager.show_hidden = true
    Manager.sort_by = "mtime"
    Manager.sort_reverse = true

    -- Open rules (file associations)
    Opener:rule("*.pdf", { use = { "default", "gui_open" } })
    Opener:rule("*.docx", { use = { "doc", "gui_open" } })
    Opener:rule({ mime = "video/*" }, { use = { "play", "gui_open" } })
    Opener:rule({ mime = "text/*" }, { use = { "edit", "gui_open" } })
    Opener:rule({ mime = "image/*" }, { use = { "default", "gui_open" } })

    -- Openers
    Opener:add("edit", {
      run = "emacs \"$@\"",
      block = true,
      desc = "Edit in Emacs",
    })
    Opener:add("play", {
      run = "vlc \"$@\"",
      orphan = true,
      desc = "Open in VLC",
    })
    Opener:add("gui_open", {
      run = "dolphin \"$(dirname \"$1\")\"",
      orphan = true,
      desc = "Reveal in Dolphin",
    })
    Opener:add("doc", {
      run = "libreoffice \"$@\"",
      orphan = true,
      desc = "Open in LibreOffice",
    })
    Opener:add("default", {
      run = "xdg-open \"$@\"",
      desc = "System Default",
    })
  '';

  xdg.configFile."yazi/keymap.lua".text = ''
    Keymap:add({
      on = { "O" },
      run = "open --interactive",
      desc = "Open With...",
    })
  '';
}
