# modules/home/palette.nix
#
# The theme, derived rather than copied.
#
# ── The two sources of truth ──────────────────────────────────────────────
#
# This file used to be five hex literals, with a comment that admitted exactly
# what they were: "These mirror the Stylix base16 scheme (tokyo-night-dark) …
# To re-theme, change the scheme in modules/system/core.nix and update these
# five values." That is one theme with two definitions, and the second only
# updates if you remember it exists. Change `stylix.base16Scheme` and every
# riced surface — the bar, the lock screen, both compositors' borders — keeps
# the old colours. Silently, because nothing connects them.
#
# There is one definition now: `config.lib.stylix.colors`, which stylix
# computes from the scheme named in modules/system/appearance.nix. (That file
# was core.nix when this comment was first written, and the move is the point:
# the theme is a question, and it now has a file rather than a corner.)
#
# ── The half nobody was watching: format ──────────────────────────────────
#
# Copying a colour by hand is two jobs, and only the first one is obvious. The
# same `#7aa2f7` has to be spelled three ways here — CSS for waybar, a quoted
# CSS-ish string for niri's KDL, and hyprlang's own function syntax for
# hyprland.conf and hyprlock.conf — and the hand-copy got the third one wrong:
#
#     outer_color = rgb(#7aa2f7)
#
# hyprlang's `rgb()` takes six *bare* hex characters. The `#` makes seven, it
# fails the length check, and hyprlang returns "rgb() expects length of 6
# characters (3 bytes) or 3 comma separated values". All four coloured lines in
# hyprlock.conf were parse errors: the password field's outline, its fill, its
# text and the clock have never been themed at all. Nobody noticed because a
# lock screen that falls back to defaults still locks.
#
# So the palette hands out values that are *already in the target syntax*, and
# no module downstream ever writes a colour or wraps one in a function again.
# Getting the format wrong is now a thing you do once, here, in front of a
# comment explaining the format — not a thing you do silently in a heredoc.
{ config, lib, ... }:

let
  # base16.nix exposes both `baseXX` (bare) and `withHashtag.baseXX`. Take the
  # hashed set as the source and strip when a syntax wants it bare, so which of
  # the two carries the `#` is not a fact this file has to be right about.
  hashed = config.lib.stylix.colors.withHashtag;
  bare = base: lib.removePrefix "#" hashed.${base};

  # The roles anything riced in this repo actually asks for. The old file had a
  # fifth literal, `magenta`, with zero call sites in the whole tree — the same
  # thing the Lamdan report says about `unstable` and the `lxqt` branches: a
  # knob nothing turns was never a requirement.
  roles = {
    bg = "base00"; # bar and lock-screen background
    dim = "base03"; # inactive border, unfocused workspace
    fg = "base05"; # foreground text
    accent = "base0D"; # active border, focused workspace, lock field
  };
in
{
  options.shaulos.palette = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = ''
      The stylix base16 scheme, pre-rendered into the syntaxes this config's
      riced surfaces need, plus the stylix font set.

      `css`  — `#rrggbb`. CSS (waybar) and niri's KDL, which take the same form.
      `hypr` — `rgb(rrggbb)`. hyprland.conf and hyprlock.conf. Already wrapped:
               interpolate it bare, do not put it inside another `rgb(…)`.
      `font` — `mono` / `sans` names and the `sizes` set, so a module writing a
               config file that names a font does not name it a second time.
      `cursor` — `name` / `size` / `package`, from `stylix.cursor`. Plasma, niri
               and Hyprland each need this in their own spelling and each used
               to guess: the size was 24, 24 and 12 respectively, and the only
               one that named a *theme* named `Breeze_Snow`, which Plasma 6
               renamed to `Breeze_Light` and therefore silently ignored.

      Read this; never hand-write a colour, a font name or a cursor in a
      consuming module. All three halves of that rule have been broken before,
      and the two that broke silently — the `rgb(#…)` parse error and the
      renamed cursor theme — are the reason the rule exists.
    '';
  };

  config.shaulos.palette = {
    css = lib.mapAttrs (_role: base: hashed.${base}) roles;
    hypr = lib.mapAttrs (_role: base: "rgb(${bare base})") roles;

    font = {
      mono = config.stylix.fonts.monospace.name;
      sans = config.stylix.fonts.sansSerif.name;
      inherit (config.stylix.fonts) sizes;
    };

    # `stylix.cursor` is set in ../system/appearance.nix and copied into
    # home-manager by stylix's own integration, so this is the same value the
    # system saw — not a home-side restatement of it.
    cursor = {
      inherit (config.stylix.cursor) name size package;
    };
  };
}
