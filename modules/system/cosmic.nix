# modules/system/cosmic.nix
#
# The fourth greeter entry: System76's Rust desktop, for fun and for a
# scrolling-tiling paradigm that is niri's closest cousin with a full DE
# around it.
#
# Only the desktop manager half is enabled. `services.displayManager.
# cosmic-greeter.enable` would install COSMIC's own greetd-based greeter as a
# SECOND display manager next to SDDM — what we want is the session listed in
# the greeter we already have, which `services.desktopManager.cosmic` does by
# registering `cosmic-session` in `services.displayManager.sessionPackages`.
#
# XWayland stays at its upstream default (off); turn it on here if some X-only
# app ever matters inside this session — every other session on this machine
# gets its XWayland from its own compositor module.
_:

{
  services.desktopManager.cosmic.enable = true;
}
