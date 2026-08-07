# modules/home/hyprland/default.nix
#
# The Hyprland session: its config file, and nothing else. The bar, launcher,
# notifier, wallpaper daemon, locker, terminal and file manager it spawns all
# come from ../wayland-common.nix, which the niri session imports too.
#
# The keys and the autostart list come from ../keys.nix. What is left here is
# Hyprland's own vocabulary — master/dwindle layouts, groups, the special
# workspace — and nothing in it names a program both sessions provide. Four of
# the binds this file used to carry were drift rather than choice: Mod+P for a
# search that is Mod+Space under niri, and a second pair of scratchpad keys on
# Shift+Return / Ctrl+Return duplicating the grave pair that both sessions
# already had.
#
# Border colours come from ../palette.nix in hyprlang's own `rgb(…)` spelling.
# They used to be a hand-written third format, `0xAARRGGBB`, kept beside the
# `#rrggbb` literals for the same two colours — one theme, three transcriptions,
# and the transcription hyprlock got was a parse error. Two formats now, both
# generated.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.shaulos.palette) hypr cursor;
  inherit (config.shaulos.keys) keyboard session startup;
  render = config.shaulos.keys.hypr;

  ws = lib.concatMap (n: [
    {
      mods = [ "Mod" ];
      key = toString n;
      cmd = "workspace, ${toString n}";
      desc = "Focus workspace ${toString n}";
      group = "Workspaces";
    }
    {
      # Was movetoworkspace for 1-3 and movetoworkspacesilent for 4-5, which
      # meant the window followed you to three of them and not to the other two.
      # Nobody chose that; the guide beside this file did not even record it.
      mods = [
        "Mod"
        "Shift"
      ];
      key = toString n;
      cmd = "movetoworkspace, ${toString n}";
      desc = "Move window to workspace ${toString n}";
      group = "Workspaces";
    }
  ]) (lib.range 1 5);

  binds = [
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "C";
      cmd = "killactive";
      desc = "Close the focused window";
      group = "Session";
    }
    {
      # niri has had this since it was written; Hyprland had no way out at all
      # short of the session menu.
      mods = [
        "Mod"
        "Shift"
        "Alt"
      ];
      key = "Q";
      cmd = "exit";
      desc = "Quit Hyprland immediately (emergency)";
      group = "Session";
    }

    {
      mods = [ "Mod" ];
      key = "H";
      cmd = "movefocus, l";
      desc = "Focus left";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "L";
      cmd = "movefocus, r";
      desc = "Focus right";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "K";
      cmd = "cyclenext";
      desc = "Cycle to the next window";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "J";
      cmd = "cyclenext, prev";
      desc = "Cycle to the previous window";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "B";
      cmd = "cyclenext, floating";
      desc = "Cycle among floating windows";
      group = "Focus";
    }

    {
      mods = [ "Mod" ];
      key = "M";
      cmd = "layoutmsg, swapwithmaster master";
      desc = "Swap the focused window into the master slot";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "J";
      cmd = "layoutmsg, swapnext";
      desc = "Swap with the next window in the stack";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "K";
      cmd = "layoutmsg, swapprev";
      desc = "Swap with the previous window in the stack";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "G";
      cmd = "pseudo";
      desc = "Toggle pseudo-tiling";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "C";
      cmd = "centerwindow";
      desc = "Centre a floating window";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Space";
      cmd = "togglefloating";
      desc = "Toggle floating / tiled";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "W";
      cmd = "togglegroup";
      desc = "Group the window with its neighbours (tabs)";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "Tab";
      cmd = "changegroupactive, f";
      desc = "Next tab in the group";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Tab";
      cmd = "changegroupactive, b";
      desc = "Previous tab in the group";
      group = "Arrange";
    }

    {
      mods = [ "Mod" ];
      key = "F";
      cmd = "fullscreen, 0";
      desc = "Toggle fullscreen";
      group = "Size";
    }
    {
      # Documented as Super+Ctrl for as long as the cheat-sheet existed. It has
      # always been Alt.
      mods = [
        "Mod"
        "Alt"
      ];
      key = "H";
      cmd = "resizeactive, -20 0";
      desc = "Shrink horizontally";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "L";
      cmd = "resizeactive, 20 0";
      desc = "Grow horizontally";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "K";
      cmd = "resizeactive, 0 -20";
      desc = "Shrink vertically";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "J";
      cmd = "resizeactive, 0 20";
      desc = "Grow vertically";
      group = "Size";
    }

    {
      mods = [ "Mod" ];
      key = "S";
      cmd = "togglespecialworkspace";
      desc = "Show / hide the special workspace";
      group = "Workspaces";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "S";
      cmd = "movetoworkspace, special";
      desc = "Stash the window on the special workspace";
      group = "Workspaces";
    }

    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "R";
      cmd = "exec, hyprctl keyword general:layout $(hyprctl getoption general:layout | grep -q master && echo dwindle || echo master)";
      desc = "Toggle master / dwindle layout";
      group = "Layout";
    }
    {
      # The only dwindle bind that has ever existed. The cheat-sheet listed
      # three others — Super+V, Super+Shift+V, Super+Shift+H — and the config
      # has never had any of them.
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "Backslash";
      cmd = "layoutmsg, togglesplit";
      desc = "Flip the dwindle split direction";
      group = "Layout";
    }
  ]
  ++ ws;

  # Hyprland's own session bootstrap. Not shareable: niri under uwsm does this
  # itself, and there is no niri spelling for either line.
  ownStartup = [
    {
      name = "uwsm";
      argv = [
        "uwsm"
        "finalize"
      ];
      desc = "Hand the session over to systemd";
    }
    {
      name = "dbus";
      argv = [
        "${pkgs.dbus}/bin/dbus-update-activation-environment"
        "--all"
      ];
      desc = "Export the session environment to D-Bus";
    }
  ];
