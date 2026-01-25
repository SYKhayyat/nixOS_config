# my-packages.nix
{ config, lib, pkgs, ... }:
{
=======
 ig.android_sdk.accept_license=true;
{ 
>>>>>>> new_branch
  # This adds packages to the system-wide environment
  nixpkgs.config.android_sdk.accept_license = true;
  environment.systemPackages = with pkgs; [
    # Add the packages you want to install
    gcc # C compiler
    android-studio-full # Android IDE
    androidenv.androidPkgs.androidsdk # Android SDK.
    jdk # Java Development Kit
    maven # Java Helper.
    gradle # Java Helper.
    androidenv.androidPkgs.androidsdk # Android SDK.
    python315 # Python Scripting language.
    # You can also add custom-defined packages
    # (pkgs.callPackage ./path/to/your/custom-package.nix {})
  ];
  # Alternatively, for environment.variables (slightly different mechanism, but often interchangeable for simple use cases)
   environment.variables = {
ANDROID_SDK_ROOT="config.home.homeDirectory/.nix-profile/libexec/android-sdk";
 };

  # You can also use this module to configure specific programs
  # For example, to enable the OpenSSH service
  # services.openssh.enable = true;
}
