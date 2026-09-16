# modules/system/base-tools.nix
#
# What the *machine* installs, as opposed to what *you* install. It is a short
# list and every entry has to earn its place, because a specialisation inherits
# its parent and nothing here can be taken away by one.
#
# This file was `cli-tools.nix`, and the name was the problem. "CLI tool" is a
# category every command-line program is in, so the file became the drawer: 30
# packages, three terminal editors, fourteen search tools, and a browser. Then
# `study` — whose whole claim is "offline airgap, no browsers" — inherited
# `lynx` from line 31 of it. See modules/home/toolkit.nix for the full argument;
# the rule it lands on is:
#
#   environment.systemPackages holds only what has to work when home-manager is
#   broken, absent, or not yours. Everything a person types goes to home, where
#   `shaulos.study` can reach it.
#
# So what is left below is the set you repair a bad generation with — you are in
# a TTY, the last switch went wrong, your home profile may well be the reason —
# plus one argued exception at the bottom.
{ lib, pkgs, ... }:

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
    # ── Repair ────────────────────────────────────────────────────────────
    # git, because this config is a git repo and a bad switch is usually undone
    # by reading or reverting it. vim, because you have to edit a .nix file
    # before you can rebuild the profile that would have given you an editor.
    # The rest is what you reach for while working out what happened.
    git
    vim
    wget
    curl
    htop
    tree
    unzip
    zip

    # ── Rebuilding ────────────────────────────────────────────────────────
    # The two commands that undo the mistake. `home-manager` especially has to
    # exist outside the home profile it manages, or a home profile that fails
    # to build takes its own repair tool down with it.
    nh
    home-manager

    # ── The one exception ─────────────────────────────────────────────────
    # The spell-checking stack stays machine-wide because `DICPATH` below has
    # to. environment.sessionVariables is set by PAM, so every process in the
    # session sees it — including a GUI Emacs or a LibreOffice launched from a
    # compositor, neither of which runs a login shell and so neither of which
    # sources home-manager's session variables. A dictionary path that is only
    # right inside a terminal is wrong. The packages stay with the variable
    # that points at them; moving them alone would give it a second definition.
    enchant # what Emacs's jinx speaks
    hunspellWithDicts
    (aspellWithDicts (d: [
      d.en
      d.en-computers
    ]))
  ];

  # `lib.mkForce` here is defensive and predates this file's history — nothing
  # else in the tree sets DICPATH. Left exactly as it was; that is not this pass.
  environment.sessionVariables = {
    DICPATH = lib.mkForce "${hunspellWithDicts}/share/hunspell";
  };
}
