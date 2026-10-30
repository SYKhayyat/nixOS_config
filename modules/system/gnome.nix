# modules/system/gnome.nix
#
# The second full desktop environment, and the one with a genuinely different
# paradigm from Plasma: mutter instead of KWin, GTK4 instead of Qt, gestures
# instead of panels. You asked for it as the thing to compare the others
# against, and that is what it is for.
#
# Like Plasma (../desktop.nix), this registers SDDM entries — `gnome` and
# `gnome-xorg` — and does NOT bring its own display manager. GDM only starts
# if you write `services.displayManager.gdm.enable = true`, which this file
# deliberately does not. One greeter, five sessions, which is the shape this
# machine already has.
#
# What the module does pull in, unavoidably, is the GNOME service stack:
# accounts-daemon, gvfs, upower, gnome-keyring, and the tracker indexer.
# The first four are already enabled for the compositor sessions by
# ./wayland.nix, so GNOME costs one *new* daemon, and it is named and turned
# off below.
{ pkgs, ... }:

{
  services.desktopManager.gnome.enable = true;

  # GNOME games: off. It is already `mkDefault false`, so this line states a
  # decision rather than changing one — and it is here so that the day
  # upstream flips the default, the machine does not get mahjongg.
  services.gnome.games.enable = false;

  # Tracker — GNOME's indexer, and the same decision Plasma already made in
  # ../home/shaul.nix (baloofilerc `Indexing-Enabled = false`) for the same
  # reason: an indexer that walks $HOME and rebuilds a multi-gigabyte cache
  # nobody asked for, on a default of `mkDefault true`. One line is the whole
  # shutdown, exactly as it is for Baloo.
  services.gnome.tinysparql.enable = false;

  # Core apps stay, minus weather. `excludePackages` subtracts by package
  # name from every GNOME list the module builds, which is the one
  # subtraction mechanism it offers — and weather was the one you named.
  environment.gnome.excludePackages = [ pkgs.gnome-weather ];
}
