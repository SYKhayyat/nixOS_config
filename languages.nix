# my-packages.nix
{ config, lib, pkgs, ... }:
{
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    gcc # C compiler
    jdk # Java Development Kit
    jre # Java Runtime Enviroment
    maven # Java Helper.
    gradle # Java Helper.
    python315 # Python Scripting language.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
