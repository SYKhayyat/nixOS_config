# modules/home/niri/default.nix
{ pkgs, config, lib, ... }: {
  imports = [ ../yazi.nix ];

  home.packages = with pkgs; [
    foot            # Ultra-fast terminal
    fuzzel          # Minimal C-based launcher
    waybar          # Top bar
    mako            # Light notifications
    swww            # GPU-accelerated wallpaper
    wlogout         # Wayland power menu
    avizo           # Volume/Brightness OSD
    networkmanagerapplet
    blueman
    grim            # Screenshots
    slurp           # Region selector
  ];

  # Niri Configuration (KDL format)
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard { xkb { layout "us"; } }
        touchpad { tap; natural-scroll; }
        mouse { natural-scroll; }
    }

    output "eDP-1" { scale 1.0; }

    layout {
        gap 12
        center-focused-column "never"
        default-column-width { proportion 0.5; }
    }

    // Performance start-up
    spawn-at-startup "waybar"
    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "nm-applet"
    spawn-at-startup "avizo-service"

    binds {
        // App Launcher & Terminal
        Mod+Return { spawn "foot"; }
        Mod+D { spawn "fuzzel"; }
        
        // File Managers
        Mod+E { spawn "foot" "yazi"; }       // Quick terminal FM
        Mod+Shift+E { spawn "dolphin"; }     // Full GUI FM
        
        // Session
        Mod+Shift+Q { spawn "wlogout"; }
        
        // Ribbon Navigation (Infinite Scroll)
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+L     { focus-column-right; }
        
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+C { close-window; }
        
        // Media Keys (via avizo/light)
        XF86AudioRaiseVolume { spawn "volumectl" "-u" "up"; }
        XF86AudioLowerVolume { spawn "volumectl" "-u" "down"; }
        XF86AudioMute        { spawn "volumectl" "toggle-mute"; }
        XF86MonBrightnessUp   { spawn "lightctl" "up"; }
        XF86MonBrightnessDown { spawn "lightctl" "down"; }

        // Screenshots
        Print { spawn "grim" "-g" "$(slurp)" "-t" "png" "- | wl-copy"; }
    }
  '';

  # Modern Waybar Styling
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 34;
      modules-left = [ "niri/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "network" "cpu" "memory" "tray" ];
      network = { format-wifi = "  {essid}"; format-ethernet = "󰈀"; };
      cpu = { format = "  {usage}%"; };
      memory = { format = "  {percentage}%"; };
    }];
    style = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; font-weight: bold; }
      window#waybar { background: rgba(20, 20, 30, 0.9); color: #ffffff; border-bottom: 2px solid #333; }
      #workspaces button { color: #888; }
      #workspaces button.focused { color: #fff; }
    '';
  };
}
