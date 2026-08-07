# modules/home/foot.nix
#
# The terminal every session binds to Mod+Return. One line, and it used to be
# three.
#
# Stylix's foot target already writes
#
#     font = ${fonts.monospace.name}:size=${toString fonts.sizes.terminal}
#
# along with the full base16 colour table. This file answered that with
# `lib.mkForce "JetBrainsMono Nerd Font:size=10"` — a hand-copy of the font
# stylix had just derived from the scheme, wrapped in the one operator
# guaranteed to win, and carrying a size that lived nowhere near the three other
# font sizes in home/shaul.nix.
#
# The size moved there, to `stylix.fonts.sizes.terminal`, which is where sizes
# are stated. Same rendered value; one place that decides it.
_:

{
  programs.foot.enable = true;
}
