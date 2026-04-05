# modules/home/niri/default.nix
# Niri Configuration (KDL format)
# modules/home/niri/default.nix
# modules/home/niri/default.nix
{ pkgs, config, lib, ... }: {
  imports = [ ../yazi.nix ];

  home.packages = with pkgs; [
    # --- Desktop Essentials ---
    foot                 # Terminal
    fuzzel               # Launcher
    waybar               # Status bar
    mako                 # Notifications
    swww                 # Wallpaper
    wlogout              # Power menu
    avizo                # Volume/Brightness OSD
    grim                 # Screenshots core
    slurp                # Region selector
    wl-clipboard         # Clipboard utils
    cliphist             # Clipboard history
    swaylock-effects     # Screen locker
    swayidle             # Idle daemon
    playerctl            # Media control
    udiskie              # Auto-mount USBs
    
    # --- Fonts ---
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji # Correct emoji package
    culmus                 # Quality Hebrew fonts
    nerd-fonts.jetbrains-mono
  ];

  # Force Dark Theme across GTK and Qt
  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
    iconTheme = { name = "Papirus-Dark"; package = pkgs.papirus-icon-theme; };
    cursorTheme = { name = "Adwaita"; package = pkgs.adwaita-icon-theme; };
  };
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  # Niri Configuration
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,il"
                options "grp:alt_shift_toggle"
            }
        }
        touchpad { tap; natural-scroll; dwt; }
        mouse { natural-scroll; }
    }

    output ".*" { scale 1.0; }

    layout {
        gap 12
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        preset-column-widths {
            proportion 0.333
            proportion 0.5
            proportion 0.666
        }
        focus-ring { width 4; active-color "#7aa2f7"; inactive-color "#414868"; }
    }

    // --- Background Services ---
    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "avizo-service"
    spawn-at-startup "udiskie" "--tray"
    // Authentication Agent (Polkit)
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    // Clipboard History
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store"

    binds {
        Mod+Return { spawn "foot"; }
        Mod+D { spawn "fuzzel"; }
        Mod+V { spawn "bash" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy"; }
        Mod+L { spawn "swaylock" "-f" "-c" "000000"; }
        
        Mod+E { spawn "foot" "yazi"; }
        Mod+Shift+E { spawn "dolphin"; }
        Mod+Shift+Q { spawn "wlogout"; }
        
        // --- HJKL Navigation ---
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+K { focus-window-up; }
        Mod+J { focus-window-down; }
        
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+J { move-window-down; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Shift+C { close-window; }
        
        // --- Hardware Keys ---
        XF86AudioRaiseVolume { spawn "volumectl" "-u" "up"; }
        XF86AudioLowerVolume { spawn "volumectl" "-u" "down"; }
        XF86AudioMute        { spawn "volumectl" "toggle-mute"; }
        XF86MonBrightnessUp   { spawn "light" "-A" "5"; }
        XF86MonBrightnessDown { spawn "light" "-U" "5"; }

        // Media Control
        XF86AudioPlay { spawn "playerctl" "play-pause"; }
        XF86AudioNext { spawn "playerctl" "next"; }
        XF86AudioPrev { spawn "playerctl" "previous"; }

        // Screenshots (Fixed Escaping)
        Print { spawn "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }
    }
  '';

  # High-End Waybar with Hebrew Support
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      modules-left = [ "niri/window" "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "backlight" "cpu" "memory" "battery" "tray" ];
      
      clock = {
        format = "  {:%H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons = { default = ["󰕿" "󰖀" "󰕾"]; };
        on-click = "pavucontrol";
      };

      backlight = {
        format = "󰃠 {percent}%";
      };

      battery = {
        states = { warning = 30; critical = 15; };
        format = "{icon} {capacity}%";
        format-icons = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
      };
    }];
    
    style = ''
      * { 
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew"; 
        font-size: 13px; font-weight: bold; 
      }
      window#waybar { background: #1a1b26; color: #a9b1d6; }
      #workspaces button { padding: 0 8px; color: #565f89; }
      #workspaces button.focused { color: #7aa2f7; border-bottom: 2px solid #7aa2f7; }
      #clock, #pulseaudio, #backlight, #cpu, #memory, #battery, #tray {
        padding: 0 10px; margin: 4px 4px;
        background: #24283b; border-radius: 6px;
      }
    '';
  };
}
