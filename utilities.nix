# my-packages.nix
{ config, lib, pkgs, ... }:
{ 
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    persepolis # A download manager.
    peazip # Archive file manager.
    onedriver # OneDrive manager.
    tor-browser # The Tor Browser.
    zenity # Needed for Otzaria.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];
  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}

