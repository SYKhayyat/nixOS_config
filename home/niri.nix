{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ./common.nix                                              # zsh, p10k, git, aliases, scripts
    (import ../modules/home/wayland-common.nix { xdgDesktop = "niri"; })
    ../modules/home/emacs
    ../modules/home/niri                                      # launches waybar/mako/udiskie/swww itself
  ];

  # Niri uses a smaller cursor than the default in common.
  home.sessionVariables.XCURSOR_SIZE = "12";
}
