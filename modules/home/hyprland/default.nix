{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  blue = "0xff7aa2f7";
  gray = "0xff414868";
  wallpaper = "/home/shaul/nixos-config/wallpaper.jpg";
in {
  imports = [ ../yazi.nix ../waybar.nix ../lock-idle.nix ../scripts.nix ];

  home.packages = with pkgs; [
    awww
    mako
    kdePackages.kded
    waybar
    fuzzel
    kdePackages.dolphin
    kdePackages.okular
    kdePackages.kate
    kdePackages.kde
  ];

  xdg.configFile."hypr/hyprland.conf".text = ''
    monitor = , 1366x768@60, 0x0, 1

    exec-once = uwsm finalize
    exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --all
    exec-once = waybar
    exec-once = mako
    exec-once = kded5
    exec-once = bash -c "awww-daemon && until awww ping 2>/dev/null; do sleep 0.5; done && awww img /home/shaul/nixos-config/wallpaper.jpg"
    exec-once = nm-applet --indicator
    exec-once = udiskie --tray
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    exec-once = bash -c "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store"

    input {
        kb_layout = us,il
       kb_options = grp:ctrl_shift_toggle,caps:escape
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
        col.active_border = ${blue}
        col.inactive_border = ${gray}
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
    windowrule = match:class ^(scratchpad)$, float on
    windowrule = match:class ^(emacs-scratch)$, float on
    windowrule = match:class ^(scratchpad)$, size 1100 600
    windowrule = match:class ^(emacs-scratch)$, size 1100 600
    windowrule = match:class ^(scratchpad)$, center on
    windowrule = match:class ^(emacs-scratch)$, center on

    # File‑picker dialogs
    windowrule = match:title ^(Open|Save|Select|Choose), float on

    # Other floating apps
    windowrule = match:class ^(pavucontrol)$, float on
    windowrule = match:class ^(nm-connection-editor)$, float on

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

    # Emacs-style splitting controls (Dwindle layout)
    # Dwindle preselect directions (Emacs-style splitting)
    bind = $mainMod CTRL, L, layoutmsg, preselect l
    bind = $mainMod CTRL, R, layoutmsg, preselect r
    bind = $mainMod CTRL, U, layoutmsg, preselect u
    bind = $mainMod CTRL, D, layoutmsg, preselect d

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
