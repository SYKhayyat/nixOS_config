# modules/system/niri.nix
{ pkgs, ... }: {
  programs.niri.enable = true;
  programs.uwsm.enable = true;

  # Define Niri as a valid UWSM compositor
  programs.uwsm.waylandCompositors.niri = {
    prettyName = "Niri";
    comment = "Scrollable tiling compositor";
    binPath = "${pkgs.niri}/bin/niri";
  };

  # Hardware Access & Power
  # Fix: programs.light is deprecated/removed. Using acpilight.
  hardware.acpilight.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;

  # Authentication & Secrets
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;

  # Required for gnome-keyring/GTK to show password prompts over D-Bus
  services.dbus.packages = [ pkgs.gcr ];

  # PAM integration to unlock gnome-keyring at login
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
