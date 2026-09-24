# modules/home/art.nix
# ART 1.26.4 — profiles, LUTs, "plugins".
#
# ART is the maintained RawTherapee fork with the same pipeline, so the notes
# from rawtherapee.nix apply one-for-one. It reads DCPs from
# ~/.config/ART/profiles (Raw Pixels profile selection), and LUTs for the
# lut3d module / film simulation from ~/.config/ART/lut.
#
# Plugins: ART inherits RawTherapee's "no plugin API" stance; this section is
# deliberately empty for the same reason as rawtherapee.nix — see its header.
{
  config,
  pkgs,
  ...
}:
let
  inherit (config.shaulos.rawEditors) d7200Dcp t3mujinpack;
in
{
  # The package itself lives in toolkit.nix (offInStudy → pkgs.art 1.26.4).

  # ── Profiles ─────────────────────────────────────────────────────────────
  xdg.configFile."ART/profiles/NIKON D7200.dcp".source = d7200Dcp;

  # ── LUTs ─────────────────────────────────────────────────────────────────
  xdg.configFile."ART/lut/t3mujinpack".source = "${t3mujinpack}/haldcluts";

  # ── Plugins ──────────────────────────────────────────────────────────────
  # none — see the header note.

  home.packages = [
    (pkgs.writeShellScriptBin "art-verify" ''
      set -e
      dcp="$HOME/.config/ART/profiles/NIKON D7200.dcp"
      echo "art: $(command -v art)"
      if test -f "$dcp"; then
        echo "D7200 DCP: present ($(du -h "$dcp" | cut -f1))"
      else
        echo "D7200 DCP: MISSING" >&2
        exit 1
      fi
      echo "luts: $(find "$HOME/.config/ART/lut" -type f 2>/dev/null | wc -l) files"
    '')
  ];
}
