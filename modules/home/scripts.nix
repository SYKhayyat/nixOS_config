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
{ pkgs, myConfig, ... }:

let
  # The SAME Emacs the daemon runs — ./emacs/default.nix starts
  # `services.emacs` with `myConfig.emacsPackage`, the pgtk build that comes
  # with the emacs-config flake input's package set.
  #
  # `toggleEmacs` below said `${pkgs.emacs}`, which is a different derivation:
  # plain X11 emacs-30.2 out of nixpkgs, against
  # emacs-pgtk-with-packages-30.2 from the input. Two consequences, one visible
  # and one not. The invisible one is that naming it dragged an entire second
  # Emacs into the home closure — a few hundred megabytes to run one
  # `emacsclient`. The visible one is that emacsclient and the server it talks
  # to are supposed to be the same build; they happen to share a version here,
  # so it works, and it works for a reason nothing in this repo states or
  # checks. Bump one side and it stops.
  #
  # ../home/keys.nix already binds Emacs as bare `emacsclient`, i.e. the one on
  # $PATH, i.e. this one. This is the same fact, spelled the way this file
  # spells facts.
  emacsclient = "${myConfig.emacsPackage}/bin/emacsclient";

  # ── The detection, which could not detect Hyprland ───────────────────────
  #
  # This was `pgrep -x niri` / `pgrep -x Hyprland`. The first works. The second
  # cannot match, on this machine or any other NixOS machine, and never could.
  #
  # `pgrep -x` matches a process's `comm`, and Linux sets `comm` from the
  # basename of the *executable* — truncated to 15 characters — not from
  # argv[0]. nixpkgs wraps Hyprland: `bin/Hyprland` is a shell script that
  # fixes up PATH and ends in
  #
  #     exec -a "$0" .../bin/.Hyprland-wrapped "$@"
  #
  # `exec -a` sets argv[0], so `ps` shows `/nix/store/…/bin/Hyprland` and every
  # human check agrees the process is called Hyprland. The kernel disagrees:
  # comm is `.Hyprland-wrapp`. You can watch this happen on a running Plasma
  # session — `.plasmashell-wrapped` reports comm `.plasmashell-wr` while its
  # argv[0] is `…/bin/plasmashell`, and `pgrep -x plasmashell` finds nothing.
  #
  # niri is not wrapped — `bin/niri` is the ELF — which is exactly why one of
  # the two branches worked and the asymmetry was invisible. Under Hyprland
  # every script here fell through to `plasma`: `spotlight` and `teleport`
  # refused with "this session is plasma", `swallow` skipped the compositor
  # entirely, and both scratchpad toggles took the else-branch and spawned a
  # *new* terminal on every press instead of focusing the existing one.
  #
  # So: ask the compositors, which both answer. niri exports `NIRI_SOCKET` and
  # Hyprland exports `HYPRLAND_INSTANCE_SIGNATURE` into the environment of
  # everything they spawn — that is what those variables are for, it is how
  # `niri msg` and `hyprctl` find their own sockets, and a keybind's process is
  # a child of the compositor. No process table, no name matching, no
  # 15-character limit. The pgrep line is kept only as a fallback for a shell
  # that somehow lost the environment, and its Hyprland half now matches the
  # command line (`-f`), which is where the name actually is.
  compositorDetect = ''
    if [ -n "''${NIRI_SOCKET:-}" ]; then
      COMPOSITOR="niri"
    elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      COMPOSITOR="hyprland"
    elif pgrep -x niri > /dev/null; then
      COMPOSITOR="niri"
    elif pgrep -f '/bin/Hyprland' > /dev/null; then
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

    # `-f`, not `-x`, and for the reason the compositor detection above is
    # written the way it is: nixpkgs wraps waybar, so the running process is
    # `.waybar-wrapped` and its comm is what the kernel took from *that* name.
    # `pkill -x waybar` and `pgrep -x waybar` both matched nothing, which broke
    # this pair in opposite directions and made them additive:
    #
    #   hide_bar  killed nothing, so spotlighting never hid the bar;
    #   show_bar  then found no waybar and started one — on top of the one that
    #             was still running.
    #
    # So every spotlight round trip left an extra waybar behind, stacked on the
    # same output, and the comment two paragraphs up about stopping and starting
    # the bar "answering to pgrep" described a question that was always
    # returning the same wrong answer.
    #
    # The pattern matches the command line, where the store path ends in
    # `/bin/waybar` under both the wrapper and a direct invocation.
    # `$(id -u)` rather than `$USER`: this runs from a compositor keybind, not
    # from a login shell, and `$USER` is not guaranteed to be in that
    # environment — `pkill -u ""` is an argument error, not a no-op.
    me=$(id -u)
    hide_bar() { pkill -u "$me" -f '/bin/waybar'; true; }
    show_bar() {
      pgrep -u "$me" -f '/bin/waybar' > /dev/null && return 0
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

  # `swallow CMD...` — run CMD with the calling terminal faded out, then put it
  # back. Every line of this that touched a compositor was wrong:
  #
  #   * `niri msg action set-window-opacity` is not an action. niri's action
  #     list has `set-window-width`, `set-window-height`, `set-column-width`
  #     and `toggle-window-rule-opacity`, and nothing named set-window-opacity;
  #     niri exits 2 with "unrecognized subcommand".
  #   * `hyprctl dispatch setprop ...` puts a top-level hyprctl command behind
  #     the dispatcher. `hyprctl --help` lists `dispatch` and `setprop` as
  #     siblings — setprop is not a dispatcher and never was, so this asked
  #     Hyprland to run a dispatcher called "setprop".
  #   * even spelled `hyprctl setprop`, the usage is
  #     `setprop <regex> <property> <value>` — `toggle` is not a value, and
  #     `opaque` is a boolean that forces a window *fully opaque*, i.e. the
  #     opposite of swallowing it. The property that fades a window is `alpha`,
  #     which takes a float and multiplies the config's `active_opacity`.
  #
  # So under both compositors the decoration silently failed and only `"$@"`
  # ever ran. That is the failure this file's header is about — a command that
  # exits 0 having done a third of its job.
  #
  # Now: the restore runs from a trap, so Ctrl-C or a non-zero exit from CMD
  # cannot leave the terminal stuck invisible — which is the failure mode that
  # makes a half-working swallow worse than none. The compositor calls are
  # `|| true` for the same reason: fading is a nicety, and running CMD is the
  # job.
  swallow = pkgs.writeShellScriptBin "swallow" ''
    ${compositorDetect}

    if [ "$#" -eq 0 ]; then
      echo "usage: swallow COMMAND [ARGS...]" >&2
      exit 2
    fi

    case "$COMPOSITOR" in
      hyprland)
        restore() { hyprctl setprop active alpha 1.0 || true; }
        trap restore EXIT INT TERM
        hyprctl setprop active alpha 0.0 || true
        ;;
      niri)
        # niri's only per-window opacity control is a toggle of the opacity its
        # window rules assign, so this is symmetric rather than absolute.
        restore() { niri msg action toggle-window-rule-opacity || true; }
        trap restore EXIT INT TERM
        niri msg action toggle-window-rule-opacity || true
        ;;
      *)
        # Plasma manages its own windows; there is nothing to fade and nothing
        # to apologise for. Run the command.
        ;;
    esac

    "$@"
  '';

  # The `*)` arm is the same argument as `unsupported` above: a `case` with no
  # default accepts `volctl mute-all`, `volctl vol-up`, any typo at all, and
  # exits 0 having done nothing. ../home/keys.nix is the only caller today and
  # it passes the five words below, so this costs nothing — until the day the
  # sixth bind is added with a name this file does not have, and the key is
  # silently dead instead of loudly wrong. ./lock.nix's session-dpms already
  # takes exactly this shape.
  volctl = pkgs.writeShellScriptBin "volctl" ''
    case "''${1:-}" in
      up)   ${pkgs.pamixer}/bin/pamixer -i 5 ;;
      down) ${pkgs.pamixer}/bin/pamixer -d 5 ;;
      mute) ${pkgs.pamixer}/bin/pamixer -t ;;
      br-up)   ${pkgs.brightnessctl}/bin/brightnessctl set +5% ;;
      br-down) ${pkgs.brightnessctl}/bin/brightnessctl set 5%- ;;
      *)
        echo "usage: volctl up|down|mute|br-up|br-down" >&2
        exit 2
        ;;
    esac
  '';

  # Pressing Escape during the region select is not an error, it is how you
  # change your mind — and it was the common path through this script. slurp
  # exits non-zero and prints nothing, the unguarded command substitution then
  # ran `grim -g "" "$FILE"`, and grim failed with a geometry parse error into a
  # session with no terminal attached to see it. Worse, `mkdir -p` had already
  # made ~/Pictures/Screenshots, so a cancelled screenshot left a directory
  # behind on a machine that had never taken one.
  #
  # Take the region first, and only touch the disk once there is something to
  # write.
  screenshot = pkgs.writeShellScriptBin "screenshot-edit" ''
    GEOM=$(${pkgs.slurp}/bin/slurp) || exit 0   # cancelled — not a failure
    [ -n "$GEOM" ] || exit 0

    FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
    mkdir -p "$(dirname "$FILE")"
    if ${pkgs.grim}/bin/grim -g "$GEOM" "$FILE"; then
      ${pkgs.swappy}/bin/swappy -f "$FILE"
    else
      ${pkgs.libnotify}/bin/notify-send "screenshot-edit" "grim failed to capture the region"
      exit 1
    fi
  '';

  # ── niri focuses windows by id, and only by id ───────────────────────────
  #
  # Both toggles below used to call
  #
  #     niri msg action focus-window --app-id "$ID"      (this one)
  #     niri msg action focus-window --title "$NAME"     (toggleEmacs)
  #
  # and `niri msg action focus-window --help` is four lines long:
  #
  #     Usage: niri msg action focus-window --id <ID>
  #       --id <ID>  Id of the window to focus
  #
  # There is no `--app-id` and no `--title`. clap exits 2 on the unknown flag,
  # so under niri both scratchpad keys were dead in the one state they exist
  # for: the *first* press matched no window and spawned one correctly, and
  # every press after that took the branch that found the window and then
  # failed to focus it. So the scratchpad opened once and the key did nothing
  # ever again — and because the spawn branch is the one that works, it looked
  # like the toggle simply had no hide half rather than like an error.
  #
  # The id is already in the JSON that the existence check parses, so asking
  # jq for it instead of `-e` costs nothing and is the flag niri does have.
  # Hyprland's `focuswindow` genuinely does take `class:`/`title:` selectors,
  # so that branch was right and is unchanged.
  toggleTerm = pkgs.writeShellScriptBin "toggle-scratchpad-terminal" ''
    ${compositorDetect}
    ID="scratchpad"
    if [ "$COMPOSITOR" = "niri" ]; then
      WIN=$(niri msg --json windows |
        ${pkgs.jq}/bin/jq -r --arg id "$ID" 'map(select(.app_id == $id))[0].id // empty')
      if [ -n "$WIN" ]; then
        niri msg action focus-window --id "$WIN"
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
    ${emacsclient} -c -a "" -e "(progn
      (unless (seq-find (lambda (f) (string= (frame-parameter f 'name) \"$NAME\")) (frame-list))
        (make-frame '((name . \"$NAME\") (width . 110) (height . 30))))
      (select-frame-by-name \"$NAME\"))"
    sleep 0.2
    if [ "$COMPOSITOR" = "niri" ]; then
      # By id, for the reason spelled out above toggleTerm: niri's
      # focus-window takes --id and nothing else. The frame's Wayland title is
      # the frame name Emacs was just told to use.
      WIN=$(niri msg --json windows |
        ${pkgs.jq}/bin/jq -r --arg t "$NAME" 'map(select(.title != null and (.title | contains($t))))[0].id // empty')
      [ -n "$WIN" ] && niri msg action focus-window --id "$WIN"
    elif [ "$COMPOSITOR" = "hyprland" ]; then
      hyprctl dispatch focuswindow "title:$NAME"
    fi
  '';

in
{
  # `power-search` used to live here: writeShellScriptBin "power-search"
  # "exec fsearch", a script whose entire body renamed a binary. That is only
  # worth doing if the thing invoking it cannot name the real program, and the
  # only caller was a keybinding. modules/home/keys.nix names fsearch.
  home.packages = [
    spotlight
    teleport
    swallow
    volctl
    screenshot
    toggleTerm
    toggleEmacs
  ];
}
