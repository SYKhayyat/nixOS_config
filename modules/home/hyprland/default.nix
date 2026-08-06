# modules/home/hyprland/default.nix
#
# The Hyprland session: its config file, and nothing else. The bar, launcher,
# notifier, wallpaper daemon, locker, terminal and file manager it spawns below
# all come from ../wayland-common.nix, which the niri session imports too.
#
# Border colours come from ../palette.nix in hyprlang's own `rgb(…)` spelling.
# They used to be a hand-written third format, `0xAARRGGBB`, kept beside the
# `#rrggbb` literals for the same two colours — one theme, three transcriptions,
# and the transcription hyprlock got was a parse error. Two formats now, both
# generated.
{ config, pkgs, ... }:

let
  inherit (config.shaulos.palette) hypr;
  wallpaper = ../../../wallpaper.jpg;
in
{
  imports = [ ../palette.nix ];

  xdg.configFile."hypr/hyprland.conf".text = ''
    # `preferred, auto` rather than the panel this laptop happens to have.
    # The niri config has always said `output ".*" { scale 1.0 }`; hardcoding
    # 1366x768@60 here meant plugging in an external display behaved differently
    # in the two sessions, for no reason anyone chose.
    monitor = , preferred, auto, 1

    exec-once = uwsm finalize
    exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --all
    exec-once = waybar
    exec-once = mako
    # Idle -> dim -> lock -> DPMS off. Config in modules/home/lock.nix, which
    # has always existed and which nothing had ever actually started.
    exec-once = hypridle

    exec-once = bash -c "${pkgs.swww}/bin/swww-daemon & until ${pkgs.swww}/bin/swww query 2>/dev/null; do sleep 0.5; done && ${pkgs.swww}/bin/swww img ${wallpaper}"
    exec-once = nm-applet --indicator
    exec-once = udiskie --tray
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    exec-once = bash -c "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store"

    input {
        kb_layout = us,il
kb_options = grp:lctrl_lalt_toggle,caps:escape
        repeat_delay = 250
        repeat_rate = 40
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

    # File‑picker dialogs
    windowrule = float, title:^(Open|Save|Select|Choose).*$

    # Other floating apps
    windowrule = float, class:^(pavucontrol)$
    windowrule = float, class:^(nm-connection-editor)$

    $mainMod = SUPER

    bind = $mainMod, Return, exec, foot
    bind = $mainMod, D, exec, fuzzel
    bind = $mainMod, P, exec, power-search
    bind = $mainMod, N, exec, nm-connection-editor
    bind = $mainMod, V, exec, bash -c "${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel -d | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
    bind = $mainMod SHIFT, C, killactive
    bind = $mainMod SHIFT, Q, exec, wlogout

    bind = $mainMod, T, exec, teleport
    bind = $mainMod ALT, S, exec, spotlight
    bind = $mainMod, grave, exec, toggle-scratchpad-terminal
    bind = $mainMod SHIFT, grave, exec, toggle-scratchpad-emacs

    # ── New keybinds ────────────────────────────────────────────
    # Scratchpads (saner keys)
    bind = $mainMod SHIFT, Return, exec, toggle-scratchpad-terminal
    bind = $mainMod CTRL, Return, exec, toggle-scratchpad-emacs

    # Hide / restore window (special workspace)
    bind = $mainMod, S, togglespecialworkspace
    bind = $mainMod SHIFT, S, movetoworkspace, special

    # Tab groups
    bind = $mainMod, W, togglegroup
    bind = $mainMod, Tab, changegroupactive, f
    bind = $mainMod SHIFT, Tab, changegroupactive, b

    # Launch apps
    bind = $mainMod, E, exec, dolphin
    bind = $mainMod SHIFT, E, exec, emacs

    # Master layout manipulation
    bind = $mainMod, M, layoutmsg, swapwithmaster master
    bind = $mainMod SHIFT, J, layoutmsg, swapnext
    bind = $mainMod SHIFT, K, layoutmsg, swapprev

    # Silent workspace moves (extend to 4 and 5)
    bind = $mainMod SHIFT, 4, movetoworkspacesilent, 4
    bind = $mainMod SHIFT, 5, movetoworkspacesilent, 5

    # Pseudo‑tile toggle
    bind = $mainMod, G, pseudo

    # Focus among floating windows
    bind = $mainMod, B, cyclenext, floating

    # Center a floating window
    bind = $mainMod, C, centerwindow

    # Resize windows
        bind = $mainMod ALT, H, resizeactive, -20 0
    bind = $mainMod ALT, L, resizeactive, 20 0
    bind = $mainMod ALT, K, resizeactive, 0 -20
    bind = $mainMod ALT, J, resizeactive, 0 20

    # Dwindle split control (only meaningful under the dwindle layout;
    # toggle master<->dwindle with $mainMod SHIFT, R below)
    bind = $mainMod CTRL, Backslash, layoutmsg, togglesplit

    # ── Navigation (HJKL) ──────────────────────────────────────
    bind = $mainMod, H, movefocus, l
    bind = $mainMod, L, movefocus, r
    bind = $mainMod, K, cyclenext
    bind = $mainMod, J, cyclenext, prev

    bind = $mainMod SHIFT, R, exec, hyprctl keyword general:layout $(hyprctl getoption general:layout | grep -q master && echo dwindle || echo master)
    bind = $mainMod, F, fullscreen, 0
    bind = $mainMod SHIFT, Space, togglefloating

    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3

    bind = , XF86AudioRaiseVolume, exec, volctl up
    bind = , XF86AudioLowerVolume, exec, volctl down
    bind = , XF86AudioMute, exec, volctl mute
    bind = , XF86MonBrightnessUp, exec, volctl br-up
    bind = , XF86MonBrightnessDown, exec, volctl br-down

    bind = , Print, exec, screenshot-edit
  '';
}
