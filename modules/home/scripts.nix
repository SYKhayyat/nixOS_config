# modules/home/scripts.nix
#
# Session helpers, bound to keys in both compositor configs.
#
# The `pgrep` below is deliberate and it was not always defensible. While each
# compositor had its own boot closure, this was rediscovering at runtime — on a
# keypress path, in eight scripts — a fact the build had already compiled in.
# There is one closure for all three sessions now, so the compositor genuinely
# is not knowable until the key is pressed, and detection is the right answer.
#
# What was never right is the silent fall-through: under Plasma these scripts
# matched no branch and exited 0 having done nothing, which is three commands on
# $PATH that lie about having run. They say so now.
#
# `jq` is spelled as a store path like every other program these scripts call.
# It was bare, which meant it worked because something else happened to install
# it — home/common.nix did, on a line that also carried five duplicates of
# modules/system/cli-tools.nix. `niri`, `hyprctl`, `waybar` and `pgrep` stay
# bare deliberately: the first three come from the running session and the last
# from the NixOS required-packages set, and none of them is ours to pin.
{ pkgs, ... }:

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

  # Fail visibly instead of exiting 0 having done nothing.
  unsupported = ''
    ${pkgs.libnotify}/bin/notify-send \
      "$(basename "$0")" "needs niri or Hyprland — this session is $COMPOSITOR"
    exit 1
  '';

  # Whether this window is spotlighted is a fact about the window, and both
  # compositors have always been able to state it: niri's IPC `Window` carries
  # `is_floating`, Hyprland's `activewindow -j` carries `floating`.
  #
  # This used to keep the answer in `/tmp/spotlight-state` — touch a file going
  # in, remove it coming out, believe the file (Lamdan 3.4). Nothing kept the
  # file and the window in agreement. Unfloat the window with any other key, or
  # close it while spotlighted, and the file is a lie; and because the only
  # thing that ever removed it was the branch the lie sent you away from, it
  # stayed a lie until a reboot wiped /tmp. A cache of a value one query away,
  # with no invalidation — the same shape as the palette literals and the
  # hand-copied Qt theme, one directory over.
  #
  # waybar gets the same treatment for the same reason. `pkill -SIGUSR1 waybar`
  # is a *toggle*: it assumes it knows whether the bar is up, which is the bug
  # again at one remove — read the window truthfully, hit the bar blind, and the
  # two halves drift apart instead of the file drifting from both. Stopping and
  # starting it costs a couple of hundred milliseconds of bar and answers to
  # `pgrep`, which is a question with an answer.
  spotlight = pkgs.writeShellScriptBin "spotlight" ''
    ${compositorDetect}

    hide_bar() { pkill -x waybar; true; }
    show_bar() {
      pgrep -x waybar > /dev/null && return 0
      waybar > /dev/null 2>&1 &
    }

    # "true" / "false" / anything else, and anything else means "no window to
    # ask about" — an empty workspace, or a compositor that did not answer.
    # `tostring` rather than jq's `//`, which treats `false` as absent and would
    # report every tiled window as unknown.
    case "$COMPOSITOR" in
      niri)
        floating=$(niri msg --json windows |
          ${pkgs.jq}/bin/jq -r 'map(select(.is_focused))[0].is_floating | tostring')
        ;;
      hyprland)
        floating=$(hyprctl activewindow -j |
          ${pkgs.jq}/bin/jq -r '.floating | tostring')
        ;;
      *)
        ${unsupported}
        ;;
    esac

    case "$floating" in
      false)
        if [ "$COMPOSITOR" = "niri" ]; then
          niri msg action toggle-window-floating
          niri msg action center-column
          niri msg action set-column-width "90%"
        else
          hyprctl dispatch togglefloating
          hyprctl dispatch centerwindow
          hyprctl dispatch resizeactive exact 90% 90%
        fi
        hide_bar
        ;;
      true)
        if [ "$COMPOSITOR" = "niri" ]; then
          niri msg action toggle-window-floating
          niri msg action set-column-width "50%"
        else
          hyprctl dispatch togglefloating
        fi
        show_bar
        ;;
      *)
        ${pkgs.libnotify}/bin/notify-send \
          "spotlight" "no focused window to spotlight"
        exit 1
        ;;
    esac
  '';

  teleport = pkgs.writeShellScriptBin "teleport" ''
    ${compositorDetect}
    if [ "$COMPOSITOR" = "niri" ]; then
      WINDOW=$(niri msg --json windows | ${pkgs.jq}/bin/jq -r '.[] | "\(.title) | \(.app_id) | \(.id)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
      [ -z "$WINDOW" ] && exit 0
      ID=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
      niri msg action focus-window --id "$ID"
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      WINDOW=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | "\(.title) | \(.class) | \(.address)"' | ${pkgs.fuzzel}/bin/fuzzel -d -p "󰿄 Teleport: ")
      [ -z "$WINDOW" ] && exit 0
      ADDR=$(echo "$WINDOW" | awk -F '|' '{print $NF}' | tr -d ' ')
      hyprctl dispatch focuswindow "address:$ADDR"
    else
      ${unsupported}
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
      if niri msg --json windows | ${pkgs.jq}/bin/jq -e ".[] | select(.app_id == \"$ID\")" > /dev/null; then
        niri msg action focus-window --app-id "$ID"
      else
        ${pkgs.foot}/bin/foot --app-id="$ID" &
      fi
    elif [ "$COMPOSITOR" = "hyprland" ]; then
       if hyprctl clients -j | ${pkgs.jq}/bin/jq -e ".[] | select(.class == \"$ID\")" > /dev/null; then
         hyprctl dispatch focuswindow "class:$ID"
       else
         ${pkgs.foot}/bin/foot --app-id="$ID" &
       fi
    else
      # No compositor to focus an existing one with, but a terminal is still a
      # terminal — this is the one case where "just do the useful half" beats
      # refusing.
      ${pkgs.foot}/bin/foot --app-id="$ID" &
    fi
  '';

  toggleEmacs = pkgs.writeShellScriptBin "toggle-scratchpad-emacs" ''
    ${compositorDetect}
    NAME="emacs-scratch"
        ${pkgs.emacs}/bin/emacsclient -c -a "" -e "(progn
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
  # `power-search` used to live here: writeShellScriptBin "power-search"
  # "exec fsearch", a script whose entire body renamed a binary. That is only
  # worth doing if the thing invoking it cannot name the real program, and the
  # only caller was a keybinding. modules/home/keys.nix names fsearch.
  home.packages = [
    spotlight teleport swallow
    volctl screenshot toggleTerm toggleEmacs
  ];
}
