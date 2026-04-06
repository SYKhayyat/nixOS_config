# modules/home/niri/default.nix
# Niri Configuration (KDL format)
# modules/home/niri/default.nix
# modules/home/niri/default.nix
# modules/home/niri/default.nix
# modules/home/niri/default.nix
# modules/home/niri/default.nix
# Niri desktop configuration with high-priority theme overrides

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
    pavucontrol          # Audio GUI
    networkmanagerapplet # Wi-Fi tray applet
    light                # Brightness control
    kdePackages.dolphin  # GUI file manager
    
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    culmus
    nerd-fonts.jetbrains-mono
  ];

  # ══════════════════════════════════════════════════════════════════
  # GTK & QT OVERRIDES
  # Using lib.mkForce (Priority 50) to outrank common.nix (Priority 1000)
  # ══════════════════════════════════════════════════════════════════

  gtk = {
    enable = true;
    theme = {
      name = lib.mkForce "Adwaita-dark";
      package = lib.mkForce pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = lib.mkForce "adwaita";
    style.name = lib.mkForce "adwaita-dark";
  };

  # ══════════════════════════════════════════════════════════════════
  # NIRI CONFIGURATION (KDL)
  # ══════════════════════════════════════════════════════════════════

  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,il"
                options "grp:alt_shift_toggle"
            }
        }
        touchpad {
            tap
            dwt
        }
        mouse { }
    }

    output ".*" {
        scale 1.0
    }

    layout {
        gaps 12

        default-column-width {
            proportion 0.5
        }

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
    }

    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "avizo-service"
    spawn-at-startup "udiskie" "--tray"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store"

    binds {
        Mod+Return { spawn "foot"; }
        Mod+D { spawn "fuzzel"; }
        Mod+N { spawn "foot" "-e" "nmtui"; }
        Mod+V { spawn "bash" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy"; }

        Mod+Alt+L { spawn "swaylock" "-f" "-c" "000000"; }

        Mod+E { spawn "foot" "yazi"; }
        Mod+Shift+E { spawn "dolphin"; }
        Mod+Shift+Q { spawn "wlogout"; }
        Mod+Shift+C { close-window; }

        Mod+Left  { focus-column-left; }
        Mod+H     { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+L     { focus-column-right; }
        Mod+Up    { focus-window-up; }
        Mod+K     { focus-window-up; }
        Mod+Down  { focus-window-down; }
        Mod+J     { focus-window-down; }

        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+H     { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+L     { move-column-right; }
        Mod+Shift+Up    { move-window-up; }
        Mod+Shift+K     { move-window-up; }
        Mod+Shift+Down  { move-window-down; }
        Mod+Shift+J     { move-window-down; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        XF86AudioRaiseVolume   { spawn "volumectl" "-u" "up"; }
        XF86AudioLowerVolume   { spawn "volumectl" "-u" "down"; }
        XF86AudioMute          { spawn "volumectl" "toggle-mute"; }
        XF86MonBrightnessUp    { spawn "light" "-A" "5"; }
        XF86MonBrightnessDown  { spawn "light" "-U" "5"; }

        XF86AudioPlay { spawn "playerctl" "play-pause"; }
        XF86AudioNext { spawn "playerctl" "next"; }
        XF86AudioPrev { spawn "playerctl" "previous"; }

        Print { spawn "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }
    }
  '';

  # ══════════════════════════════════════════════════════════════════
  # WAYBAR CONFIGURATION
  # ══════════════════════════════════════════════════════════════════

  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      modules-left = [ "niri/window" "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "network" "pulseaudio" "backlight" "cpu" "memory" "battery" "tray" ];

      clock = {
        format = "  {:%H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      network = {
        format-wifi = "󰤨";
        format-ethernet = "󰈀";
        format-disconnected = "󰤭";
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        tooltip-format-ethernet = "{ifname}";
        tooltip-format-disconnected = "Disconnected";
        on-click = "foot -e nmtui";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons = {
          default = [ "󰕿" "󰖀" "󰕾" ];
        };
        on-click = "pavucontrol";
      };

      backlight = {
        format = "󰃠 {percent}%";
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew";
        font-size: 13px;
        font-weight: bold;
      }

      window#waybar {
        background: #1a1b26;
        color: #a9b1d6;
      }

      #workspaces button {
        padding: 0 8px;
        color: #565f89;
      }

      #workspaces button.focused {
        color: #7aa2f7;
        border-bottom: 2px solid #7aa2f7;
      }

      #clock, #network, #pulseaudio, #backlight, #cpu, #memory, #battery, #tray {
        padding: 0 10px;
        margin: 4px 4px;
        background: #24283b;
        border-radius: 6px;
      }
    '';
  };
}
