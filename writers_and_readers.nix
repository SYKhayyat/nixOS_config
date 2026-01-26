# my-packages.nix
{ config, lib, pkgs, ... }:
{
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    ((emacsPackagesFor emacs-pgtk).emacsWithPackages (epkgs: [
     ])) # THE text editor.
    vim # The other text editor.
    neovim # A modern clone of vim.
    helix # A modern text editor.
    libreoffice-qt-fresh # FOSS office suite
    kdePackages.calligra # KDE's office suite.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
