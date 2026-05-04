# modules/home/hyprland/default.nix
{ config, lib, pkgs, ... }:

let
  bg = "#1a1b26";
  fg = "#c0caf5";
  blue = "#7aa2f7";
  wallpaper = toString ./../../../wallpaper.jpg;
in {
  imports = [ ../yazi.nix ../waybar.nix ];

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    foot
    fuzzel
    waybar
    mako
    awww
    wlogout
    avizo
    grim
    slurp
    wl-clipboard
    cliphist
    playerctl
    udiskie
    pavucontrol
    swappy
    networkmanagerapplet
    polkit_gnome
    libsecret
    fd
    fzf
    jq
    hyprpaper
    hyprpicker
    font-awesome
  ];

  services.gnome-keyring.enable = true;

  services.mako = {
    enable = true;
    settings = lib.mkForce {
      background-color = "${bg}";
      text-color = "${fg}";
      border-color = "${blue}";
      border-size = 2;
      border-radius = 12;
      default-timeout = 5000;
      font = "JetBrainsMono Nerd Font 10";
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = lib.mkForce {
      main = {
        font = "JetBrainsMono Nerd Font:size=13";
        terminal = "xdg-terminal-exec";
        prompt = "'󰍉 '";
      };
      colors = {
        background = "1a1b26ff";
        text = "c0caf5ff";
        match = "7aa2f7ff";
        selection = "414868ff";
        selection-text = "c0caf5ff";
        border = "7aa2f7ff";
      };
      border = { width = 2; radius = 10; };
    };
  };

  xdg.configFile."hypr/hyprland.conf".text = ''
    monitor = eDP-1,preferred,auto,1

    exec-once = waybar
    exec-once = mako
    exec-once = awww-daemon
    exec-once = nm-applet --indicator
    exec-once = udiskie --tray
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    exec-once = wl-paste --watch cliphist store
    exec-once = uwsm finalize

    input {
        kb_layout = us,il
        kb_options = grp:alt_shift_toggle,caps:escape
        repeat_delay = 250
        repeat_rate = 40
        touchpad {
            natural_scroll = true
            tap-to-click = true
        }
    }

    general {
        gaps_in = 8
        gaps_out = 16
        border_size = 2
        col.active_border = ${blue}
        col.inactive_border = 0x414868
        layout = master
    }

    decoration {
        rounding = 10
        blur {
            enabled = true
            size = 5
            passes = 2
        }
    }

    animations {
        enabled = true
        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        animation = windows, 1, 7, myBezier
        animation = border, 1, 10, default
        animation = fade, 1, 7, default
        animation = workspaces, 1, 6, default
    }

    windowrulev2 = float, class:(pavucontrol)
    windowrulev2 = float, class:(nm-connection-editor)
    windowrulev2 = float, title:(scratchterm)
    windowrulev2 = float, title:(emacs-scratch)
    windowrulev2 = size 1100 800, title:(scratchterm)
    windowrulev2 = center, title:(scratchterm)
    windowrulev2 = center, title:(emacs-scratch)

    $mainMod = SUPER

    bind = $mainMod, Return, exec, xdg-terminal-exec
    bind = $mainMod, D, exec, fuzzel
    bind = $mainMod, N, exec, nm-connection-editor
    bind = $mainMod, V, exec, bash -c "cliphist list | fuzzel -d | cliphist decode | wl-copy"
    bind = $mainMod SHIFT, C, killactive
    bind = $mainMod SHIFT, Q, exec, wlogout

    bind = $mainMod, Space, exec, power-search
    bind = $mainMod, T, exec, teleport
    bind = $mainMod ALT, S, exec, spotlight

    bind = $mainMod, grave, exec, toggle-scratchpad-terminal
    bind = $mainMod SHIFT, grave, exec, toggle-scratchpad-emacs

    bind = $mainMod, H, movefocus, l
    bind = $mainMod, L, movefocus, r
    bind = $mainMod, K, movefocus, u
    bind = $mainMod, J, movefocus, d
    bind = $mainMod SHIFT, H, movewindow, l
    bind = $mainMod SHIFT, L, movewindow, r
    bind = $mainMod SHIFT, K, movewindow, u
    bind = $mainMod SHIFT, J, movewindow, d

    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5

    bind = $mainMod, F, fullscreen
    bind = $mainMod SHIFT, F, togglefloating

    bind = , XF86AudioRaiseVolume, exec, volctl up
    bind = , XF86AudioLowerVolume, exec, volctl down
    bind = , XF86AudioMute, exec, volctl toggle-mute
    bind = , XF86MonBrightnessUp, exec, light -A 5
    bind = , XF86MonBrightnessDown, exec, light -U 5

    bind = , Print, exec, screenshot-edit
  '';

  systemd.user.services.awww-wallpaper = {
    Unit = {
      Description = "Set wallpaper on awww";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.awww}/bin/awww set ${wallpaper}";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
