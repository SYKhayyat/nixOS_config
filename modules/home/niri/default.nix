{ pkgs, config, lib, ... }:

let
  # Tokyo Night Color Palette
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  magenta = "#bb9af7";
  orange = "#ff9e64";
  gray = "#414868";
  dark_bg = "#16161e";

  # ... (The scripts powerSearch, spotlight, swallow, teleport, screenshot remain exactly as they were) ...
  powerSearch = pkgs.writeShellScriptBin "power-search" ''
    FILE=$(fd . $HOME --exclude .cache --exclude .git | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰍉 Search: ")
    [ -z "$FILE" ] && exit 0

    ACTION=$(echo -e "🚀 Open\n📁 Open Folder (Yazi)\n💻 Open Terminal Here" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Action: ")
    case "$ACTION" in
        "🚀 Open") xdg-open "$FILE" ;;
        "📁 Open Folder (Yazi)")
            DIR=$(dirname "$FILE")
            ${pkgs.foot}/bin/foot -e ${pkgs.yazi}/bin/yazi "$DIR" ;;
        "💻 Open Terminal Here")
            DIR=$(dirname "$FILE")
            ${pkgs.foot}/bin/foot -D "$DIR" ;;
    esac
  '';

  spotlight = pkgs.writeShellScriptBin "niri-spotlight" ''
    STATE_FILE="/tmp/niri-spotlight-state"
    if [ ! -f "$STATE_FILE" ]; then
        niri msg action toggle-window-floating
        niri msg action center-column
        niri msg action set-column-width "90%"
        pkill -SIGUSR1 waybar
        touch "$STATE_FILE"
    else
        niri msg action toggle-window-floating
        niri msg action set-column-width "50%"
        pkill -SIGUSR1 waybar
        rm "$STATE_FILE"
    fi
  '';

  swallow = pkgs.writeShellScriptBin "swallow" ''
    niri msg action set-window-opacity 0.0
    "$@"
    niri msg action set-window-opacity 1.0
  '';

  teleport = pkgs.writeShellScriptBin "teleport" ''
    WINDOW=$(niri msg --json windows | jq -r '.[] | "\(.title) | \(.app_id) | \(.id)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
    [ -z "$WINDOW" ] && exit 0
    ID=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
    niri msg action focus-window --id "$ID"
  '';

  screenshot = pkgs.writeShellScriptBin "screenshot-edit" ''
    FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
    mkdir -p "$(dirname "$FILE")"
    grim -g "$(slurp)" "$FILE"
    if [ -f "$FILE" ]; then
       ${pkgs.swappy}/bin/swappy -f "$FILE"
    fi
  '';

in {
  imports = [ ../yazi.nix ];

  # 1. ENVIRONMENT & FONTS
  fonts.fontconfig.enable = true;

  # REMOVED: home.sessionVariables (They break Konsole in Plasma)

  home.packages = with pkgs; [
    foot fuzzel waybar mako swww wlogout avizo
    grim slurp wl-clipboard cliphist swaylock-effects
    swayidle playerctl udiskie pavucontrol light swappy
    networkmanagerapplet polkit_gnome
    libsecret fd fzf jq
    powerSearch spotlight swallow teleport screenshot
  ];

  # ... (Services: gnome-keyring, swayidle, mako, kanshi remain exactly as they were) ...
  services.gnome-keyring.enable = true;

  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = "${pkgs.swaylock-effects}/bin/swaylock -f --screenshots --clock --indicator --effect-blur 7x5"; }
    ];
    timeouts = [
      { timeout = 300; command = "${pkgs.light}/bin/light -S 10"; resumeCommand = "${pkgs.light}/bin/light -S 100"; }
      { timeout = 420; command = "${pkgs.swaylock-effects}/bin/swaylock -f --screenshots --clock --indicator --effect-blur 7x5 --ring-color ${blue}"; }
      { timeout = 600; command = "niri msg action power-off-monitors"; }
    ];
  };

  services.mako = {
    enable = true;
    settings = {
      background-color = bg;
      text-color = fg;
      border-color = blue;
      border-size = 2;
      border-radius = 12;
      default-timeout = 5000;
      font = "JetBrainsMono Nerd Font 10";
    };
  };

  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "internal";
        profile.outputs = [{
          criteria = "eDP-1";
          scale = 1.0;
          status = "enable";
        }];
      }
    ];
  };

  # 3. FUZZEL CONFIGURATION (Remains same)
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=13";
        terminal = "foot";
        prompt = "'󰍉 '";
      };
      colors = {
        background = "1a1b26ff";
        text = "c0caf5ff";
        match = "7aa2f7ff";
        selection = "414868ff";
        selection-text = "c0caf5ff";
        border = "7aa2f7ff";
      };
      border = { width = 2; radius = 10; };
    };
  };

  # 4. NIRI CONFIGURATION (Added environment block)
  xdg.configFile."niri/config.kdl".text = ''
    // These variables ONLY apply when you boot into Niri
    environment {
        QT_QPA_PLATFORM "wayland"
        NIXOS_OZONE_WL "1"
        MOZ_ENABLE_WAYLAND "1"
        GDK_BACKEND "wayland"
    }

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
            natural-scroll
        }
    }

    output ".*" {
        scale 1.0
    }

    layout {
        gaps 16
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
    }

    animations {
        slowdown 1.2
        workspace-switch {
            spring stiffness=800 damping-ratio=1.0 epsilon=0.0001
        }
        window-open {
            spring stiffness=800 damping-ratio=1.0 epsilon=0.0001
        }
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
        match title="scratchpad";
        open-floating true;
        default-column-width { fixed 1100; }
    }

    spawn-at-startup "uwsm" "app" "--" "waybar"
    spawn-at-startup "uwsm" "app" "--" "mako"
    spawn-at-startup "uwsm" "app" "--" "swww-daemon"
    spawn-at-startup "uwsm" "app" "--" "nm-applet"
    spawn-at-startup "uwsm" "app" "--" "udiskie" "--tray"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store"

    binds {
        Mod+Slash { show-hotkey-overlay; }

        Mod+Return { spawn "uwsm" "app" "--" "foot"; }
        Mod+D { spawn "uwsm" "app" "--" "fuzzel"; }
        Mod+N { spawn "uwsm" "app" "--" "nm-connection-editor"; }
        Mod+V { spawn "bash" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy"; }
        Mod+Shift+C { close-window; }
        Mod+Shift+Q { spawn "wlogout"; }

        Mod+Space { spawn "power-search"; }
        Mod+T { spawn "teleport"; }
        Mod+Alt+S { spawn "niri-spotlight"; }
        Mod+S { spawn "foot" "-t" "scratchpad"; }

        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+Up { focus-workspace-up; }
        Mod+Down { focus-workspace-down; }
        Mod+K { focus-workspace-up; }
        Mod+J { focus-workspace-down; }

        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up { move-window-to-workspace-up; }
        Mod+Shift+Down { move-window-to-workspace-down; }

        Mod+TouchpadScrollLeft  { focus-column-left; }
        Mod+TouchpadScrollRight { focus-column-right; }
        Mod+TouchpadScrollUp    { focus-workspace-up; }
        Mod+TouchpadScrollDown  { focus-workspace-down; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+C { center-column; }

        XF86AudioRaiseVolume { spawn "volumectl" "-u" "up"; }
        XF86AudioLowerVolume { spawn "volumectl" "-u" "down"; }
        XF86AudioMute { spawn "volumectl" "toggle-mute"; }
        XF86MonBrightnessUp { spawn "light" "-A" "5"; }
        XF86MonBrightnessDown { spawn "light" "-U" "5"; }

        Print { spawn "screenshot-edit"; }
    }
  '';

  # ... (Waybar, GTK/QT themes remain same) ...
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      margin = "8 12 0 12";
      modules-left = [ "niri/window" ];
      modules-center = [ "niri/workspaces" ];
      modules-right = [ "custom/help" "network" "pulseaudio" "battery" "clock" "tray" ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
            default = "○";
            focused = "●";
        };
      };

      "custom/help" = {
        format = "󰞋";
        on-click = "niri msg action show-hotkey-overlay";
        tooltip-format = "Show Shortcuts (Mod+/)";
      };

      network = {
        format-wifi = "󰤨  {essid}";
        format-disconnected = "󰤭  None";
        on-click = "nm-connection-editor";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-icons = [ "󰕿" "󰖀" "󰕾" ];
        on-click = "pavucontrol";
      };

      clock = {
        format = "󰥔  {:%H:%M}";
      };

      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew";
        font-size: 13px;
        border: none;
      }

      window#waybar {
        background: transparent;
      }

      #window, #workspaces, #network, #pulseaudio, #battery, #clock, #tray, #custom-help {
        background: ${bg};
        color: ${fg};
        padding: 4px 14px;
        margin: 0 4px;
        border-radius: 12px;
        border: 1px solid ${gray};
      }

      #workspaces button {
        color: ${gray};
        padding: 0 4px;
      }

      #workspaces button.focused {
        color: ${blue};
      }

      #custom-help {
        color: ${magenta};
      }
    '';
  };

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
}