in
{
  imports = [
    ../palette.nix
    ../keys.nix
  ];

  shaulos.compositors.hyprland = {
    title = "Hyprland — dynamic tiling";
    order = 2;
    intro = [
      "Windows tile to fill the screen. The default layout is *master*: one main"
      "window beside a stack, with Super+M promoting the focused window into the"
      "main slot. Super+Shift+R switches to *dwindle*, which splits the focused"
      "window in half like Emacs windows, and Super+Ctrl+\\ flips the split."
      ""
      "Super+W groups windows into tabs in place. Super+S stashes anything on"
      "the special workspace — a scratch surface that floats over whichever"
      "workspace you are on."
    ];
    inherit binds;
  };

  xdg.configFile."hypr/hyprland.conf".text = ''
    # `preferred, auto` rather than the panel this laptop happens to have.
    # The niri config has always said `output ".*" { scale 1.0 }`; hardcoding
    # 1366x768@60 here meant plugging in an external display behaved differently
    # in the two sessions, for no reason anyone chose.
    monitor = , preferred, auto, 1

    # The cursor, from ../palette.nix — i.e. from `stylix.cursor`, the same
    # source Plasma and niri now read. This file used to say nothing about the
    # cursor at all, which meant the Hyprland session got whatever the default
    # was while niri drew a 12 px one and Plasma a 24 px one.
    env = XCURSOR_THEME,${cursor.name}
    env = XCURSOR_SIZE,${toString cursor.size}

    # Autostart. The shared list is in ../keys.nix and the niri session runs the
    # same one; only the two lines above it are Hyprland's own.
    ${render.startup (ownStartup ++ startup)}

    input {
        kb_layout = ${keyboard.layout}
        kb_options = ${keyboard.optionString}
        repeat_delay = ${toString keyboard.repeatDelay}
        repeat_rate = ${toString keyboard.repeatRate}
        touchpad {
            natural_scroll = false
            tap-to-click = true
        }
    }

    general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        col.active_border = ${hypr.accent}
        col.inactive_border = ${hypr.dim}
        layout = master
    }

    master {
        mfact = 0.55
    }

    dwindle {
        preserve_split = true
        permanent_direction_override = true
    }

    decoration {
        rounding = 10
        active_opacity = .80
        inactive_opacity = 0.65

        blur {
            enabled = true
            size = 5
            passes = 2
        }
    }

    animations {
        enabled = true
        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        animation = windows, 1, 5, myBezier
        animation = windowsOut, 1, 5, default
        animation = border, 1, 10, default
        animation = fade, 1, 5, default
        animation = workspaces, 1, 5, default
    }

    misc {
        enable_swallow = false
        disable_watchdog_warning = true
    }

    # ── Floating rules ────────────────────────────────────────────
    # Scratchpads
    windowrule = float, class:^(scratchpad)$
    windowrule = float, class:^(emacs-scratch)$
    windowrule = size 1100 600, class:^(scratchpad)$
    windowrule = size 1100 600, class:^(emacs-scratch)$
    windowrule = center, class:^(scratchpad)$
    windowrule = center, class:^(emacs-scratch)$

    # File-picker dialogs
    windowrule = float, title:^(Open|Save|Select|Choose).*$

    # Other floating apps
    windowrule = float, class:^(pavucontrol)$
    windowrule = float, class:^(nm-connection-editor)$

    $mainMod = SUPER

    ${render.binds (session ++ binds)}
  '';
}
