{ config, pkgs, lib, ... }:

let
  emacs = pkgs.emacs-pgtk;
  epkgs = pkgs.emacsPackagesFor emacs;

  hunspellDictsList = [
    pkgs.hunspellDicts.en_US
    pkgs.hunspellDicts.he_IL
  ];

  dicts = pkgs.hunspellWithDicts hunspellDictsList;
in
{
  environment.systemPackages = [
    (epkgs.emacsWithPackages (p: [ p.jinx ]))
    pkgs.enchant2
    dicts
  ];

  # mkForce wins over the definition in emacsPackages.nix
  environment.sessionVariables.DICPATH = lib.mkForce "${dicts}/share/hunspell";
}
