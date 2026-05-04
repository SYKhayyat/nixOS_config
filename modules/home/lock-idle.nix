# modules/home/lock-idle.nix
{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  blue = "#7aa2f7";
in {
  home.packages = with pkgs; [
    hyprlock
    hypridle
  ];

  xdg.configFile."hypr/hyprlock.conf".text = ''
    background {
        monitor = eDP-1
        path = screenshot
        blur_passes = 3
        blur_size = 7
    }

    input-field {
        monitor = eDP-1
        size = 200, 50
        outline_thickness = 3
        dots_size = 0.2
        dots_spacing = 0.2
        dots_center = true
        outer_color = rgb(${blue})
        inner_color = rgb(${bg})
        font_color = rgb(${blue})
        fade_on_empty = false
        placeholder_text = <i>Password</i>
        hide_input = false
    }

    label {
        monitor = eDP-1
        text = cmd[update:1000] echo "$(date +"%H:%M")"
        color = rgb(${blue})
        font_size = 60
        position = 0, -200
        halign = center
        valign = center
    }
  '';

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "light -S 10";
          on-resume = "light -S 100";
        }
        {
          timeout = 420;
          on-timeout = "hyprlock";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
