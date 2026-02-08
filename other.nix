# my-packages.nix
{ config, lib, pkgs, ... }:
{
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    scribus # Publisher
    audacity # Recorder and audio editor.
    lmms # DAW
    ollama-cpu # Open source LLMs.
    # Add the packages you want to install
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
