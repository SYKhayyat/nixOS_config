# modules/home/niri/default.nix
#
# The niri session: its KDL config and the one package only niri needs.
#
# The bar, launcher, notifier, wallpaper daemon, locker, terminal and file
# manager it spawns all come from ../wayland-common.nix, which the Hyprland
# session imports too — that is the whole point of the module.
#
# The keys and the autostart list come from ../keys.nix for exactly the same
# reason. Everything below is either a niri verb — scrolling columns, consuming
# into a column, expelling out of one — or a niri-shaped fact. Nothing here
# names a program that both sessions provide, because those keys must not
# depend on which compositor is running, and while they were written out twice
# they did not stay the same: `power-search` was Mod+Space here and Mod+P under
# Hyprland, and Mod+E, Mod+Shift+E and Mod+1..5 existed only there.
#
# Border colours come from ../palette.nix, which derives them from the stylix
# scheme. niri's KDL takes the same `#rrggbb` spelling CSS does, which is why
# this file and waybar.nix read the same `css` view.
{ config, pkgs, lib, ... }:

let
  inherit (config.shaulos.palette) css;
  inherit (config.shaulos.keys) keyboard session startup;
  render = config.shaulos.keys.niri;

  ws = lib.concatMap (n: [
    {
      mods = [ "Mod" ];
      key = toString n;
      cmd = "focus-workspace ${toString n}";
      desc = "Focus workspace ${toString n}";
      group = "Workspaces";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = toString n;
      cmd = "move-window-to-workspace ${toString n}";
      desc = "Move window to workspace ${toString n}";
      group = "Workspaces";
    }
  ]) (lib.range 1 5);

  # niri's own verbs. Anything that spawns a program belongs in ../keys.nix.
  binds = [
    {
      mods = [ "Mod" ];
      key = "Slash";
      cmd = "show-hotkey-overlay";
      desc = "niri's built-in key overlay";
      group = "Session";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "C";
      cmd = "close-window";
      desc = "Close the focused window";
      group = "Session";
    }
    {
      mods = [ "Mod" "Shift" "Alt" ];
      key = "Q";
      cmd = "quit";
      desc = "Quit niri immediately (emergency)";
      group = "Session";
    }

    {
      mods = [ "Mod" ];
      key = "H";
      cmd = "focus-column-left";
      desc = "Focus the column to the left";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "L";
      cmd = "focus-column-right";
      desc = "Focus the column to the right";
      group = "Focus";
    }
    {
      mods = [ "Mod" ];
      key = "B";
      cmd = "focus-floating";
      desc = "Focus the floating windows";
      group = "Focus";
    }
    {
      mods = [ "Mod" "Ctrl" ];
      key = "K";
      cmd = "focus-window-top";
      desc = "Focus the top window in the column";
      group = "Focus";
    }
    {
      mods = [ "Mod" "Ctrl" ];
      key = "J";
      cmd = "focus-window-bottom";
      desc = "Focus the bottom window in the column";
      group = "Focus";
    }
    {
      mods = [ "Mod" "Ctrl" ];
      key = "H";
      cmd = "focus-monitor-left";
      desc = "Focus the monitor to the left";
      group = "Focus";
    }
    {
      mods = [ "Mod" "Ctrl" ];
      key = "L";
      cmd = "focus-monitor-right";
      desc = "Focus the monitor to the right";
      group = "Focus";
    }

    {
      mods = [ "Mod" "Shift" ];
      key = "H";
      cmd = "move-column-left";
      desc = "Move the column left";
      group = "Arrange";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "L";
      cmd = "move-column-right";
      desc = "Move the column right";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "Comma";
      cmd = "consume-window-into-column";
      desc = "Pull the next window into this column";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "Period";
      cmd = "expel-window-from-column";
      desc = "Push this window out into its own column";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "U";
      cmd = "consume-or-expel-window-left";
      desc = "Consume or expel leftwards";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "Y";
      cmd = "consume-or-expel-window-right";
      desc = "Consume or expel rightwards";
      group = "Arrange";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "Space";
      cmd = "toggle-window-floating";
      desc = "Toggle floating / tiled";
      group = "Arrange";
    }
    {
      mods = [ "Mod" ];
      key = "C";
      cmd = "center-column";
      desc = "Centre the focused column";
      group = "Arrange";
    }

    {
      mods = [ "Mod" ];
      key = "R";
      cmd = "switch-preset-column-width";
      desc = "Cycle preset column width (33 / 50 / 66%)";
      group = "Size";
    }
    {
      mods = [ "Mod" ];
      key = "F";
      cmd = "maximize-column";
      desc = "Maximise the column to full width";
      group = "Size";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "F";
      cmd = "fullscreen-window";
      desc = "Fullscreen the window";
      group = "Size";
    }
    {
      mods = [ "Mod" "Ctrl" ];
      key = "F";
      cmd = "expand-column-to-available-width";
      desc = "Expand the column into the free space";
      group = "Size";
    }
    {
      mods = [ "Mod" ];
      key = "Equal";
      cmd = ''set-column-width "+10%"'';
      desc = "Widen the column by 10%";
      group = "Size";
    }
    {
      mods = [ "Mod" ];
      key = "Minus";
      cmd = ''set-column-width "-10%"'';
      desc = "Narrow the column by 10%";
      group = "Size";
    }

    {
      mods = [ "Mod" ];
      key = "K";
      cmd = "focus-workspace-up";
      desc = "Focus the workspace above";
      group = "Workspaces";
    }
    {
      mods = [ "Mod" ];
      key = "J";
      cmd = "focus-workspace-down";
      desc = "Focus the workspace below";
      group = "Workspaces";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "K";
      cmd = "move-window-to-workspace-up";
      desc = "Move the window to the workspace above";
      group = "Workspaces";
    }
    {
      mods = [ "Mod" "Shift" ];
      key = "J";
      cmd = "move-window-to-workspace-down";
      desc = "Move the window to the workspace below";
      group = "Workspaces";
    }
  ]
  ++ ws;
