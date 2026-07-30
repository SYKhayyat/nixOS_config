{ pkgs, lib, config, ... }:

let
  inherit (import ./palette.nix) bg blue;
in {
  home.packages = with pkgs; [ hyprlock hypridle ];

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

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = 300
        on-timeout = brightnessctl set 10%
        on-resume = brightnessctl set 100%
    }

    listener {
        timeout = 420
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 600
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
  '';

  # No systemd service here; hypridle is started via exec-once in Hyprland.
}
