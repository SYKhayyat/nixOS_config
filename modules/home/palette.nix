# modules/home/palette.nix
#
# Single source of truth for the accent colors used by the ricing modules
# (waybar, hyprlock, niri, hyprland). These mirror the Stylix base16 scheme
# (tokyo-night-dark) so the ricing matches the system theme:
#
#   base00 bg | base03 gray | base05 fg | base0D blue | base0E magenta
#
# Kept as literals so every module evaluates without reaching into Stylix
# internals. To re-theme, change the scheme in modules/system/core.nix and
# update these five values (or later wire them to config.lib.stylix.colors).
rec {
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  magenta = "#bb9af7";
  gray = "#414868";

  # Hyprland wants 0xAARRGGBB (opaque) rather than #RRGGBB.
  hypr = {
    blue = "0xff7aa2f7";
    gray = "0xff414868";
  };
}
