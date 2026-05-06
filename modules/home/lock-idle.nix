{ pkgs, lib, config, ... }:

let
  bg = "#1a1b26";
  blue = "#7aa2f7";
in {
  home.packages = with pkgs; [ hyprlock hypridle ];

  # Hyprlock: The Screen Locker
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

  # Hypridle: The Idle Manager (Req 8.1)
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on || niri msg action power-on-monitors";
      };

      listener = [
        {
          # 300s: Reduce brightness to 10%
          timeout = 300;
          on-timeout = "brightnessctl set 10%";
          on-resume = "brightnessctl set 100%";
        }
        {
          # 420s: Lock screen
          timeout = 420;
          on-timeout = "loginctl lock-session";
        }
        {
          # 600s: Turn off monitors
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off || niri msg action power-off-monitors";
          on-resume = "hyprctl dispatch dpms on || niri msg action power-on-monitors";
        }
      ];
    };
  };
}
