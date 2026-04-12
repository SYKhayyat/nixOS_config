# modules/system/niri.nix
# modules/system/niri.nix
{ pkgs, ... }: {
  programs.niri.enable = true;
  programs.uwsm.enable = true;

  # Hardware Access & Power
  programs.light.enable = true; # Enables brightness control hardware access
  services.udisks2.enable = true; # Enables disk mounting permissions
  services.upower.enable = true;  # Enables battery sensing

  # Authentication & Secrets
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  
  # polkit agent startup is handled in the Home Manager Niri config

  environment.systemPackages = with pkgs; [
    wayland-utils
    wl-clipboard
    libsecret
    polkit_gnome # The GUI popup for passwords
  ];

  # Ensure Hebrew and other fonts are available to Wayland apps
  fonts.fontconfig.enable = true;
}
