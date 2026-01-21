# /etc/nixos/configuration.nix
{ pkgs, lib, ... }:

let
  # Define your custom Emacs with packages
  myEmacs = pkgs.emacsWithPackages (epkgs: with epkgs; [
    # evil          # For modal editing
    # nix-mode      # For editing Nix files
    # Add other packages here, e.g., haskell-mode, org, etc.
  ]);
in
{
  services.emacs = {
    enable = true;         # Enable the Emacs daemon service
    # package = myEmacs;     # Use your customized Emacs package
    # defaultEditor = true;  # Optional: set as default editor
    startWithGraphical = true; # Uncomment if you want GUI frames
  };

  # Optional: Add system packages if needed
  environment.systemPackages = [ pkgs.emacs-pgtk ]; # For the basic emacs command

  # Configure system settings (e.g., for default editor)
  # ... other system config ...
}
