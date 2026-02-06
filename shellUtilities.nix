# my-packages.nix
{ config, lib, pkgs, ... }:
{ 
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    # Tools:
    git # Version Control.
    wget # Download from url.
    htop # Task manager.
    pandoc # Document conversion.
    fdupes # Duplicate finder.
    nh # Nix Helper.
    ncdu # Visualizer.pay-respect 
    yai # Terminal AI.
    # File Managers:
    yazi # terminal file manager.
    yaziPlugins.sudo # Sudo in yazi.
    mc # Midnight Commander.
    # Editors.
    vim # The other editor.
    neovim # Modern vim.
    helix # Modal text editor.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];
  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}

