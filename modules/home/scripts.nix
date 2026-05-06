{ pkgs, lib, config, ... }:

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
      dbus-send --session --dest=org.kde.krunner --type=method_call /App org.kde.krunner.App.display
      exit 0
    fi

    # Choose search engine: plocate (fast, indexed) or fd (filesystem)
    ENGINE=$(echo -e "⚡ plocate (indexed)\n🔍 fd (filesystem)" | ${pkgs.fuzzel}/bin/fuzzel -d -p "Search engine: ")
    case "$ENGINE" in
      *plocate*)
        if command -v plocate >/dev/null; then
          FILE=$(plocate -i '' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰍉 Search: ")
        else
          ${pkgs.libnotify}/bin/notify-send "plocate not found; falling back to fd"
          FILE=$(fd . $HOME/Documents $HOME/Downloads --max-depth 4 --exclude .cache --exclude .git | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰍉 Search: ")
        fi
        ;;
      *fd*)
        FILE=$(fd . $HOME/Documents $HOME/Downloads --max-depth 4 --exclude .cache --exclude .git | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰍉 Search: ")
        ;;
      *)
        exit 0
        ;;
    esac
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

  spotlight = pkgs.writeShellScriptBin "spotlight" ''
    ${compositorDetect}
    STATE_FILE="/tmp/spotlight-state"

    if [ "$COMPOSITOR" = "niri" ]; then
      if [ ! -f "$STATE_FILE" ]; then
          niri msg action toggle-window-floating
          niri msg action center-column
          niri msg action set-column-width "90%"
          pgrep -x waybar && pkill -SIGUSR1 waybar
          touch "$STATE_FILE"
      else
          niri msg action toggle-window-floating
          niri msg action set-column-width "50%"
          pgrep -x waybar || waybar &
          pkill -SIGUSR1 waybar
          rm "$STATE_FILE"
      fi
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      if [ ! -f "$STATE_FILE" ]; then
          hyprctl dispatch togglefloating
          hyprctl dispatch centerwindow
          hyprctl dispatch resizeactive exact 90% 90%
          pkill -SIGUSR1 waybar
          touch "$STATE_FILE"
      else
          hyprctl dispatch togglefloating
          pkill -SIGUSR1 waybar
          rm "$STATE_FILE"
      fi
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
      WINDOW=$(hyprctl clients -j | jq -r '.[] | "\(.title) | \(.class) | \(.address)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
      [ -z "$WINDOW" ] && exit 0
      ADDR=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
      hyprctl dispatch focuswindow "address:$ADDR"
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

  volctl = pkgs.writeShellScriptBin "volctl" ''
    case "''${1:-}" in
      up)   ${pkgs.pamixer}/bin/pamixer -i 5 ;;
      down) ${pkgs.pamixer}/bin/pamixer -d 5 ;;
      mute) ${pkgs.pamixer}/bin/pamixer -t ;;
      br-up)   ${pkgs.brightnessctl}/bin/brightnessctl set +5% ;;
      br-down) ${pkgs.brightnessctl}/bin/brightnessctl set 5%- ;;
    esac
  '';

  screenshot = pkgs.writeShellScriptBin "screenshot-edit" ''
    FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
    mkdir -p "$(dirname "$FILE")"
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$FILE"
    [ -f "$FILE" ] && ${pkgs.swappy}/bin/swappy -f "$FILE"
  '';

  toggleTerm = pkgs.writeShellScriptBin "toggle-scratchpad-terminal" ''
    ${compositorDetect}
    ID="scratchpad"
    if [ "$COMPOSITOR" = "niri" ]; then
      if niri msg --json windows | jq -e ".[] | select(.app_id == \"$ID\")" > /dev/null; then
        niri msg action focus-window --app-id "$ID"
      else
        ${pkgs.foot}/bin/foot --app-id="$ID" &
      fi
    elif [ "$COMPOSITOR" = "hyprland" ]; then
       if hyprctl clients -j | jq -e ".[] | select(.class == \"$ID\")" > /dev/null; then
         hyprctl dispatch focuswindow "class:$ID"
       else
         ${pkgs.foot}/bin/foot --app-id="$ID" &   # ← changed --class to --app-id
       fi
    fi
  '';

  toggleEmacs = pkgs.writeShellScriptBin "toggle-scratchpad-emacs" ''
    ${compositorDetect}
    NAME="emacs-scratch"
    ${pkgs.emacs}/bin/emacsclient -a "" -e "(progn
      (unless (seq-find (lambda (f) (string= (frame-parameter f 'name) \"$NAME\")) (frame-list))
        (make-frame '((name . \"$NAME\") (width . 110) (height . 30))))
      (select-frame-by-name \"$NAME\"))"
    sleep 0.2
    if [ "$COMPOSITOR" = "niri" ]; then
      niri msg action focus-window --title "$NAME"
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      hyprctl dispatch focuswindow "title:$NAME"
    fi
  '';

in {
  home.packages = [
    powerSearch spotlight teleport swallow
    volctl screenshot toggleTerm toggleEmacs
  ];
}
