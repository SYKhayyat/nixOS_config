# modules/system/cli-tools.nix
# System-wide command-line tools

{ config, lib, pkgs, ... }:

let
  # Spell checking dictionaries
  hunspellDicts = with pkgs.hunspellDicts; [ en_US he_IL ];
  hunspellWithDicts = pkgs.hunspellWithDicts hunspellDicts;
in
{
  # ══════════════════════════════════════════════════════════════════
  # COMMAND-LINE TOOLS
  # ══════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    # ────────────────────────────────────────────────────────────────
    # ESSENTIAL TOOLS
    # ────────────────────────────────────────────────────────────────
    git
    wget
    curl
    htop
    tree

    # ────────────────────────────────────────────────────────────────
    # FILE SEARCH
    # ────────────────────────────────────────────────────────────────
    fd                      # Better 'find'
    ripgrep                 # Better 'grep'
    ripgrep-all             # Ripgrep for all file types
    fzf                     # Fuzzy finder
    fzy                     # Another fuzzy finder
    plocate                 # Fast 'locate'
    recoll                  # Full-text search
    fsearch                 # GUI file search
    kdePackages.kfind       # KDE file search
    television              # File finder TUI
    docfd                   # Document fuzzy finder
    skim                    # Fuzzy finder (Rust)
    agrep                   # Approximate grep

    # ────────────────────────────────────────────────────────────────
    # FILE MANAGEMENT
    # ────────────────────────────────────────────────────────────────
    nnn                     # Terminal file manager
    ranger                  # Terminal file manager
    mc                      # Midnight Commander
    fdupes                  # Duplicate finder
    ncdu                    # Disk usage analyzer
    peazip                  # Archive manager

    # ────────────────────────────────────────────────────────────────
    # DOCUMENT TOOLS
    # ────────────────────────────────────────────────────────────────
    pandoc                  # Document converter
    poppler                 # PDF library
    poppler-utils           # PDF utilities
    antiword                # Word document converter
    catdoc                  # Word/Excel/PowerPoint viewer
    unzip                   # Archive extraction

    # ────────────────────────────────────────────────────────────────
    # SPELL CHECKING
    # ────────────────────────────────────────────────────────────────
    enchant
    hunspellWithDicts
    (aspellWithDicts (dicts: with dicts; [ en en-computers he ]))

    # ────────────────────────────────────────────────────────────────
    # SEARCH INDEXING
    # ────────────────────────────────────────────────────────────────
    xapian

    # ────────────────────────────────────────────────────────────────
    # DOWNLOADERS
    # ────────────────────────────────────────────────────────────────
    aria2                   # Download manager

    # ────────────────────────────────────────────────────────────────
    # TERMINAL UTILITIES
    # ────────────────────────────────────────────────────────────────
    bat                     # Better 'cat'
    navi                    # Cheatsheet tool
    lynx                    # Terminal web browser

    # ────────────────────────────────────────────────────────────────
    # TERMINAL EDITORS
    # ────────────────────────────────────────────────────────────────
    vim
    neovim
    helix

    # ────────────────────────────────────────────────────────────────
    # NIX TOOLS
    # ────────────────────────────────────────────────────────────────
    nh                      # Nix helper
    home-manager
    # ────────────────────────────────────────────────────────────────
    # AI TOOLS
    # ────────────────────────────────────────────────────────────────
    opencode
  ];

  # ══════════════════════════════════════════════════════════════════
  # FIREFOX
  # ══════════════════════════════════════════════════════════════════

  programs.firefox.enable = true;

  # ══════════════════════════════════════════════════════════════════
  # ENVIRONMENT VARIABLES
  # ══════════════════════════════════════════════════════════════════

  environment.sessionVariables = {
    DICPATH = lib.mkForce "${hunspellWithDicts}/share/hunspell";
  };
}
