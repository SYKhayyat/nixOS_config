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

focus="$system/specialisation/focus"
focusProfile="$focus/etc/profiles/per-user/$user/bin"

# `focus`'s claim is not about packages, it is about *processes*, so the checks
# for it read the generated unit directory rather than a bin directory. That is
# also the only place its one real bug has ever been visible: dropping
# ./network.nix took NetworkManager, wpa_supplicant and ModemManager away and
# left `dhcpcd.service`, because `networking.useDHCP` defaults to true and is
# not implemented by NetworkManager. It evaluated, it built, and nothing said a
# word — it showed up in a diff of these two directories.
units="$system/etc/systemd/system"
focusUnits="$focus/etc/systemd/system"

# `study`'s claim is a process claim too — "NetworkManager, wireless, Bluetooth,
# sshd and the data bootstrap off; firewall deny-all" — and for a long time this
# script tested only its *packages*. That gap was not hypothetical: the one unit
# assertion that would have caught an enabled `dhcpcd.service` in the airgap was
# written against `focus` and never copied here, so the airgap shipped a DHCP
# client for as long as it has existed. Both halves are below now.
studyUnits="$study/etc/systemd/system"

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

# ── Absent and masked are different, and `absent` above cannot tell them apart ─
#
# `systemd.services.<n>.enable = false` does NOT omit the unit. nixpkgs'
# `makeUnit` (nixos/lib/systemd-lib.nix:76) takes the `else` branch and builds a
# store path named `unit-<name>-disabled`, and systemd's masking convention
# lives INSIDE it. The result in the closure is two hops, not one:
#
#     /etc/systemd/system/<name>
#       -> /nix/store/…-unit-<name>-disabled/<name>
#            -> /dev/null
#
# `[ -e ]` resolves that whole chain, finds /dev/null and reports the unit as
# present — so `absent` would go red on a unit that is correctly switched off.
#
# The two hops are the entire subtlety, and getting it wrong is not theoretical:
# this helper first shipped comparing `readlink "$path"` to "/dev/null". Plain
# `readlink` prints only the FIRST hop — the `-disabled` store path — so the
# comparison never matched and the airgap's two data-bootstrap units were
# reported as live. Hence `readlink -f` below, which resolves the chain to its
# end. Anything that ends at /dev/null is masked, however many links it took.
#
# Both forms are live in this repo and they are not interchangeable:
#
#   absent            the module was never imported, or its `mkIf` is false, so
#                     nothing was generated. NetworkManager, wpa_supplicant,
#                     ModemManager, sshd and dhcpcd in `study` — the forces in
#                     study-offline.nix make the generating modules inert.
#   masked            the unit is declared and switched off by name. Both
#                     `shaulos-data-bootstrap` units, via `enable = mkForce
#                     false`.
#
# Either is a pass. A real unit file is the failure. Distinguishing them is not
# pedantry — it is the same mistake in miniature as the one the seforim section
# below is about: a check that cannot tell two states apart will eventually be
# asked to tell them apart.
not_running() {
  local path="$1/$2"
  local resolved
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    ok "$2 is not in $3 (absent — nothing generated it)"
    return
  fi
  # -f, not bare readlink: follow every hop to the end of the chain.
  resolved=$(readlink -f "$path" 2>/dev/null) || resolved=""
  if [ "$resolved" = "/dev/null" ]; then
    ok "$2 is masked in $3 (resolves to /dev/null)"
  elif [ ! -s "$path" ]; then
    # Belt and braces. A unit that resolves somewhere other than /dev/null but
    # still has no content cannot start anything either, and saying so is more
    # useful than calling it live.
    ok "$2 is inert in $3 (zero-length unit)"
  else
    bad "$2 IS a live unit in $3 ($(wc -c <"$path") bytes) — $4"
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
anchor_dir "$units" "the system unit directory"
anchor_dir "$studyUnits" "study's unit directory"
anchor_dir "$focus" "the focus specialisation"
anchor_dir "$focusProfile" "focus's home profile"
anchor_dir "$focusUnits" "focus's unit directory"

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
echo "── the base system runs all of this ───────────────────────────────────"
# The anchor for the section below, and the reason it is a whole section: an
# "is this unit absent" test is worthless if the unit was never generated under
# this name in the first place. Every name asserted absent from focus is
# asserted present here first, so a nixpkgs rename turns this section red
# rather than turning the next one green.
daemons=(
  display-manager.service # SDDM, and Plasma behind it
  NetworkManager.service
  wpa_supplicant.service
  ModemManager.service
  sshd.service
  cups.service
  bluetooth.service
  blueman-mechanism.service
  pipewire.service
  wireplumber.service
  flatpak-system-helper.service
  ollama.service
  update-locatedb.service        # services.locate's plocate run
  udisks2.service
  upower.service
  accounts-daemon.service
)
for u in "${daemons[@]}"; do
  present "$units" "$u" "the base system's units" \
    "if this name is wrong, the focus assertions below prove nothing"
done

echo
echo "── focus runs none of it ──────────────────────────────────────────────"
# README.md's claim for focus is a list of things that are NOT running. Unlike
# study, focus does not force any of these off — it is built with
# inheritParentConfig = false, so the units are absent because the modules that
# generate them were never imported. This is what asks the artifact whether
# that actually worked.
for u in "${daemons[@]}"; do
  absent "$focusUnits" "$u" "focus's units" \
    "focus does not import the module that generates it; see modules/system/focus.nix"
done
# Not in the list above because the base system does not generate it either:
# it appears only when NetworkManager is absent AND networking.useDHCP is left
# at its default of true. That is the bug this section was written for, and it
# is invisible to every other check in this file.
absent "$focusUnits" "dhcpcd.service" "focus's units" \
  "networking.useDHCP defaults to TRUE — dropping NetworkManager falls back to dhcpcd rather than to nothing"

echo
echo "── study still runs the desktop it inherits ───────────────────────────"
# The anchor for the section below, and it is doing two jobs. It proves we are
# reading a real unit directory — without it, "NetworkManager is absent from
# study" and "I mistyped the path" are the same result — and it proves study is
# still the inheriting specialisation it claims to be. If Plasma and ollama were
# to vanish from here, study has stopped being "this system with the radios off"
# and every assertion below is answering a question about a different closure.
for u in display-manager.service ollama.service cups.service update-locatedb.service; do
  present "$studyUnits" "$u" "study's units" \
    "study inherits the full base system; if this is gone, the absences below prove nothing"
done

echo
echo "── the airgap: study's radios and daemons are off ─────────────────────"
# README.md's claim for study is a *process* claim, and until now this script
# only ever checked its packages. Each name below is a line in
# modules/system/study-offline.nix; a force that stops working is invisible in
# the source and visible right here.
# Absent, because study-offline.nix's forces make the modules that generate
# these inert — `networking.networkmanager.enable`, `networking.wireless.enable`,
# `services.openssh.enable` and `hardware.bluetooth.enable` all gate their units
# behind `mkIf cfg.enable`, so there is nothing left to emit.
for u in \
  NetworkManager.service \
  wpa_supplicant.service \
  ModemManager.service \
  sshd.service \
  bluetooth.service; do
  not_running "$studyUnits" "$u" "study's units" \
    "modules/system/study-offline.nix forces it off; README.md says the airgap does not run it"
done

# Masked rather than absent, and that is the correct outcome. study-offline.nix
# switches these off by name — `systemd.timers.shaulos-data-bootstrap.enable =
# lib.mkForce false` — which nixpkgs renders as a /dev/null symlink. Both are
# named so that `systemctl start` is off too, not just the timer.
for u in shaulos-data-bootstrap.service shaulos-data-bootstrap.timer; do
  not_running "$studyUnits" "$u" "study's units" \
    "study-offline.nix sets enable = mkForce false on both; the airgap must not phone home"
done

# The assertion this whole section exists for, and the one that was missing.
#
# It is the same bug as the focus line above, reached from the other side, and
# it shipped in the airgap for as long as the airgap has existed: force
# NetworkManager off and nixpkgs' `networking.useDHCP` default of TRUE wins
# again, so the "hard offline" closure generated an enabled dhcpcd.service and
# solicited a lease on every wired interface. The firewall cannot catch it —
# those four deny-all lists are an INBOUND claim, and dhcpcd's DISCOVER goes out
# over a raw AF_PACKET socket that never touches the INPUT chain.
not_running "$studyUnits" "dhcpcd.service" "study's units" \
  "networking.useDHCP defaults to TRUE — forcing NetworkManager off falls back to dhcpcd; study-offline.nix must say useDHCP = false out loud"

echo
echo "── the seforim stack and EMACS_MODULE_GROUPS agree ────────────────────"
# The gate this repo did not have, and the reason it did not have one is worth
# stating: every check above is either "is the package there" or "is the unit
# there", and the failure this catches is neither. It is a package that is
# there for code that is not.
#
# modules/home/emacs/default.nix sets EMACS_MODULE_GROUPS = "essentials", which
# leaves 57% of the Emacs configuration — all 89 seforim-* functions and the
# whole Hebrew layer — copied into the store, symlinked into ~/.config/emacs,
# and never loaded. For one commit this machine answered "yes" to every recoll
# question this script asked while being unable to run a single `seforim-'
# command, and the script went green on all of it.
#
# So the two are asserted to agree, in the only direction the artifact can be
# asked about: with `essentials` alone, nothing whose only caller is `extras/`
# may be in any profile. Turn the groups back on and this section is what tells
# you which blocks to uncomment — it will go red, by name, in every closure.
# Bash 3-compatible parallel arrays rather than an associative one: the three
# profile paths and the names to print for them. `basename` cannot do this job —
# all three end in the same `per-user/$user/bin`.
seforimProfiles=("$profile" "$studyProfile" "$focusProfile")
seforimLabels=("the base home profile" "study's home profile" "focus's home profile")
for i in "${!seforimProfiles[@]}"; do
  for b in recoll recollindex xapian hdate; do
    absent "${seforimProfiles[$i]}" "$b" "${seforimLabels[$i]}" \
      "its only callers live in the emacs-config repo's extras/, and EMACS_MODULE_GROUPS says essentials"
  done
done
# The paired present-test, so this cannot go green by looking in the wrong
# place: poppler-utils is in the same lists and is NOT a seforim package —
# essentials/11-pdf.org probes `pdfinfo` and Org export shells out to
# `pdftotext`. If this is absent the absences above mean nothing.
#
# All three profiles, including study's: modules/home/toolkit.nix lists
# `poppler-utils` in `always`, not in `offInStudy`, so the airgap keeps it.
for i in "${!seforimProfiles[@]}"; do
  present "${seforimProfiles[$i]}" "pdftotext" "${seforimLabels[$i]}" \
    "poppler-utils is essentials' PDF path, not seforim's — it anchors the absences above"
done
# And the four-hourly indexer, which is now off in every closure rather than in
# focus alone. It fed an index nothing read: extras/15-seforim-dream.org keeps
# its own recoll confdir under ~/.cache/emacs/seforim and queries that.
absent "$units" "recoll-index-$user.service" "the base system's units" \
  "modules/system/services.nix has it commented out; its index was never the one seforim search read"

echo
echo "── focus runs the one thing it is for ─────────────────────────────────"
present "$focusUnits" "cage-tty1.service" "focus's units" \
  "services.cage is the whole session — without it focus boots to a bare tty"
for b in emacs emacsclient rg fd yazi pandoc git; do
  present "$focusProfile" "$b" "focus's home profile" \
    "focus is Emacs plus text search and the document toolchain; see home/focus.nix"
done

echo
echo "── focus is not the desktop with holes in it ──────────────────────────"
# The desktop half of home/shaul.nix, asserted absent from the profile that
# does not import it. `foot` and `fuzzel` are the interesting two: they came in
# through home/common.nix until modules/home/scripts.nix moved to
# wayland-common.nix, so a regression there would put a terminal and a launcher
# back into the session that has no compositor to run them under.
for b in "${browsers[@]}"; do
  absent "$focusProfile" "$b" "focus's home profile" \
    "focus has no network stack at all"
done
for b in foot fuzzel waybar mako niri Hyprland libreoffice gimp mpv; do
  absent "$focusProfile" "$b" "focus's home profile" \
    "it belongs to a compositor session; see the 'not imported' list in home/focus.nix"
done

echo
if [ "$fail" -ne 0 ]; then
  echo "closure check FAILED — see the FAIL lines above."
  exit 1
fi
echo "closure check passed."
