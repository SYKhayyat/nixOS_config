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
# and nothing else.
#
# The one exception this file used to carry is gone. `enchant`, `hunspell`,
# `aspell` and the `DICPATH` session variable that pointed at them were here
# because the old Nix-side Emacs config spell-checked with jinx; the config they
# served was deleted on 2026-11-18, and the audit listed them with it. Keeping
# them would have been the same mistake one layer down — a package kept for a
# caller that no longer exists, in the file whose whole argument is that nothing
# gets in without one.
#
# Where they would go back: the Emacs configuration or LibreOffice, whichever needs
# them, in the module that needs them. `DICPATH` has to be a *session* variable
# rather than a home-manager one if a GUI program is the consumer, because a
# program launched from a compositor never sources a login shell — that part of
# the old comment was correct, and it is the reason this is a decision to revisit
# rather than a line to add.
{ pkgs, ... }:

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
    # `nh` rebuilds. `home-manager` does not: Home Manager runs as a NixOS
    # module here and the flake has no `homeConfigurations`, so the repair for
    # a home profile that fails to build is `just switch`. The CLI is kept for
    # `home-manager generations` and `home-manager news`.
    nh
    home-manager

    # `just` is here, outside the home profile, because it is that repair:
    # `just switch` is `nixos-rebuild switch`, which rebuilds the home profile
    # too. A home profile that does not build cannot be repaired from inside
    # itself — the entry point to fixing it has to already exist, or the failure
    # mode is a machine whose documented repair command is missing.
    #
    # This was not hypothetical: ./justfile, README.md and CI all document
    # `just switch` / `just lint` / `just check` as the interface, and `just`
    # was in no closure on this machine. Every documented command in this repo
    # was unrunnable.
    just
  ];
}
