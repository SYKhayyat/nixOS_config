# modules/home/lock.nix
#
# One locker and one idle daemon, for every Wayland session on this machine.
#
# This replaces lock-idle.nix (hyprlock + a full hypridle config, Hyprland only)
# and lock-niri.nix, which was three lines that installed swaylock and nothing
# else. So: **the niri session never locked itself.** No idle daemon, no
# timeout, no DPMS — a difference you would only discover by walking away from
# the machine. Reachable through wlogout, so not dead code, just silently
# absent.
#
# And the Hyprland half did not work either. lock-idle.nix signed off with
# "hypridle is started via exec-once in Hyprland" and hyprland.conf has no such
# line. Both sessions shipped an idle configuration that nothing ran.
#
# hyprlock speaks ext-session-lock-v1 and hypridle speaks ext-idle-notify-v1;
# niri implements both, so one pair covers both compositors and swaylock is
# gone. Startup is now explicit in each compositor's config.
{ pkgs, ... }:

let
  inherit (import ./palette.nix) bg blue;

  # The one verb hypridle cannot express portably. This is the case runtime
  # detection is genuinely right for — one closure, several possible
  # compositors, and the answer only exists at the moment the timer fires.
  # `|| true` because a missing action must not wedge the idle daemon: failing
  # to blank the panel is a nuisance, an idle daemon that dies is a machine
  # that never locks again.
  sessionDpms = pkgs.writeShellScriptBin "session-dpms" ''
    case "''${1:-}" in
      on | off) ;;
      *)
        echo "usage: session-dpms on|off" >&2
        exit 2
        ;;
    esac

    if ${pkgs.procps}/bin/pgrep -x niri > /dev/null; then
      niri msg action "power-$1-monitors" || true
    elif ${pkgs.procps}/bin/pgrep -x Hyprland > /dev/null; then
      hyprctl dispatch dpms "$1" || true
    fi
  '';
in
{
  home.packages = [
    pkgs.hyprlock
    pkgs.hypridle
    sessionDpms
  ];

  # wlogout's stock layout hardcodes `swaylock`, which was installed in exactly
  # one of the two sessions — so the power menu's lock button did nothing under
  # Hyprland. Name the locker we actually ship. (No `style`, so wlogout keeps
  # its packaged CSS and icon paths.)
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "${pkgs.hyprlock}/bin/hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "loginctl terminate-user $USER";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];
  };

  xdg.configFile."hypr/hyprlock.conf".text = ''
    background {
        monitor =
        path = screenshot
        blur_passes = 3
        blur_size = 7
    }

    input-field {
        monitor =
        size = 200, 50
        outline_thickness = 3
        dots_size = 0.33
        dots_spacing = 0.15
        dots_center = true
        outer_color = rgb(${blue})
        inner_color = rgb(${bg})
        font_color = rgb(${blue})
        fade_on_empty = true
        placeholder_text = <i>Password...</i>
        hide_input = false
        position = 0, -20
        halign = center
        valign = center
    }

    label {
        monitor =
        text = $TIME
        color = rgb(${blue})
        font_size = 64
        font_family = JetBrainsMono Nerd Font
        position = 0, 80
        halign = center
        valign = center
    }
  '';

  # Dim at 5 min, lock at 7, panel off at 10. Started by both compositors.
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = ${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = ${sessionDpms}/bin/session-dpms on
    }

    listener {
        timeout = 300
        on-timeout = ${pkgs.brightnessctl}/bin/brightnessctl set 10%
        on-resume = ${pkgs.brightnessctl}/bin/brightnessctl set 100%
    }

    listener {
        timeout = 420
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 600
        on-timeout = ${sessionDpms}/bin/session-dpms off
        on-resume = ${sessionDpms}/bin/session-dpms on
    }
  '';
}
