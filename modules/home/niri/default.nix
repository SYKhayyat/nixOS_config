{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  magenta = "#bb9af7";
  gray = "#414868";
in {
  imports = [ ../yazi.nix ../waybar.nix ../lock-niri.nix ../scripts.nix ];

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
                options "grp:caps_toggle,caps:escape"
            }
            repeat-delay 250
            repeat-rate 40
        }
        touchpad {
            tap
            dwt
            natural-scroll false
        }
    }

    output ".*" {
        scale 1.0
    }

    cursor {
        xcursor-size 12
    }

    layout {
        gaps 8 // Optimized for 768p
        center-focused-column "always"
        preset-column-widths {
            proportion 0.333
            proportion 0.5
            proportion 0.666
        }
        default-column-width { proportion 0.5; }

        focus-ring {
            width 2
            active-color "${blue}"
            inactive-color "${gray}"
        }

        border {
            width 2
            active-color "${blue}"
            inactive-color "${gray}"
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

    spawn-at-startup "bash" "-c" "sleep 2 && waybar"
    spawn-at-startup "bash" "-c" "awww-daemon && sleep 1 && awww img ${./../../../wallpaper.jpg}"
    spawn-at-startup "bash" "-c" "sleep 2 && nm-applet"
    spawn-at-startup "udiskie" "--tray"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    spawn-at-startup "bash" "-c" "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store"

    binds {
        Mod+Slash { show-hotkey-overlay; }
        Mod+Return { spawn "foot"; }
        Mod+D { spawn "fuzzel"; }
        Mod+N { spawn "nm-connection-editor"; }
        Mod+V { spawn "bash" "-c" "${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel -d | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"; }
        Mod+Shift+C { close-window; }
        Mod+Shift+Q { spawn "wlogout"; }
        Mod+Shift+Alt+Q { quit; }

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

        // New binds
        Mod+B { focus-floating; }
        Mod+U { consume-or-expel-window-left; }
        Mod+Y { consume-or-expel-window-right; }
        Mod+Ctrl+K { focus-window-top; }
        Mod+Ctrl+J { focus-window-bottom; }
        Mod+Ctrl+H { focus-monitor-left; }
        Mod+Ctrl+L { focus-monitor-right; }
        Mod+Shift+Ctrl+H { move-column-to-workspace-left; }
        Mod+Shift+Ctrl+L { move-column-to-workspace-right; }
        Mod+Tab { toggle-overview; }
        Mod+Ctrl+F { expand-column-to-available-width; }

        // Tiling & Floating Logic (The Hybrid)
        Mod+Comma  { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+Shift+Space { toggle-window-floating; }
        Mod+C { center-column; }

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
