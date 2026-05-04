# modules/system/hyprland.nix
{ pkgs, ... }: {
  programs.hyprland.enable = true;
  programs.uwsm.enable = true;

  programs.uwsm.waylandCompositors.hyprland = {
    prettyName = "Hyprland";
    comment = "Dynamic tiling compositor";
    binPath = "${pkgs.hyprland}/bin/Hyprland";
  };

  # Hardware Access & Power
  # Fix: programs.light is deprecated/removed. Using acpilight.
  hardware.acpilight.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;

  # Authentication & Secrets
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  services.dbus.packages = [ pkgs.gcr ];

  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    wayland-utils
    wl-clipboard
    libsecret
    polkit_gnome
    networkmanagerapplet
  ];

  fonts.fontconfig.enable = true;
}
