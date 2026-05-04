{ pkgs, lib, ... }:

let
  compositorDetect = ''
    if pgrep -x niri > /dev/null; then
      COMPOSITOR="niri"
    elif pgrep -x Hyprland > /dev/null; then
      COMPOSITOR="hyprland"
    else
      COMPOSITOR="plasma"
    fi
  '';

  powerSearch = pkgs.writeShellScriptBin "power-search" ''
    ${compositorDetect}
    if [ "$COMPOSITOR" = "plasma" ]; then
      # Use KRunner for Plasma
      dbus-send --session --dest=org.kde.krunner --type=method_call /App org.kde.krunner.App.display
      exit 0
    fi

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
            xdg-terminal-exec -D "$DIR" ;;
    esac
  '';

  spotlight = pkgs.writeShellScriptBin "spotlight" ''
    ${compositorDetect}
    STATE_FILE="/tmp/spotlight-state"

    if [ "$COMPOSITOR" = "niri" ]; then
      if [ ! -f "$STATE_FILE" ]; then
          niri msg action toggle-window-floating
          niri msg action set-window-size 90% 90%
          niri msg action center-window
          pkill -SIGUSR2 waybar
          touch "$STATE_FILE"
      else
          niri msg action toggle-window-floating
          pkill -SIGUSR2 waybar
          rm "$STATE_FILE"
      fi
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      if [ ! -f "$STATE_FILE" ]; then
          hyprctl dispatch togglefloating
          hyprctl dispatch centerwindow
          hyprctl dispatch resizeactive exact 90% 90%
          pkill -SIGUSR2 waybar
          touch "$STATE_FILE"
      else
          hyprctl dispatch togglefloating
          hyprctl dispatch resizeactive exact 50% 50%
          pkill -SIGUSR2 waybar
          rm "$STATE_FILE"
      fi
    fi
  '';

  swallow = pkgs.writeShellScriptBin "swallow" ''
    ${compositorDetect}
    if [ "$COMPOSITOR" = "niri" ]; then
      niri msg action set-window-opacity 0.0
      "$@"
      niri msg action set-window-opacity 1.0
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      hyprctl dispatch setprop active opaque toggle
      "$@"
      hyprctl dispatch setprop active opaque toggle
    else
      "$@"
    fi
  '';

  teleport = pkgs.writeShellScriptBin "teleport" ''
    ${compositorDetect}
    if [ "$COMPOSITOR" = "niri" ]; then
      WINDOW=$(niri msg --json windows | jq -r '.[] | "\(.title) | \(.app_id) | \(.id)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
      [ -z "$WINDOW" ] && exit 0
      ID=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
      niri msg action focus-window --id "$ID"
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      hyprctl clients -j | jq -r '.[] | "\(.title) | \(.class) | \(.address)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: " | while read -r line; do
        ADDR=$(echo "$line" | awk -F '|' '{print $NF}' | tr -d ' ')
        hyprctl dispatch focuswindow "address:$ADDR"
      done
    fi
  '';

  screenshot = pkgs.writeShellScriptBin "screenshot-edit" ''
    FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
    mkdir -p "$(dirname "$FILE")"
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$FILE"
    if [ -f "$FILE" ]; then
       ${pkgs.swappy}/bin/swappy -f "$FILE"
    fi
  '';

  toggleTermScratch = pkgs.writeShellScriptBin "toggle-scratchpad-terminal" ''
    ${compositorDetect}
    TERM_TITLE="scratchterm"

    if [ "$COMPOSITOR" = "niri" ]; then
      if niri msg --json windows | jq -e '.[] | select(.title == "'$TERM_TITLE'")' > /dev/null; then
        niri msg action focus-window --title "$TERM_TITLE"
      else
        ${pkgs.foot}/bin/foot --title="$TERM_TITLE" &
        sleep 0.5
        niri msg action focus-window --title "$TERM_TITLE"
      fi
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      if hyprctl clients -j | jq -e '.[] | select(.title == "'$TERM_TITLE'")' > /dev/null; then
        hyprctl dispatch focuswindow "title:$TERM_TITLE"
      else
        ${pkgs.foot}/bin/foot --title="$TERM_TITLE" &
        sleep 0.5
        hyprctl dispatch focuswindow "title:$TERM_TITLE"
      fi
    fi
  '';

  toggleEmacsScratch = pkgs.writeShellScriptBin "toggle-scratchpad-emacs" ''
    ${compositorDetect}
    FRAME_NAME="emacs-scratch"

    ${pkgs.emacs}/bin/emacsclient -a "" -e "(+ 1 1)" > /dev/null 2>&1

    ${pkgs.emacs}/bin/emacsclient -a "" -e "(progn
      (unless (seq-find (lambda (f) (string= (frame-parameter f 'name) \"$FRAME_NAME\")) (frame-list))
        (make-frame '((name . \"$FRAME_NAME\") (width . 80) (height . 25) (menu-bar-lines . 0) (tool-bar-lines . 0))))
      (select-frame-by-name \"$FRAME_NAME\"))"

    if [ "$COMPOSITOR" = "niri" ]; then
      sleep 0.3
      niri msg action focus-window --title "$FRAME_NAME"
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      sleep 0.3
      hyprctl dispatch focuswindow "title:$FRAME_NAME"
    fi
  '';

  volctl = pkgs.writeShellScriptBin "volctl" ''
    set -euo pipefail
    STEP=3
    case "''${1:-}" in
      up)   ${pkgs.pamixer}/bin/pamixer -i $STEP ;;
      down) ${pkgs.pamixer}/bin/pamixer -d $STEP ;;
      toggle-mute) ${pkgs.pamixer}/bin/pamixer -t ;;
      br-up) ${pkgs.brightnessctl}/bin/brightnessctl set +5% ;;
      br-down) ${pkgs.brightnessctl}/bin/brightnessctl set 5%- ;;
      *) echo "Usage: volctl up|down|toggle-mute|br-up|br-down" >&2; exit 1 ;;
    esac
  '';

in {
  home.packages = with pkgs; [
    pamixer
    brightnessctl
    powerSearch
    spotlight
    swallow
    teleport
    screenshot
    toggleTermScratch
    toggleEmacsScratch
    volctl
  ];
}
