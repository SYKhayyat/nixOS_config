# emacs-packages.nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    
    # ══════════════════════════════════════════════════════════════════
    # DOCUMENT SYSTEMS
    # ══════════════════════════════════════════════════════════════════

    # LaTeX (includes ConTeXt via scheme-full)
    (texlive.combine {
      inherit (texlive) scheme-full;
    })

    # Typst
    typst
    tinymist       # LSP (replaces typst-lsp)

    # ══════════════════════════════════════════════════════════════════
    # PDF TOOLS
    # ══════════════════════════════════════════════════════════════════

    poppler
    poppler-utils

    # ══════════════════════════════════════════════════════════════════
    # SPELL CHECKING
    # ══════════════════════════════════════════════════════════════════

    hunspell
    hunspellDicts.en_US
    hunspellDicts.he-il

    # ══════════════════════════════════════════════════════════════════
    # FONTS (runtime access)
    # ══════════════════════════════════════════════════════════════════

    culmus

    # ══════════════════════════════════════════════════════════════════
    # PROGRAMMING LANGUAGES & LSP
    # ══════════════════════════════════════════════════════════════════

    python3
    python3Packages.python-lsp-server
    rustc
    cargo
    rust-analyzer
    jdk
    jdt-language-server

    # ══════════════════════════════════════════════════════════════════
    # UTILITIES
    # ══════════════════════════════════════════════════════════════════

    git
    ripgrep
    fd
    sqlite
    graphviz
  ];

  fonts.packages = with pkgs; [
    # Hebrew
    culmus

    # General
    noto-fonts
    liberation_ttf
    dejavu_fonts

    # Programming
    fira-code
    fira-code-symbols

    # Emacs
    emacs-all-the-icons-fonts

    # Typography (corrected names)
    source-serif-pro
    source-sans-pro
    source-code-pro
    libertinus
  ];

  environment.variables = {
    DICPATH = "${pkgs.hunspellDicts.en_US}/share/hunspell:${pkgs.hunspellDicts.he-il}/share/hunspell";
    OSFONTDIR = "/run/current-system/sw/share/X11/fonts";
  };

  fonts.fontDir.enable = true;
}
