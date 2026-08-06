#!/usr/bin/env bash
#
# tools/check-closure.sh — ask the built system whether it is what the docs say.
#
# Run against the result of `nix build .#checks.x86_64-linux.toplevel`:
#
#     nix build .#checks.x86_64-linux.toplevel
#     bash tools/check-closure.sh ./result
#
# ── Why this file exists ──────────────────────────────────────────────────
#
# "Offline airgap, no browsers" was in README.md while `firefox` and `lynx` were
# on $PATH in the study specialisation (Lamdan 3.2, and the `lynx` half was
# found later, two words away on the same line of the same file). Both are fixed
# — the browsers moved to modules/home/toolkit.nix, where `shaulos.study`
# subtracts them by construction rather than by a mkForce someone remembered to
# write.
#
# "By construction" is a claim about the source. This asks the artifact. A
# specialisation can only ever ADD to its parent, so every subtraction it makes
# is a mechanism that can be got wrong, and no amount of reading the .nix files
# tells you what actually landed in the closure.
#
# ── The anchors matter as much as the assertions ──────────────────────────
#
# Half of what follows checks that a thing is PRESENT. That is not padding. An
# "is X absent" test passes trivially when you are looking in the wrong place,
# and a check that cannot tell "absent" from "I could not find the directory" is
# the exact failure mode this whole pass exists to kill: it goes green forever
# and tells you nothing. So every absence test is paired with a presence test in
# the same directory, and a missing anchor is a hard failure.
#
# Layout being asserted, all of it standard NixOS:
#
#   $system/sw/bin                                  environment.systemPackages
#   $system/etc/profiles/per-user/<user>/bin        home.packages, because
#                                                   home-manager.useUserPackages
#                                                   is true and NixOS renders
#                                                   users.users.<n>.packages
#                                                   into environment.etc
#   $system/specialisation/<name>                   the child toplevel
#
set -euo pipefail

system=${1:-./result}
user=${2:-shaul}

sw="$system/sw/bin"
profile="$system/etc/profiles/per-user/$user/bin"
study="$system/specialisation/study"
studySw="$study/sw/bin"
studyProfile="$study/etc/profiles/per-user/$user/bin"

fail=0

ok() { printf '  ok    %s\n' "$*"; }
bad() {
  printf '  FAIL  %s\n' "$*"
  fail=1
}

# An anchor is fatal on its own: if the layout is not what we think, nothing
# below this line means anything and reporting it as a pass would be a lie.
anchor_dir() {
  if [ -d "$1" ]; then
    ok "$2 exists ($1)"
  else
    printf '\nFATAL: %s is not a directory.\n' "$1"
    printf 'The store layout is not what this script assumes, so every "absent"\n'
    printf 'result below would be meaningless. Fix the path in tools/check-closure.sh.\n'
    exit 2
  fi
}

present() {
  if [ -e "$1/$2" ]; then
    ok "$2 is in $3"
  else
    bad "$2 is NOT in $3 — expected it there; $4"
  fi
}

absent() {
  if [ -e "$1/$2" ]; then
    bad "$2 IS in $3 — $4"
  else
    ok "$2 is not in $3"
  fi
}

# Browsers, as modules/home/toolkit.nix lists them. `tor-browser` has been
# spelled `torbrowser` in nixpkgs' past, so both names are checked for absence;
# neither is used as an anchor, because a package rename must not be able to
# turn this check green.
browsers=(firefox lynx qutebrowser tor-browser torbrowser)

# The other half of toolkit.nix's `offInStudy` that is a real claim rather than
# taste: the things whose entire job is fetching over a network the airgap has
# just switched off.
fetchers=(aria2 yt-dlp ytfzf rclone persepolis)

echo
echo "system: $system"
echo

echo "── layout ─────────────────────────────────────────────────────────────"
anchor_dir "$sw" "the system package set"
anchor_dir "$profile" "$user's home profile"
anchor_dir "$study" "the study specialisation"
anchor_dir "$studySw" "study's system package set"
anchor_dir "$studyProfile" "study's home profile"

echo
echo "── modules/system/base-tools.nix: the repair set is there ─────────────"
# If these are missing we are reading a system path that is not the one the
# machine boots, and every absence test below is worthless.
for b in git vim curl htop nh home-manager; do
  present "$sw" "$b" "the system package set" \
    "modules/system/base-tools.nix installs it"
done

echo
echo "── the rule: no browser is a system package, in any closure ───────────"
# base-tools.nix holds only what must work when home-manager is broken. A
# browser has never qualified, and `programs.firefox.enable = true` at the NixOS
# level is exactly how one got in last time — it puts firefox into
# environment.systemPackages, which every specialisation inherits and none can
# remove.
for b in "${browsers[@]}"; do
  absent "$sw" "$b" "the system package set" \
    "environment.systemPackages is inherited by study and cannot be subtracted; it belongs in modules/home/toolkit.nix"
  absent "$studySw" "$b" "study's system package set" \
    "same, one closure down"
done

echo
echo "── the base session has the browsers ──────────────────────────────────"
# The anchor for the section below. If these are absent the airgap result is
# "I found no browsers anywhere", which is not the same sentence at all.
for b in firefox qutebrowser lynx; do
  present "$profile" "$b" "$user's home profile" \
    "modules/home/toolkit.nix installs it outside study"
done

echo
echo "── the airgap: study has none of them ─────────────────────────────────"
for b in "${browsers[@]}"; do
  absent "$studyProfile" "$b" "study's home profile" \
    "README.md says \"no browsers\"; see toolkit.nix offInStudy"
done
for f in "${fetchers[@]}"; do
  absent "$studyProfile" "$f" "study's home profile" \
    "its job is fetching over the network study has switched off"
done

echo
echo "── study keeps what it is supposed to keep ────────────────────────────"
# The other half of the same claim, and the one that decides whether you go on
# booting this specialisation at all. README.md: study keeps "the search tools,
# the file managers, the editors, the document toolchain, the compilers and a
# local media player." One binary per clause of that sentence, in order, plus
# Emacs — which is the session's entire reason to exist and comes from
# modules/home/emacs/default.nix rather than from toolkit.nix.
for b in rg fd nnn pandoc gcc mpv emacs; do
  present "$studyProfile" "$b" "study's home profile" \
    "study removes browsers, downloaders and the creative suite — not tools"
done

echo
if [ "$fail" -ne 0 ]; then
  echo "closure check FAILED — see the FAIL lines above."
  exit 1
fi
echo "closure check passed."
