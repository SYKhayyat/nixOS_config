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
# servers and modules/home/emacs.nix already had them. And `nixpkgs-fmt`
# is gone rather than moved — `nix fmt` and `just fmt` run nixfmt-rfc-style, so
# a second Nix formatter on $PATH is a coin-flip about which one reformats the
# file you are looking at.

{ pkgs, ... }:

{
  # ══════════════════════════════════════════════════════════════════
  # NIX-LD (Run unpatched binaries)
  # Required for some downloaded executables and IDEs
  # ══════════════════════════════════════════════════════════════════

  # One list, not two. This was steam-run's `multiPkgs` *plus* a hand-written
  # twenty-package list that mostly overlapped it — nobody could tell which
  # half the binaries actually needed. The hand list is gone; multiPkgs is the
  # set with a reason to exist.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = pkgs.steam-run.args.multiPkgs pkgs;

  # ══════════════════════════════════════════════════════════════════
  # DIRENV
  # Automatic environment loading for project directories
  # ══════════════════════════════════════════════════════════════════

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
