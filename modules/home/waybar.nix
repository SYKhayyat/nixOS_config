# modules/home/waybar.nix
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
      modules-left = [ "hyprland/workspaces" ];  # or "niri/workspaces" depending on env, but waybar autodetects
      modules-center = [ "clock" ];
      modules-right = [ "tray" "pulseaudio" "network" "battery" ];

      "hyprland/workspaces" = {
        format = "{icon}";
        format-icons = {
          default = "○";
          focused = "●";
        };
      };
      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          default = "○";
          focused = "●";
        };
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
      clock = {
        format = "󰥔  {:%H:%M}";
      };
      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
      tray = {
        spacing = 10;
      };
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans Hebrew", "Font Awesome 6 Free";
        font-size: 13px;
        border: none;
      }
      window#waybar {
        background: transparent;
      }
      #workspaces, #network, #pulseaudio, #battery, #clock, #tray {
        background: ${bg};
        color: ${fg};
        padding: 4px 14px;
        margin: 0 4px;
        border-radius: 12px;
        border: 1px solid ${gray};
      }
      #workspaces button {
        color: ${gray};
        padding: 0 4px;
      }
      #workspaces button.focused {
        color: ${blue};
      }
    '';
  };
}
