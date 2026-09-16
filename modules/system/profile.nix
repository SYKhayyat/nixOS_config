# modules/system/profile.nix
#
# The one fact the home profile needs from the system: is this closure the study
# closure? There is exactly one specialisation left, and this is how
# home/shaul.nix finds out it is inside it — home-manager's NixOS module passes
# the system `config` down to every home module as `osConfig`, so the flag
# travels without a second place that says which home profile to import.
#
# That second place is the point. `home-manager.users.<name>` is a submodule, so
# two definitions of it MERGE: a specialisation that sets
# `users.shaul.imports = [ ./home/study.nix ]` does not replace the parent's
# `imports = [ ./home/desktop.nix ]`, it adds to it. The old study
# specialisation therefore imported the full desktop profile as well as its own
# — tor-browser, qutebrowser and the entire graphics suite included, in the
# session whose whole point was not having them. `lib.mkIf false` around the
# home-manager block does not retract the parent definition either; it just
# contributes nothing.
#
# One import site plus a boolean cannot do that.
{ lib, ... }:

{
  options.shaulos.study = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      True inside the `study` specialisation. Hard offline at the system level;
      at the home level it swaps the desktop application suite for the study
      toolchain and turns the browsers off.
    '';
  };
}
