{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  blue = "#7aa2f7";
  wallpaper = toString ./../../../wallpaper.jpg;
in {
  imports = [ ../yazi.nix ../waybar.nix ../lock-idle.nix ];

  xdg.configFile."hypr/hyprland.conf".text = ''
    monitor = eDP-1, 1366x768@60, 0x0, 1

    exec-once = waybar
    exec-once = mako
    exec-once = awww-daemon
    exec-once = nm-applet --indicator
    exec-once = udiskie --tray
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    exec-once = wl-paste --watch cliphist store
    exec-once = awww img ${wallpaper}
    exec-once = uwsm finalize

    input {
        kb_layout = us,il
        kb_options = grp:win_space_toggle,caps:escape
        repeat_delay = 250
        repeat_rate = 40
        touchpad {
            natural_scroll = false // Traditional
            tap-to-click = true
        }
    }

    general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        col.active_border = ${blue}
        col.inactive_border = 0x414868
        layout = master // Default
    }

    # FIX: Modern nested decoration syntax for 25.11
    decoration {
        rounding = 10
        active_opacity = 1.0
        inactive_opacity = 0.8

        blur {
            enabled = true
            size = 5
            passes = 2
            new_optimizations = true
        }
    }

    animations {
        enabled = true
        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        animation = windows, 1, 5, myBezier
        animation = windowsOut, 1, 5, default, popup 80%   # ← popin → popup
        animation = border, 1, 10, default
        animation = fade, 1, 5, default
        animation = workspaces, 1, 5, default
    }

    # Swallow Feature (Space saving on small screen)
    misc {
        enable_swallow = true
        swallow_regex = ^(foot)$
    }

    windowrulev2 = float, class:(pavucontrol)
    windowrulev2 = float, class:(nm-connection-editor)
    windowrulev2 = float, class:(scratchpad)
    windowrulev2 = float, title:(emacs-scratch)
    windowrulev2 = size 1100 700, class:(scratchpad)
    windowrulev2 = center, class:(scratchpad)

    $mainMod = SUPER

    bind = $mainMod, Return, exec, foot
    bind = $mainMod, D, exec, fuzzel
    bind = $mainMod, N, exec, nm-connection-editor
    bind = $mainMod, V, exec, bash -c "cliphist list | fuzzel -d | cliphist decode | wl-copy"
    bind = $mainMod SHIFT, C, killactive
    bind = $mainMod SHIFT, Q, exec, wlogout

    bind = $mainMod, Space, exec, power-search
    bind = $mainMod, T, exec, teleport
    bind = $mainMod ALT, S, exec, spotlight
    bind = $mainMod, grave, exec, toggle-scratchpad-terminal
    bind = $mainMod SHIFT, grave, exec, toggle-scratchpad-emacs

    # Navigation
    bind = $mainMod, H, movefocus, l
    bind = $mainMod, L, movefocus, r
    bind = $mainMod, K, movefocus, u
    bind = $mainMod, J, movefocus, d

    # Layout Toggle: Master <-> Dwindle
    bind = $mainMod SHIFT, R, exec, hyprctl keyword general:layout $(hyprctl getoption general:layout | grep -q master && echo dwindle || echo master)
    bind = $mainMod, F, fullscreen, 0
    bind = $mainMod SHIFT, Space, togglefloating

    # Workspaces
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3

    # Hardware (volctl)
    bind = , XF86AudioRaiseVolume, exec, volctl up
    bind = , XF86AudioLowerVolume, exec, volctl down
    bind = , XF86AudioMute, exec, volctl mute
    bind = , XF86MonBrightnessUp, exec, volctl br-up
    bind = , XF86MonBrightnessDown, exec, volctl br-down

    bind = , Print, exec, screenshot-edit
  '';
}
