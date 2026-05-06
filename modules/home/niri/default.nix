{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  magenta = "#bb9af7";
  gray = "#414868";
in {
  imports = [ ../yazi.nix ../waybar.nix ../lock-niri.nix ];   # ← was lock-idle.nix

  home.packages = with pkgs; [
    awww
    mako
    waybar
    fuzzel
    xwayland-satellite
  ];

  # Master Niri KDL Configuration
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,il"
                options "grp:win_space_toggle,caps:escape"
            }
            repeat-delay 250
            repeat-rate 40
        }
        touchpad {
            tap
            dwt
            natural-scroll false // Traditional
        }
        mouse {
            natural-scroll false
        }
    }

    output ".*" {
        scale 1.0
    }

    layout {
        gaps 8 // Optimized for 768p
        center-focused-column "never"
        preset-column-widths {
            proportion 0.333
            proportion 0.5
            proportion 0.666
        }
        default-column-width { proportion 0.5; }

        focus-ring {
            width 4
            active-color "${blue}"
            inactive-color "${gray}"
        }

        // Space Saving: Disable window titlebars
        border {
            width 2
            active-color "${blue}"
            inactive-color "${gray}"
        }
    }

    animations {
        slowdown 1.2
        workspace-switch { spring stiffness=800 damping-ratio=1.0 epsilon=0.0001; }
        window-open { spring stiffness=800 damping-ratio=1.0 epsilon=0.0001; }
    }

    window-rule {
        match is-active=false;
        opacity 0.7
    }

    window-rule {
        match app-id="nm-connection-editor";
        match app-id="pavucontrol";
        open-floating true;
    }

    window-rule {
        match app-id="scratchpad";
        open-floating true;
        default-column-width { fixed 1100; }
    }

    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "awww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "udiskie" "--tray"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store"
    spawn-at-startup "uwsm" "finalize"
    spawn-at-startup "bash" "-c" "awww img /etc/nixos/wallpaper.jpg"

    binds {
        Mod+Slash { show-hotkey-overlay; }
        Mod+Return { spawn "foot"; }
        Mod+D { spawn "fuzzel"; }
        Mod+N { spawn "nm-connection-editor"; }
        Mod+V { spawn "bash" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy"; }
        Mod+Shift+C { close-window; }
        Mod+Shift+Q { spawn "wlogout"; }

        // Universal Script Binds
        Mod+Space { spawn "power-search"; }
        Mod+T { spawn "teleport"; }
        Mod+Alt+S { spawn "spotlight"; }
        Mod+grave { spawn "toggle-scratchpad-terminal"; }
        Mod+Shift+grave { spawn "toggle-scratchpad-emacs"; }

        // Navigation (HJKL)
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+K { focus-workspace-up; }
        Mod+J { focus-workspace-down; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+K { move-window-to-workspace-up; }
        Mod+Shift+J { move-window-to-workspace-down; }

        // Tiling & Floating Logic (The Hybrid)
        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+Shift+Space { toggle-window-floating; }
        Mod+C { center-column; }

        // Touchpad Navigation (Req 5.3)
        Mod+TouchpadScrollLeft  { focus-column-left; }
        Mod+TouchpadScrollRight { focus-column-right; }
        Mod+TouchpadScrollUp    { focus-workspace-up; }
        Mod+TouchpadScrollDown  { focus-workspace-down; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        // Hardware Controls
        XF86AudioRaiseVolume { spawn "volctl" "up"; }
        XF86AudioLowerVolume { spawn "volctl" "down"; }
        XF86AudioMute { spawn "volctl" "mute"; }
        XF86MonBrightnessUp { spawn "volctl" "br-up"; }
        XF86MonBrightnessDown { spawn "volctl" "br-down"; }

        Print { spawn "screenshot-edit"; }

        // Resolution Magnifier
        Mod+Equal { set-column-width "+10%"; }
        Mod+Minus { set-column-width "-10%"; }
    }
  '';
}
