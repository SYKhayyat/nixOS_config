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
# from the stylix scheme rather than restating it. The font size now comes from
# there too.
#
# It used to be `font-size: 12px`, under a comment claiming it was a deliberate
# exception — that `stylix.fonts.sizes.desktop` was 9 but the bar needed 12 for
# the Nerd Font glyphs in the module formats. That was not an exception, it was
# a unit conversion nobody had done: CSS fixes 4 pixels to every 3 points, so
# 9pt *is* 12px, and the literal was the derived value written in the other unit
# and then pinned by hand. It said "deliberate" and rendered "identical", which
# is the most expensive kind of hardcode — the bar was the one surface that
# would not have followed when the desktop size changed, and it would have
# looked like a decision rather than a leak.
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
        font-size: ${toString (font.sizes.desktop * 4 / 3)}px;
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
