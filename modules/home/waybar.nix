# modules/home/waybar.nix
#
# One bar config listing both compositors' modules. waybar loads the ones its
# compositor supports and ignores the rest — which used to be a shared config
# hedging about a fact its closure already knew, and is now simply correct: one
# closure serves all three sessions and the bar cannot know in advance which one
# started it.
#
# Not started here. Each compositor spawns waybar itself, so there is one place
# that says when the bar appears.
#
# Colours and the monospace family come from ./palette.nix, which derives them
# from the stylix scheme rather than restating it. The font *size* below stays a
# literal on purpose: `stylix.fonts.sizes.desktop` is 9 and this bar is 12px
# because of the Nerd Font glyphs in the module formats, not because anyone
# forgot to wire it. A deliberate exception, said out loud.
{ config, ... }:

let
  inherit (config.shaulos.palette) css font;
in
{
  imports = [ ./palette.nix ];

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        margin = "8 12 0 12";

        modules-left = [
          "niri/window"
          "hyprland/window"
        ];
        modules-center = [
          "niri/workspaces"
          "hyprland/workspaces"
        ];
        modules-right = [
          "tray"
          "pulseaudio"
          "network"
          "battery"
          "clock"
        ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            default = "○";
            focused = "●";
          };
        };
        "hyprland/workspaces" = {
          format = "{icon}";
          on-click = "activate";
        };
        "niri/window" = {
          format = "󰖲 {title}";
          max-length = 30;
        };
        "hyprland/window" = {
          format = "󰖲 {title}";
          max-length = 30;
        };

        network = {
          format-wifi = "󰤨  {essid}";
          format-disconnected = "󰤭  None";
          on-click = "nm-connection-editor";
        };
        pulseaudio = {
          format = "{icon} {volume}%";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          on-click = "pavucontrol";
        };
        clock = {
          format = "󰥔  {:%H:%M}";
        };
        battery = {
          format = "{icon} {capacity}%";
          format-icons = [
            "󰂎"
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };
        tray = {
          spacing = 10;
        };
      }
    ];

    style = ''
      * {
        font-family: "${font.mono}", "Noto Sans Hebrew", "Font Awesome 6 Free";
        font-size: 12px;
        border: none;
      }
      window#waybar { background: transparent; }
      #window, #workspaces, #network, #pulseaudio, #battery, #clock, #tray {
        background: ${css.bg};
        color: ${css.fg};
        padding: 2px 12px;
        margin: 0 4px;
        border-radius: 10px;
        border: 1px solid ${css.dim};
      }
      #workspaces button { color: ${css.dim}; padding: 0 4px; }
      #workspaces button.focused { color: ${css.accent}; }
      #workspaces button.active { color: ${css.accent}; }
    '';
  };
}
