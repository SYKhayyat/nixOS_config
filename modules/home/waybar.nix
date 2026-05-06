{ pkgs, config, lib, ... }:

let
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  magenta = "#bb9af7";
  gray = "#414868";
in {
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      margin = "8 12 0 12";

      modules-left = [ "niri/window" "hyprland/window" ];
      modules-center = [ "niri/workspaces" "hyprland/workspaces" ];
      modules-right = [ "tray" "pulseaudio" "network" "battery" "clock" ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = { default = "○"; focused = "●"; };
      };
      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
      };
      "niri/window" = { format = "󰖲 {title}"; max-length = 30; };
      "hyprland/window" = { format = "󰖲 {title}"; max-length = 30; };

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
      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
      tray = { spacing = 10; };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew", "Font Awesome 6 Free";
        font-size: 12px;
        border: none;
      }
      window#waybar { background: transparent; }
      #window, #workspaces, #network, #pulseaudio, #battery, #clock, #tray {
        background: ${bg};
        color: ${fg};
        padding: 2px 12px;
        margin: 0 4px;
        border-radius: 10px;
        border: 1px solid ${gray};
      }
      #workspaces button { color: ${gray}; padding: 0 4px; }
      #workspaces button.focused { color: ${blue}; }
      #workspaces button.active { color: ${blue}; }
    '';
  };
}
