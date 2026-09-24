# modules/home/rawtherapee.nix
# RawTherapee 5.12 — profiles, LUTs, "plugins".
#
# RawTherapee reads camera calibration DCPs from ~/.config/RawTherapee/
# iccprofiles/input (Color Management tab → Input Profile ▾ Custom), so the
# pinned D7200 profile from raw-editor-sources.nix lands exactly there — NOT in
# the install dir, which Nix owns and is read-only.
#
# LUTs: the lut3d module / film emulation browses ~/.config/RawTherapee/lut.
# We link the same t3mujinpack HaldCLUT pack darktable uses — identical fetch,
# identical store path, no second download.
#
# Plugins: RawTherapee deliberately has no plugin/script API (unlike darktable's
# Lua). What exists in the wild is shell wrappers around its CLI (batch queues,
# hegui-like workflows), none of which belong here declaratively. So this
# section is intentionally empty; if a real plugin mechanism appears, it goes
# here.
{
  config,
  pkgs,
  ...
}:
let
  inherit (config.shaulos.rawEditors) d7200Dcp t3mujinpack;
in
{
  # The package itself lives in toolkit.nix (offInStudy → pkgs.rawtherapee 5.12).

  # ── Profiles ─────────────────────────────────────────────────────────────
  xdg.configFile."RawTherapee/iccprofiles/input/NIKON D7200.dcp".source = d7200Dcp;

  # ── LUTs ─────────────────────────────────────────────────────────────────
  xdg.configFile."RawTherapee/lut/t3mujinpack".source = "${t3mujinpack}/haldcluts";

  # ── Plugins ──────────────────────────────────────────────────────────────
  # none — see the header note.

  # Helper to confirm the profile is where RawTherapee will read it.
  home.packages = [
    (pkgs.writeShellScriptBin "rawtherapee-verify" ''
      set -e
      dcp="$HOME/.config/RawTherapee/iccprofiles/input/NIKON D7200.dcp"
      echo "rawtherapee: $(command -v rawtherapee)"
      if test -f "$dcp"; then
        echo "D7200 DCP: present ($(du -h "$dcp" | cut -f1))"
      else
        echo "D7200 DCP: MISSING" >&2
        exit 1
      fi
      echo "luts: $(find "$HOME/.config/RawTherapee/lut" -type f 2>/dev/null | wc -l) files"
    '')
  ];
}
