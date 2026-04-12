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

  # --- ADVANCED SCRIPT: POWER SEARCH (FD + FUZZEL + ACTIONS) ---
  powerSearch = pkgs.writeShellScriptBin "power-search" ''
    FILE=$(fd . $HOME --exclude .cache --exclude .git | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰍉 Search: ")
    [ -z "$FILE" ] && exit 0

    ACTION=$(echo -e "🚀 Open\n📁 Open Folder (Yazi)\n💻 Open Terminal Here" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Action: ")
    case "$ACTION" in
        "🚀 Open") xdg-open "$FILE" ;;
        "📁 Open Folder (Yazi)") ${pkgs.foot}/bin/foot -e ${pkgs.yazi}/bin/yazi "$(dirname "$FILE")" ;;
        "💻 Open Terminal Here") ${pkgs.foot}/bin/foot -D "$(dirname "$FILE")" ;;
    esac
  '';

  # --- ADVANCED SCRIPT: FOCUS SPOTLIGHT (Idea #3) ---
  spotlight = pkgs.writeShellScriptBin "niri-spotlight" ''
    STATE_FILE="/tmp/niri-spotlight-state"
    if [ ! -f "$STATE_FILE" ]; then
        # Entering Spotlight
        niri msg action toggle-window-floating
        niri msg action center-column
        # Enlarge: Use proportion logic
        niri msg action set-column-width "90%"
        # Dim others (via a temporary rule or global opacity)
        # Note: Niri doesn't have a 'dim others' command, so we set global background opacity
        # and hide the bar for immersion
        pkill -SIGUSR1 waybar
        touch "$STATE_FILE"
    else
        # Exiting Spotlight
        niri msg action toggle-window-floating
        niri msg action set-column-width "50%"
        pkill -SIGUSR1 waybar
        rm "$STATE_FILE"
    fi
  '';

  # --- ADVANCED SCRIPT: SWALLOW WRAPPER (Idea #2) ---
  # Usage: swallow imv photo.jpg
  swallow = pkgs.writeShellScriptBin "swallow" ''
    WINDOW_ID=$(niri msg --json windows | jq '.[] | select(.is_focused == true) | .id')
    niri msg action set-window-opacity 0.0
    "$@"
    niri msg action set-window-opacity 1.0
  '';

  # --- ADVANCED SCRIPT: TELEPORT (Idea #4) ---
  # Uses Fuzzel to list windows and jump to them instantly
  teleport = pkgs.writeShellScriptBin "teleport" ''
    WINDOW=$(niri msg --json windows | jq -r '.[] | "\(.title) | \(.app_id) | \(.id)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
    [ -z "$WINDOW" ] && exit 0
    ID=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
    niri msg action focus-window --id "$ID"
  '';

in {
  imports = [ ../yazi.nix ];

  home.packages = with pkgs; [
    foot fuzzel waybar mako swww wlogout avizo
    grim slurp wl-clipboard cliphist swaylock-effects
    swayidle playerctl udiskie pavucontrol light
    networkmanagerapplet nm-connection-editor
    libsecret fd fzf jq
    powerSearch spotlight swallow teleport
  ];

  # --- SERVICES (The "Invisible" Logic) ---

  services.gnome-keyring.enable = true; # Fixes Wi-Fi forgotten passwords

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

  # --- NIRI CONFIG (KDL) ---
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

    # --- WINDOW RULES ---

    // Idea #1: Inactive Window Dimming
    window-rule {
        match is-active=false;
        opacity 0.7
    }

    // Rules for Dialogs and Tools
    window-rule {
        match is-active=true;
        match title="Open File";
        match title="Save File";
        match app-id="nm-connection-editor";
        match app-id="pavucontrol";
        open-floating true;
    }

    // Scratchpad Styling
    window-rule {
        match title="scratchpad";
        open-floating true;
        sticky true;
        default-floating-width 1100
        default-floating-height 650
    }

    # --- STARTUP ---
    spawn-at-startup "uwsm" "app" "--" "waybar"
    spawn-at-startup "uwsm" "app" "--" "mako"
    spawn-at-startup "uwsm" "app" "--" "swww-daemon"
    spawn-at-startup "uwsm" "app" "--" "nm-applet"
    spawn-at-startup "uwsm" "app" "--" "udiskie" "--tray"
    spawn-at-startup "bash" "-c" "wl-paste --watch cliphist store"

    # --- GESTURES (Spatial) ---
    gestures {
        swipe-left { move-column-left; }
        swipe-right { move-column-right; }
        swipe-up { focus-workspace-down; }
        swipe-down { focus-workspace-up; }
    }

    # --- BINDS ---
    binds {
        // Essentials
        Mod+Return { spawn "uwsm" "app" "--" "foot"; }
        Mod+D { spawn "uwsm" "app" "--" "fuzzel"; }
        Mod+N { spawn "uwsm" "app" "--" "nm-connection-editor"; }
        Mod+V { spawn "bash" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy"; }
        Mod+Shift+C { close-window; }
        Mod+Shift+Q { spawn "wlogout"; }

        // Advanced Features
        Mod+Space { spawn "power-search"; }      // Power Search (Idea #4)
        Mod+T { spawn "teleport"; }              // Interactive Teleport (Idea #4)
        Mod+Alt+S { spawn "niri-spotlight"; }    // Deep Work Spotlight (Idea #3)
        Mod+S { spawn "foot" "-t" "scratchpad"; } // Quick Scratchpad

        // Spatial Navigation (Mod+HJKL or Mod+Arrows)
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+L     { focus-column-right; }

        Mod+Up    { focus-workspace-up; }
        Mod+Down  { focus-workspace-down; }
        Mod+K     { focus-workspace-up; }
        Mod+J     { focus-workspace-down; }

        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up    { move-window-to-workspace-up; }
        Mod+Shift+Down  { move-window-to-workspace-down; }

        // Layout Manipulation
        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+C { center-column; }

        // Multimedia
        XF86AudioRaiseVolume   { spawn "volumectl" "-u" "up"; }
        XF86AudioLowerVolume   { spawn "volumectl" "-u" "down"; }
        XF86AudioMute          { spawn "volumectl" "toggle-mute"; }
        XF86MonBrightnessUp    { spawn "light" "-A" "5"; }
        XF86MonBrightnessDown  { spawn "light" "-U" "5"; }

        Print { spawn "bash" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }
    }
  '';

  # --- WAYBAR (Floating Island Design) ---
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      margin = "8 12 0 12";
      modules-left = [ "niri/window" ];
      modules-center = [ "niri/workspaces" ];
      modules-right = [ "network" "pulseaudio" "battery" "clock" "tray" ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = { default = "○"; focused = "●"; };
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

      clock = { format = "󰥔  {:%H:%M}"; };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
      }
      window#waybar { background: transparent; }
      #window, #workspaces, #network, #pulseaudio, #battery, #clock, #tray {
        background: ${bg};
        color: ${fg};
        padding: 4px 14px;
        margin: 0 4px;
        border-radius: 12px;
        border: 1px solid ${gray};
      }
      #workspaces button { color: ${gray}; }
      #workspaces button.focused { color: ${blue}; }
    '';
  };

  # --- GTK & THEME OVERRIDES ---
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
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };
}
