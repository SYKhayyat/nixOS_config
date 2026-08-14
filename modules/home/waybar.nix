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
        /*
          `* 4.0 / 3`, and the `.0` is the whole fix. Nix `/` on two integers
          is INTEGER division, so this read `* 4 / 3` and truncated:

            8 * 4 / 3   -> 10        what waybar got
            8 * 4.0 / 3 -> 10.6667   8pt at 96 DPI, what everything else got

          — waybar rendering ~6% under every other surface derived from
          `uiSize`. The reason nobody saw it is worth keeping: this formula
          arrived in the commit that fixed waybar's hardcoded `font-size: 12px`,
          and at that moment `uiSize` was 9, where `9 * 4 / 3` is exactly 12 —
          README.md's own worked example, "9pt is 12px at 96 DPI". The
          truncation only appeared one commit later when `uiSize` dropped to 8.

          A formula that is correct for one input is not a derivation, it is a
          coincidence with a variable in it.

          And there is an independent check on the fixed value sitting in this
          same file, which is what makes it more than arithmetic. stylix emits
          its own block above everything here:

            * { font-family: "JetBrainsMono Nerd Font"; font-size: 8pt; }

          8pt at 96 DPI IS 10.667px. Two derivations that never consult each
          other — stylix's, from `fonts.sizes.desktop` in points, and this one,
          converting to pixels because that is what waybar's CSS wants — now
          agree to the digit. Before the `.0`, this rule came later in the
          cascade and quietly overrode stylix's correct 8pt with a truncated
          10px, which is the whole bug in one sentence.
        */
        font-size: ${toString (font.sizes.desktop * 4.0 / 3)}px;
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
