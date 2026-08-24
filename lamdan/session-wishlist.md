# Session wishlist

Ideas for greeter entries, not commitments. Nothing here is broken; these are
the "for fun" options discussed on 2026-08-23.

## COSMIC (System76) — DONE

Added 2026-08-23 as ../../modules/system/cosmic.nix: desktop-manager half
only, so SDDM lists `cosmic-session` without a second display manager.
XWayland left at upstream default (off).

## LatticeWM — blocked on packaging

Session plumbing needed on this side (~an afternoon):

- modules/system/latticewm.nix: session entry running river with
  `-c latticewm`, optional uwsm registration, wlr portal registration
- waybar: river/* module variant alongside hyprland/* and niri/*
- scripts.nix compositorDetect: teach it about river (RIVER_STATUS env or
  pgrep fallback)
- verify hyprlock/hypridle work against river (protocol-generic, likely fine)

Blocked on making the build sandbox-safe first: bootstrap.sh fetches Lisp deps
from Quicklisp at build time. Options: fixed-output derivation for the dep
fetch, vendoring, or nixpkgs lispPackages.

## Rejected

- Sway — third i3-style tiler, nothing new to notice
- Labwc / Wayfire — stacking/3D ricing; Plasma already covers floating
- River bare — interesting only as a LatticeWM contrast demo
