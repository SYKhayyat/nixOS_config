{ config, lib, pkgs, myConfig, ... }:

{
   nix.extraOptions = "!include /etc/nix/tokens.conf";

  hardware.graphics = {
  enable = true;
};

  programs.zsh.enable = true;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = myConfig.hostname;
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 1714 1764 ];
    allowedUDPPorts = [ 1714 1764 ];
  };

  time.timeZone = myConfig.timezone;
  i18n.defaultLocale = myConfig.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = myConfig.locale;
    LC_IDENTIFICATION = myConfig.locale;
    LC_MEASUREMENT = myConfig.locale;
    LC_MONETARY = myConfig.locale;
    LC_NAME = myConfig.locale;
    LC_NUMERIC = myConfig.locale;
    LC_PAPER = myConfig.locale;
    LC_TELEPHONE = myConfig.locale;
    LC_TIME = myConfig.locale;
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" myConfig.username ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  system.nixos.label = "ShaulOS";
  system.nixos.version = "current";

  security.rtkit.enable = true;
  security.polkit.enable = true;
  services.openssh.enable = true;
  services.dbus.enable = true;

  security.pam.services.hyprlock = {};

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.sessionVariables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    QT_SCALE_FACTOR = "1";
    QT_WAYLAND_RECONNECT = "1";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    GDK_SCALE = "1";
    GDK_DPI_SCALE = "1";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=1";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XCURSOR_SIZE = "24";
  };

  qt = {
    enable = lib.mkForce true;
    platformTheme = "kde";
    style = "breeze";
  };

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    image = ../../wallpaper.jpg;
    polarity = "dark";
    fonts = {
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
      sansSerif = { package = pkgs.noto-fonts; name = "Noto Sans"; };
      serif = { package = pkgs.noto-fonts; name = "Noto Serif"; };
      emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
    };
    targets.gtk.enable = true;
  };

  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    shell = pkgs.zsh;
  };

  system.stateVersion = "25.11";
}
