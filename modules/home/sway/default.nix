# modules/home/sway/default.nix
#
# The sway session: its config file, and nothing else. The bar, launcher,
# notifier, wallpaper daemon, locker, terminal and file manager it spawns all
# come from ../wayland-common.nix, which niri and Hyprland import too — that
# is the whole point of the module, and the reason there is not a second
# statement of mako or fuzzel anywhere here.
#
# The keys and the autostart list come from ../keys.nix for the same reason.
# What is left below is sway's own vocabulary — the split *tree*, marks,
# the scratchpad — and nothing in it names a program the other sessions
# provide.
#
# Border colours come from ../palette.nix in CSS's `#rrggbb` spelling, which
# sway's `client.*` classes take as-is. The same two colours appear in niri's
# KDL, in hyprlang's `rgb(…)` and now here; ./palette.nix hands out the right
# spelling for each grammar, which is why there is no fourth transcription.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.shaulos.palette) css cursor;
  inherit (config.shaulos.keys) keyboard session startup;
  render = config.shaulos.keys.sway;

  ws = lib.concatMap (n: [
    {
      mods = [ "Mod" ];
      key = toString n;
      cmd = "workspace number ${toString n}";
      desc = "Go to workspace ${toString n}";
      group = "Workspaces";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = toString n;
      cmd = "move container to workspace number ${toString n}";
      desc = "Move the window to workspace ${toString n}";
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
      cmd = "kill";
      desc = "Close the focused window";
      group = "Session";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "R";
      cmd = "reload";
      desc = "Reload the sway config";
      group = "Session";
    }
    {
      mods = [
        "Mod"
        "Shift"
        "Alt"
      ];
      key = "Q";
      cmd = "exit";
      desc = "Quit sway immediately (emergency)";
      group = "Session";
    }

    # ── Focus ──
    # The four directions, then parent/child, then floating. Parent and child
    # are the pair Hyprland does not have at all: with a hand-built split
    # tree you need to climb back up a branch to reach a neighbouring one.
    {
      mods = [ "Mod" ];
      key = "H";
      cmd = "focus left";
      desc = "Focus the window to the left";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "L";
      cmd = "focus right";
      desc = "Focus the window to the right";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "K";
      cmd = "focus up";
      desc = "Focus the window above";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "J";
      cmd = "focus down";
      desc = "Focus the window below";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "U";
      cmd = "focus parent";
      desc = "Focus the parent container (climb the split tree)";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "I";
      cmd = "focus child";
      desc = "Focus the child container (descend the split tree)";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "B";
      cmd = "focus floating";
      desc = "Cycle among the floating windows";
      group = "Focus";
    }

    # ── Marks, swap, reorder ──
    # This is the sway idiom, and it is stronger than what either of the
    # other two compositors offers: Hyprland's `swapnext` exchanges the
    # focused window with its neighbour in the stack, which is a swap you
    # cannot aim. A sway mark is a name you *choose* the target of, so
    # `swap container with mark` exchanges two windows regardless of where
    # they are in the tree, and `[con_mark=…] focus` jumps back to the one
    # you marked. Mark, walk somewhere, swap, jump back — the whole loop
    # need not touch the layout.
    {
      mods = [ "Mod" ];
      key = "O";
      cmd = "mark --replace swap_target";
      desc = "Mark the focused window as the swap target";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "O";
      cmd = "swap container with mark swap_target";
      desc = "Exchange the focused window with the marked one";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "C";
      cmd = "floating enable; move position center";
      desc = "Float the window and centre it (same job as niri's centre-column, Hyprland's centerwindow)";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "H";
      cmd = "move left";
      desc = "Reposition the window left in the tree";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "L";
      cmd = "move right";
      desc = "Reposition the window right in the tree";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "K";
      cmd = "move up";
      desc = "Reposition the window up in the tree";
      group = "Arrange";
    }
    {
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "J";
      cmd = "move down";
      desc = "Reposition the window down in the tree";
      group = "Arrange";
    }

    # ── The layout verbs, all of them ──
    # You asked for every option to be open, so each of sway's four layout
    # states has a key: the two split directions (which control how the
    # *next* window joins this one and how this container is oriented),
    # `toggle split` (flip the orientation of a container you already have),
    # and tabbed/stacking for the "one visible window with titlebars" modes.
    # `workspace_layout splith` in the config is only the default these keys
    # are free to override — which is the difference between a default and a
    # decision.
    {
      mods = [ "Mod" ];
      key = "G";
      cmd = "splitv";
      desc = "Next window opens below (vertical split)";
      group = "Layout";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "G";
      cmd = "splith";
      desc = "Next window opens beside (horizontal split)";
      group = "Layout";
    }
    {
      mods = [
        "Mod"
        "Ctrl"
      ];
      key = "Backslash";
      cmd = "layout toggle split";
      desc = "Flip the split direction of this container";
      group = "Layout";
    }
    {
      mods = [ "Mod" ];
      key = "W";
      cmd = "layout tabbed";
      desc = "Switch this container to tabs";
      group = "Layout";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "W";
      cmd = "layout stacking";
      desc = "Switch this container to visible titlebars";
      group = "Layout";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Space";
      cmd = "floating toggle";
      desc = "Toggle floating / tiled";
      group = "Layout";
    }

    # ── Size ──
    {
      mods = [ "Mod" ];
      key = "F";
      cmd = "fullscreen toggle";
      desc = "Toggle fullscreen";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "F";
      cmd = "fullscreen global";
      desc = "Fullscreen the window on every output";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "H";
      cmd = "resize shrink width 20 px";
      desc = "Shrink the window horizontally";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "L";
      cmd = "resize grow width 20 px";
      desc = "Grow the window horizontally";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "K";
      cmd = "resize shrink height 20 px";
      desc = "Shrink the window vertically";
      group = "Size";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "J";
      cmd = "resize grow height 20 px";
      desc = "Grow the window vertically";
      group = "Size";
    }

    # ── Scratchpad ──
    # sway's scratchpad is a real feature, not the app-id guess the other two
    # sessions make: `move scratchpad` parks a window and `scratchpad show`
    # brings it back, both compositor-side. The terminal and Emacs scratchpad
    # keys (Mod+grave, Mod+Shift+grave) stay the shared ones from ../keys.nix
    # — ../scripts.nix drives *these* commands for them — so this pair is the
    # generic "park whatever I am on / bring back whatever I parked".
    {
      mods = [ "Mod" ];
      key = "S";
      cmd = "scratchpad show";
      desc = "Show the last-parked scratchpad window";
      group = "Workspaces";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "S";
      cmd = "move scratchpad";
      desc = "Park the focused window in the scratchpad";
      group = "Workspaces";
    }

    # ── Workspaces ──
    {
      mods = [ "Mod" ];
      key = "Comma";
      cmd = "workspace prev";
      desc = "Previous workspace";
      group = "Workspaces";
    }
    {
      mods = [ "Mod" ];
      key = "Period";
      cmd = "workspace next";
      desc = "Next workspace";
      group = "Workspaces";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Comma";
      cmd = "move container to workspace prev";
      desc = "Move the window to the previous workspace";
      group = "Workspaces";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Period";
      cmd = "move container to workspace next";
      desc = "Move the window to the next workspace";
      group = "Workspaces";
    }
  ]
  ++ ws;

  # Sway's own session bootstrap, copied from ../hyprland/default.nix and
  # not shared with it: niri under uwsm does this itself, and sway — like
  # Hyprland — has to hand the session over to uwsm and export the
  # environment to D-Bus by hand. Under the plain (non-uwsm) sway session
  # SDDM also offers, the `uwsm finalize` line is inert: uwsm is in the
  # closure for the other two sessions and answers or no-ops either way.
  ownStartup = [
    {
      name = "uwsm";
      argv = [ "uwsm" "finalize" ];
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

  shaulos.compositors.sway = {
    title = "Sway — i3-compatible tree tiling";
    order = 3;
    intro = [
      "Windows split into a *tree* you build by hand. Super+G opens the next"
      "window below and Super+Shift+G opens it beside; Super+Ctrl+\\ flips the"
      "direction of a container you already have, and Super+U / Super+I climb"
      "up and down the branches."
      ""
      "Super+O marks a window as the swap target, Super+Shift+O exchanges the"
      "focused window with it — two windows anywhere in the tree, not just"
      "neighbours. Super+W switches the current container to tabs and"
      "Super+Shift+W to visible titlebars."
      ""
      "The scratchpad is real: Super+Shift+S parks the focused window,"
      "Super+S brings back the last-parked one. The terminal and Emacs"
      "scratchpads stay on Super+grave."
    ];
    inherit binds;
  };

  xdg.configFile."sway/config".text = ''
    # Generated by modules/home/sway. Do not edit.

    # ── Session bootstrap ──
    # Hyprland's two lines, mirrored: hand the session to uwsm's systemd
    # scope, then export the environment D-Bus apps need.
    ${render.startup (ownStartup ++ startup)}

    # ── Input ──
    # The layout and options come off `myConfig.keyboard` through
    # ../keys.nix — the same two strings the X server, KWin, niri and
    # Hyprland read. Sway's input block spells them `xkb_layout` /
    # `xkb_options`, comma-joined, which is the shape ../keys.nix already
    # renders.
    input {
        type:keyboard {
            xkb_layout "${keyboard.layout}"
            xkb_options "${keyboard.optionString}"
            repeat_delay ${toString keyboard.repeatDelay}
            repeat_rate ${toString keyboard.repeatRate}
        }
        type:touchpad {
            tap enabled
            dwt enabled
        }
    }

    # The cursor, from ../palette.nix — i.e. from `stylix.cursor`, the same
    # source Plasma and niri read. Sway takes it as a seat property rather
    # than the XCURSOR_* environment pair Hyprland sets, which is sway's own
    # spelling of the same seat.
    seat seat0 xcursor_theme ${cursor.name} ${toString cursor.size}

    # One panel, auto-configured at scale 1. The same answer niri's
    # `output ".*" { scale 1.0 }` and Hyprland's `preferred, auto` give;
    # hardcoding 1366x768 here would make plugging in an external display
    # behave differently in the third session, for no reason anyone chose.
    output "*" scale 1

    # The layout defaults, which every key above is free to override:
    # `splith` (new windows split into a tree, the behaviour i3 and Hyprland
    # both have) rather than sway's stock `tabbed` (everything piled into
    # one tabbed container), which surprises people on their first login.
    # `auto_back_and_forth` keeps `workspace prev` a toggle, so a mis-tap
    # is not a one-way trip.
    workspace_layout splith
    workspace_auto_back_and_forth yes

    # Gaps and borders copied from Hyprland's: in 4 / out 8 / 2. Not retuned
    # — three sessions quietly disagreeing about how much air to leave is
    # exactly the drift ../keys.nix's header is about.
    gaps inner 4
    gaps outer 8
    default_border pixel 2
    default_floating_border pixel 2

    # Colours from ../palette.nix. sway's `client.*` classes take
    # border/background/text/indicator/child-border; the indicator is what
    # the bar reads for "focused", so it gets the accent too, the same one
    # waybar's own modules use.
    client.focused          ${css.accent} ${css.accent} ${css.fg} ${css.accent} ${css.accent}
    client.focused_inactive ${css.dim} ${css.dim} ${css.fg} ${css.dim} ${css.dim}
    client.unfocused        ${css.dim} ${css.dim} ${css.fg} ${css.dim} ${css.dim}
    client.urgent           ${css.accent} ${css.accent} ${css.fg} ${css.accent} ${css.accent}

    # ── Floating rules — Hyprland's set, in sway's selectors ──
    # The two scratchpads match on different selectors for the reason
    # ../hyprland/default.nix's comment spells out: `foot --app-id=scratchpad`
    # sets a real Wayland app-id, while an Emacs frame's `name` sets the
    # window TITLE and its app-id stays `emacs` for every frame on the
    # machine.
    for_window [app_id="^scratchpad$"] floating enable
    for_window [title="^emacs-scratch$"] floating enable

    # File-picker dialogs
    for_window [title="^(Open|Save|Select|Choose).*$"] floating enable

    # Other floating apps
    for_window [app_id="^pavucontrol$"] floating enable
    for_window [app_id="^nm-connection-editor$"] floating enable

    # No `bar` block: waybar is the bar (../waybar.nix), started by the
    # shared startup list in ../keys.nix. Declaring sway's own bar would put
    # two of them on screen — sway's is opt-in, and it is not opted in.

    ${render.binds (session ++ binds)}
  '';
}
