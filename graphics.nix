# my-packages.nix
{ config, lib, pkgs, ... }:
{
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
  gimp-with-plugins # Gnu Image Manipulation Program.
  gimpPlugins.gmic # Basic plugins.
  gimpPlugins.resynthesizer # GIMP plugin.
  gimpPlugins.lqrPlugin # GIMP plugin.
  krita # Painting application.
  krita-plugin-gmic # Basic plugins.
  inkscape-with-extensions # Another graphics program.
  rawtherapee # RAW editor.
  darktable # RAW editor.
  sly # Easy photo editor.
    # Add the packages you want to install
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
