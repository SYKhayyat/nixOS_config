{ config, lib, pkgs, myConfig, ... }:

{
  imports = [
    ../modules/home/emacs
    ../modules/home/hyprland
    ../modules/home/scripts.nix
  ];

  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── Session variables ───────────────────────────────────────
  systemd.user.sessionVariables = {
    WAYLAND_DISPLAY = "wayland-1";
    XDG_CURRENT_DESKTOP = "hyprland";
  };

  # ── Services (Waybar, mako, udiskie) ───────────────────────
  programs.waybar.enable = true;
  systemd.user.services.waybar.Install.WantedBy = [ "hyprland-session.target" ];

  services.mako.enable = true;
  systemd.user.services.mako.Install.WantedBy = [ "hyprland-session.target" ];

  services.udiskie.enable = true;
  systemd.user.services.udiskie.Install.WantedBy = [ "hyprland-session.target" ];

  # ── Force browsers OFF (overrides base desktop config) ──────
  programs.firefox.enable = lib.mkForce false;

  # ── Minimal study packages ──────────────────────────────────
  home.packages = lib.mkForce (with pkgs; [
    git
    ripgrep
    fd
    fzf
    ytfzf
    yt-dlp
    mpv
    foot
    yazi
    kdePackages.kate
    kdePackages.okular
    kdePackages.dolphin
    libreoffice-qt-fresh
    wl-clipboard
    wlogout
    udiskie
    networkmanagerapplet
    cliphist
    pamixer
    brightnessctl
    grim
    slurp
    swappy
    libnotify
    kdePackages.ksshaskpass
    pandoc
  ]);

  # ── Sudo password prompt fix ────────────────────────────────
  home.sessionVariables = {
    SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  programs.ssh.enable = true;
  programs.ssh.enableDefaultConfig = false;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        email = "shaul@example.com";
      };
    };
  };

  fonts.fontconfig.enable = true;
}
