# modules/home/niri/default.nix
# Niri Configuration (KDL format)
# modules/home/niri/default.nix
{ pkgs, config, lib, ... }: {
  imports = [ ../yazi.nix ];

  home.packages = with pkgs; [
    foot                 # Terminal
    fuzzel               # Launcher
    waybar               # Status bar
    mako                 # Notifications
    swww                 # Wallpaper
    wlogout              # Power menu
    avizo                # Volume/Brightness OSD
    networkmanagerapplet # WiFi tray
    blueman              # Bluetooth tray
    grim                 # Screenshot core
    slurp                # Region selector
    wl-clipboard         # Clipboard management
    libnotify            # Notification events
    
    # Fonts for Hebrew and UI icons
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-hebrew-sans
    nerd-fonts.jetbrains-mono 
  ];

  # Niri Configuration (KDL Format)
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                // Dual Layout: US and Israel (Hebrew)
                // Switch between them with Alt + Shift
                layout "us,il"
                options "grp:alt_shift_toggle"
            }
        }
        touchpad {
            tap
            natural-scroll
            dwt // disable-while-typing
        }
        mouse {
            natural-scroll
        }
    }

    // Matches any monitor output dynamically
    output ".*" {
        scale 1.0
    }

    layout {
        gap 12
        center-focused-column "never"
        
        default-column-width { proportion 0.5; }

        preset-column-widths {
            proportion 0.333
            proportion 0.5
            proportion 0.666
        }

        focus-ring {
            width 4
            active-color "#7aa2f7"
            inactive-color "#414868"
        }

        border {
            off
        }
    }

    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "avizo-service"

    binds {
        // App Launcher & Terminal
        Mod+Return { spawn "foot" }
        Mod+D { spawn "fuzzel" }
        
        // File Managers
        Mod+E { spawn "foot" "yazi" }
        Mod+Shift+E { spawn "dolphin" }
        
        // Session
        Mod+Shift+Q { spawn "wlogout" }
        
        // Navigation (Vim keys and Arrows)
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+L     { focus-column-right; }
        
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+H     { move-column-left; }
        Mod+Shift+L     { move-column-right; }
        
        Mod+Up    { focus-window-up; }
        Mod+Down  { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+J     { focus-window-down; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Shift+C { close-window; }
        
        // Volume/Brightness (via Avizo)
        XF86AudioRaiseVolume { spawn "volumectl" "-u" "up" }
        XF86AudioLowerVolume { spawn "volumectl" "-u" "down" }
        XF86AudioMute        { spawn "volumectl" "toggle-mute" }
        XF86MonBrightnessUp   { spawn "lightctl" "up" }
        XF86MonBrightnessDown { spawn "lightctl" "down" }

        // Screenshots (Fixed Escaping: Select area -> Clipboard)
        Print { spawn "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy" }
    }

    animations {
        slowdown 1.2
    }
  '';

  # Waybar with Hebrew and Nerd Font Support
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 36;
      modules-left = [ "niri/window" "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "network" "cpu" "memory" "battery" "tray" ];
      
      "niri/window" = { 
        format = "{}"; 
        max-length = 50; 
      };
      
      clock = {
        format = "  {:%H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
      
      network = { 
        format-wifi = "  {essid}"; 
        format-ethernet = "󰈀"; 
      };
      
      cpu = { format = "  {usage}%"; };
      memory = { format = "  {percentage}%"; };
      
      battery = {
        format = "{icon} {capacity}%";
        format-icons = ["" "" "" "" ""];
      };
    }];
    
    style = ''
      * { 
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew", "sans-serif"; 
        font-size: 14px; 
        font-weight: bold; 
      }
      window#waybar { 
        background: rgba(15, 17, 26, 0.95); 
        color: #c0caf5; 
        border-bottom: 2px solid #24283b;
      }
      #workspaces button { 
        padding: 0 5px; 
        color: #565f89; 
      }
      #workspaces button.focused { 
        color: #7aa2f7; 
      }
      #clock, #network, #cpu, #memory, #battery, #tray {
        padding: 0 10px;
        margin: 4px 2px;
        background: #24283b;
        border-radius: 8px;
      }
    '';
  };
}
