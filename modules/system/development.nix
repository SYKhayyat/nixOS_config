# modules/system/development.nix
# System-wide development tools: compilers, languages, nix-ld

{ config, lib, pkgs, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # NIX-LD (Run unpatched binaries)
  # Required for some downloaded executables and IDEs
  # ══════════════════════════════════════════════════════════════════

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = (pkgs.steam-run.args.multiPkgs pkgs) ++ (with pkgs; [
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

  # ══════════════════════════════════════════════════════════════════
  # COMPILERS AND LANGUAGES
  # ══════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    # C/C++
    gcc
    gnumake
    cmake

    # Java
    jdk
    maven
    gradle

    # Go
    go

    # Rust
    rustc
    cargo
    rust-analyzer
    clippy

    # Python (with packages)
    (python3.withPackages (ps: with ps; [
      python-docx
      textual
      pip
      virtualenv
    ]))

    # Nix language tools
    nil
    nixpkgs-fmt

    # Build tools
    pkg-config
  ];

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
