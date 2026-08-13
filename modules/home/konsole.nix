# modules/home/konsole.nix
#
# The other terminal. The one actually in use, and the one this repo had never
# heard of.
#
# ── What was wrong ────────────────────────────────────────────────────────
#
# `grep -rni konsole` over the whole tree returned nothing. Not a package entry,
# not a font, not a colour — konsole appeared in no .nix file and in no line of
# the README. Meanwhile `pgrep` under the running Plasma session found konsole
# and did not find foot, and `~/.local/share/konsole/` was empty: no profile,
# no colour scheme, nothing on disk at all.
#
# So the terminal this machine is read in every day was running on whatever
# Konsole's built-in fallback profile resolves to, and the size of the text in
# it was not a fact this config stated. ../../modules/system/appearance.nix
# defines one `uiSize` and derives eight surfaces from it; this was a ninth,
# sitting outside the derivation, invisible because it happened to look close
# enough. When the sizes moved — 9pt to 8, terminals to 9 — every declared
# surface followed and this one did not, because there was nothing to follow
# with.
#
# That is the same shape as ./foot.nix's `mkForce "…:size=10"` and waybar's
# `font-size: 12px`, minus the literal: a hardcode you can at least grep for
# leaves a mark, and an undeclared program leaves none. This one was found by
# looking at `ps`, which is not a code review technique.
#
# ── The konsolerc trap, which is the kxkbrc bug again ─────────────────────
#
# `programs.plasma.overrideConfig = true` (../../home/shaul.nix) means
# plasma-manager owns ~/.config/plasma* outright and rewrites them on every
# activation. konsolerc is one of those files, and `[Desktop Entry]
# DefaultProfile` is the key that says which profile Konsole opens with.
#
# Which means picking a profile in Konsole's own settings dialog survives
# exactly until the next `just switch`, and then silently does not — the same
# failure the keyboard had, documented at length beside `input.keyboard` in
# ../../home/shaul.nix, where Plasma fell back to bare `us` after every rebuild
# because nothing declared a layout and `overrideConfig` reset the file anyway.
# A managed file with an unstated key is not "left alone", it is reverted.
#
# So the profile is declared and named as the default here. Set it by hand and
# it is gone next rebuild; set it here and it is the only statement of it.
{ config, ... }:

let
  inherit (config.shaulos.palette) font;
in
{
  imports = [ ./palette.nix ];

  programs.konsole = {
    enable = true;

    # plasma-manager writes ~/.local/share/konsole/shaul.profile and points
    # konsolerc's DefaultProfile at `shaul.profile`. The attribute name is what
    # the filename is built from, so these two are one name, not two.
    defaultProfile = "shaul";

    profiles.shaul = {
      # The same family and the same size foot gets — `stylix.fonts.sizes
      # .terminal`, which is `uiSize + 1`, because monospace reads smaller than
      # sans at equal points. Two terminals that disagree about how big text is
      # would be a worse bug than the one this file fixes, and would look like a
      # preference.
      font = {
        name = font.mono;
        size = font.sizes.terminal;
      };
    };
  };
}
