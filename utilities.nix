# my-packages.nix
{ config, lib, pkgs, ... }:
{ 
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    persepolis # A download manager.
    peazip # Archive file manager.
    onedriver # OneDrive manager.
    git # Version Control.
    wget # Download from url.
    htop # Task manager.
    pandoc # Document conversion.
    fdupes # Duplicate finder.
    tor-browser # The Tor Browser.
    zenity # Needed for Otzaria.
    nh # Nix Helper.
    ncdu # Visualizer.
    yazi # terminal file manager.
    yaziPlugins.sudo # Sudo in yazi.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];
  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}

