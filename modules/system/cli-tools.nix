{ config, lib, pkgs, ... }:

let
  # English only.  The Hebrew dictionaries (hunspell he_IL, aspell he) were
  # dropped along with Hebrew spell checking in the Emacs config: unvowelled
  # Hebrew with optional ktiv male/chaser spellings is not something these
  # dictionaries model, so every other word came back flagged and the feature
  # was noise rather than help.
  hunspellWithDicts = pkgs.hunspell.withDicts (d: [ d.en_US ]);
in
{
  environment.systemPackages = with pkgs; [
    # ESSENTIALS
    git wget curl htop tree

    # FILE SEARCH (Unabridged)
    fd ripgrep ripgrep-all fzf fzy plocate recoll
    fsearch kdePackages.kfind television docfd skim ugrep tre
    (pkgs.aspellWithDicts (d: [ d.en d.en-computers ]))

    # FILE MANAGEMENT
    nnn ranger mc fdupes ncdu peazip

    # DOCUMENT TOOLS
    pandoc poppler poppler-utils antiword catdoc unzip zip

    # SPELL CHECKING
    enchant hunspellWithDicts

    # DOWNLOADERS & TERMINAL UTILITIES
    aria2 bat navi lynx ytfzf yt-dlp mpv xapian

    # TERMINAL EDITORS
    vim neovim helix

    # NIX TOOLS
    nh home-manager

    # AI TOOLS
    opencode
  ];

  programs.firefox.enable = true;

  environment.sessionVariables = {
    DICPATH = lib.mkForce "${hunspellWithDicts}/share/hunspell";
  };
}
