# my-packages.nix
{ config, lib, pkgs, ... }:
{
      nixpkgs.config.android_sdk.accept_license = true;
  # This adds packages to the system-wide environment
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    gcc # C compiler
    jdk # Java Development Kit
    maven # Java Helper.
    gradle # Java Helper.
    androidenv.androidPkgs.androidsdk # Android SDK.
    python315 # Python Scripting language.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];
  # Alternatively, for environment.variables (slightly different mechanism, but often interchangeable for simple use cases)
  # environment.variables = {
  ANDROID_SDK_ROOT="${androidsdk}/libexec/android-sdk";
  # };

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
