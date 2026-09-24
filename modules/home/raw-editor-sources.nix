# modules/home/raw-editor-sources.nix
# Pinned raw-editor assets shared by darktable.nix / rawtherapee.nix / art.nix.
#
# The Nikon D7200 calibration profile exists as a DCP in RawTherapee's dev tree
# only — rtdata/dcpprofiles/NIKON D7200.dcp (top level, no `Nikon/` subdir; no
# release branch ships it, and no published prebuilt D7200 ICC exists anywhere).
# We pin that one file and:
#   - hand it straight to ART and RawTherapee, which both read .dcp, and
#   - compile it to an ICC for darktable with camicc (rafaelcgs10/camicc, a
#     pure-python DCP→ICC converter), so all three editors see the same embedded
#     camera calibration without the profile text ever drifting between them.
#
# Verified 2026-09-24 (re-check of the 2026-09-22 pin, file sha256 unchanged):
#   rawtherapee dev @ 6c4cb59  rtdata/dcpprofiles/NIKON D7200.dcp
#     sha256-4kvB5WqAdRqegY+RoiR4HND9kNFvjTKnwSmIdON1eg8=  (1,102,950 bytes)
#   camicc @ 51f566b  (DCP→ICC, `--variant colors`: scene-referred, safe with
#     darktable's filmic/sigmoid pipeline; do NOT use `--variant look`, which
#     bakes a tone curve that double-applies)
#   t3mujinpack @ 0b421f3  (58M HaldCLUT PNGs, shared with darktable)
#
# camicc is a single Python module + numpy (LLM-authored, README flag 3.1:
# empirically validated, not expert-reviewed) — acceptable for a build-time
# profile conversion we can eyeball in the raw editor afterwards.
{
  options,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  d7200Dcp = pkgs.fetchurl {
    name = "NIKON-D7200.dcp";
    url = "https://raw.githubusercontent.com/RawTherapee/RawTherapee/6c4cb5964fcea91dd9bdef619d4825712e083cb8/rtdata/dcpprofiles/NIKON%20D7200.dcp";
    hash = "sha256-4kvB5WqAdRqegY+RoiR4HND9kNFvjTKnwSmIdON1eg8=";
  };
  camicc = pkgs.fetchFromGitHub {
    owner = "rafaelcgs10";
    repo = "camicc";
    rev = "51f566b995136131230763604a944a595069a7c5";
    hash = "sha256-tF2v0qybshVY5byYDjmLIb/SfoAY8IEO5/BdiHmY1v0=";
  };
  d7200Icc = pkgs.runCommand "NIKON-D7200.icc" { } ''
    buildDir="$TMPDIR/icc"
    mkdir -p "$buildDir"
    cd "${camicc}"
    ${pkgs.python3.withPackages (ps: [ ps.numpy ])}/bin/python -m camicc.cli \
      "${d7200Dcp}" -o "$buildDir" \
      --variant colors --name "NIKON D7200"
    cp "$buildDir/NIKON D7200 (colors only).icc" "$out"
  '';
in
{
  options.shaulos.rawEditors = {
    d7200Dcp = mkOption {
      type = types.package;
      internal = true;
      description = "Pinned Nikon D7200 DCP (RawTherapee dev tree).";
    };
    d7200Icc = mkOption {
      type = types.package;
      internal = true;
      description = "D7200 ICC for darktable, converted from the DCP at build time.";
    };
    t3mujinpack = mkOption {
      type = types.package;
      internal = true;
      description = "Pinned t3mujinpack HaldCLUT pack, shared across the raw editors.";
    };
  };
  config.shaulos.rawEditors = {
    inherit d7200Dcp d7200Icc;
    t3mujinpack = pkgs.fetchFromGitHub {
      owner = "t3mujinpack";
      repo = "t3mujinpack";
      rev = "0b421f3e25209ed78253d1724a29cc6255c5e7fe";
      hash = "sha256-2e0gxQD4fhfw5b7lzyoOo5T4GJotGD7S7o4vudVtLC8=";
    };
  };
}
