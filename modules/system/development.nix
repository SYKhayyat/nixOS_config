# modules/system/development.nix
#
# The parts of the development environment that only the system can provide:
# a loader for unpatched binaries, and per-directory environments.
#
# The compilers and toolchains that used to be in `environment.systemPackages`
# here are in modules/home/toolkit.nix now. They were not doing anything the
# system had to do — nix-ld's libraries below are referenced as derivations, not
# through $PATH, and a build never reads your profile. What putting them in the
# system closure *did* do was make them unremovable by the `study`
# specialisation, along with everything else that had drifted into a system
# list. See toolkit.nix for the rule.
#
# Two of them were also duplicates: `nil` and `rust-analyzer` are language
# servers and modules/home/emacs/default.nix already had them. And `nixpkgs-fmt`
# is gone rather than moved — `nix fmt` and `just fmt` run nixfmt-rfc-style, so
# a second Nix formatter on $PATH is a coin-flip about which one reformats the
# file you are looking at.

{ pkgs, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # NIX-LD (Run unpatched binaries)
  # Required for some downloaded executables and IDEs
  # ══════════════════════════════════════════════════════════════════

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries =
    (pkgs.steam-run.args.multiPkgs pkgs)
    ++ (with pkgs; [
      # Core libraries for Java AWT/Swing (Updated to non-deprecated names)
      freetype
      fontconfig
      libX11
      libXext
      libXrender
      libXtst
      libXi

      # Additional UI libraries
      libGL
      zlib
      stdenv.cc.cc
      gtk3
      atk
      cairo
      gdk-pixbuf
      glib
      harfbuzz
      libepoxy
      pango
    ]);

  # Accept Android SDK license
  nixpkgs.config.android_sdk.accept_license = true;

  # ══════════════════════════════════════════════════════════════════
  # DIRENV
  # Automatic environment loading for project directories
  # ══════════════════════════════════════════════════════════════════

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