in
{
  imports = [
    ../palette.nix
    ../keys.nix
  ];

  home.packages = [ pkgs.xwayland-satellite ];

  shaulos.compositors.niri = {
    title = "Niri — scrollable tiling";
    order = 1;
    intro = [
      "Windows live on a ribbon that scrolls sideways forever. A *column* holds"
      "one or more windows stacked vertically; Super+, pulls the next window into"
      "the current column and Super+. pushes one back out. Nothing ever shrinks"
      "to fit — the ribbon just gets longer, and you scroll."
      ""
      "Workspaces are vertical: Super+J and Super+K move between them, and"
      "Super+1..5 jump straight to one."
    ];
    inherit binds;
  };

  # Master Niri KDL Configuration
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "${keyboard.layout}"
                options "${keyboard.options}"
            }
            repeat-delay ${toString keyboard.repeatDelay}
            repeat-rate ${toString keyboard.repeatRate}
        }
        touchpad {
            tap
            dwt
        }
    }

    output ".*" {
        scale 1.0
    }

    cursor {
        xcursor-size 12
    }

    layout {
        gaps 8
        center-focused-column "never"
        always-center-single-column true
        preset-column-widths {
            proportion 0.333
            proportion 0.5
            proportion 0.666
        }
        default-column-width { proportion 0.5; }

        focus-ring {
            width 2
            active-color "${css.accent}"
            inactive-color "${css.dim}"
        }

        border {
            width 2
            active-color "${css.accent}"
            inactive-color "${css.dim}"
        }
    }

    animations {
        slowdown 1.1
        workspace-switch { spring stiffness=800 damping-ratio=1.0 epsilon=0.0001; }
        window-open { spring stiffness=800 damping-ratio=1.0 epsilon=0.0001; }
    }

    window-rule {
        match is-active=false;
        opacity 0.85
    }

    window-rule {
        match app-id="nm-connection-editor";
        match app-id="pavucontrol";
        open-floating true;
    }

    window-rule {
        match app-id="scratchpad";
        open-floating true;
        default-column-width { proportion 0.8; }
    }

    // Autostart. One list, in ../keys.nix, shared with the Hyprland session —
    // neither can start something the other lacks, and the swww start no longer
    // races the daemon.
    ${render.startup startup}

    binds {
    ${render.binds (session ++ binds)}
    }
  '';
}
