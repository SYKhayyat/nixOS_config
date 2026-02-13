# my-packages.nix
{ config, lib, pkgs, ... }:

{ 
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    gcc # C compiler
    jdk # Java Development Kit
    maven # Java Helper.
    gradle # Java Helper.
    (pkgs.python3.withPackages (ps: with ps; [
    python-docx
    textual
    # Other libraries: pandas, requests, etc.
  ]))
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];

  nixpkgs.config.android_sdk.accept_license = true;
  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
