# Overhaul — what changed and what you must do next

This pass fixed build-blocking bugs, de-duplicated the config, added repo tooling,
made Emacs reproducible, and added laptop hardware + a real study airgap.
It was authored off-machine, so **nothing here has been `nixos-rebuild`-tested** —
work through the checklist below on the NixOS box.

As of entry (o) that sentence had a machine standing behind half of it — on
paper. CI evaluates the module system, builds the closure and interrogates the
result on every push, and **none of those gates had ever run green**: the lock
pinned four of six inputs, so `nix flake check` failed before reaching a check,
and `statix check .` exited 1 on the tree regardless.

As of entry (p) it is true. That pass was run on the NixOS box rather than
written about: the lock is complete, both lint gates exit 0, the module system
and the `study` specialisation evaluate, the closure builds, and the findings
that no evaluator can reach — binaries named inside strings, compositor verbs
that do not exist, `pgrep` patterns that cannot match — were checked against the
real binaries in the real store.

What CI still cannot tell you is whether the system *switches*. The checklist
stays.

## Status of `lamdan/shaulos-config-2026-08-06.md`

**Closed**, as of entry (m). Every row of the ranked table and every bullet of
3.4 has been acted on or argued down in writing:

| # | Verdict | Where |
|---|---|---|
| 1.1 | Emacs config is a separate product | (a) the `require` breakage, (b) the repo split |
| 2.1 | compositors should be sessions | (c) |
| 1.2 | `minimal` isn't minimal | (c) |
| 2.2 | the two compositor modules are one file | (c) `wayland.nix`, finished in (f) |
| 2.3 | scripts `pgrep` for a compiled-in fact | (c) — the premise changed with the closure count; the silent fall-through was the real bug and it is fixed |
| 3.1 | second nixpkgs, zero call sites | (h) |
| 3.2 | firefox in the "no browsers" airgap | (c) one line, then (g) at the root |
| 3.3 | duplicate terminal toggle | `emacs-config`, 2026-08-06 |
| 2.4 | `palette.nix` duplicates the scheme | (e) — rated `wrong-but-keep`; done anyway, because the second copy was in the wrong *format* and four hyprlock lines had never parsed |
| 3.4 | five smalls | (d), (f), (g), (h), (i), (j) |
| — | *"laptop or desktop?"* | (l) — laptop |
| — | *"that's not carelessness; that's a missing CI job"* (1.1) | (o) — the sentence was about the elisp, the diagnosis was about the repo. `emacs-config` got a CI job out of it and this half got none |

**Still open, and both are yours rather than the config's:**

- *"What are you building next?"* — half-answered: there are several laptops.
  Nothing in here changes at a host count of one, but `modules/system/hardware.nix`
  is the first file that has to stop being a singleton, and it says so at the top.
- Secure boot (lanzaboote) and the `nix-ld`/`steam-run.args.multiPkgs` hack, both
  flagged under *Deliberately NOT changed* below. Neither is a Lamdan finding.

---

## 2026-08-14 (s) — the airgap was taking a DHCP lease, and the machine was provisioned for an Emacs it does not load

This entry closes an external audit of `2cc0946` (`GRADE-2026-08-14`), which
graded the repo **A− / NOT READY** and gave two reasons: one stated guarantee
that was false at runtime, and one deliberate toggle whose cost was never
traced. Both are below, along with the nine smaller findings and the three
commits that shipped without an entry here — which is itself one of the
findings, and the mechanism behind two of the others.

**Every fix below was verified against the evaluated configuration**, not read
off the source. The three cheap CI gates (lock, lint, all three eval steps) pass
locally; the closure build is left to CI, and is the one gate this pass did not
personally finish.

### The airgap booted a DHCP client

`study` generated an **enabled `dhcpcd.service`**. The base system did not.
`focus` did not.

This is the exact failure `modules/system/focus.nix:126-142` already found,
documented at length and fixed — in the other specialisation.
`networking.useDHCP` defaults to **true**, and it is not NetworkManager that
implements it: nixpkgs sets it false inside the network-manager module's
`mkIf cfg.enable`, so `networking.networkmanager.enable = lib.mkForce false` in
`study-offline.nix` took that definition away with it and the default won.

The firewall did not cover it and could not. Those four deny-all lists are an
*inbound* claim; dhcpcd's initial `DISCOVER` goes out over a raw `AF_PACKET`
socket that never traverses the netfilter INPUT chain. The radios genuinely were
off, so this only ever bit on a wired link — which is precisely why a laptop
used on wifi would never show it.

`networking.useDHCP = lib.mkForce false;` in `modules/system/study-offline.nix`,
and the assertion that would have caught it — `tools/check-closure.sh:232`,
written against `focus` and never copied — now exists for `study` too.

    closure  useDHCP  dhcpcd.service     (after)
    base     false    absent
    study    false    absent
    focus    false    absent

### `EMACS_MODULE_GROUPS = "essentials"`, and everything that was provisioned for the half it drops

Entry (r)'s last commit set this variable in both places that matter, and the
mechanism was verified impeccably. What was never traced is what setting it
**costs**:

| group | modules | lines | loaded |
|---|---|---|---|
| `essentials` | 25 | 2,379 | yes |
| `extras` | 15 | **3,165** | **no** |

`extras/` is **57% of the Emacs configuration** — all 89 `seforim-*` functions,
31 of them interactive commands, plus the entire Hebrew and RTL layer. Copied
into the store, symlinked into `~/.config/emacs/modules`, never loaded.

Meanwhile this machine indexed `~/Documents/seforim` every four hours, shipped
`recoll`/`xapian`/`poppler-utils` into the `focus` profile under a comment
reading *"the search stack, because that is what this mode is for"*, and
declared in three separate files that `study` and `focus` had seforim search.
`tools/check-closure.sh` **went green on all of it** — it asserted `recoll` was
present in `focus`'s profile, and it was. That is the presence-test mirror of
the failure that script's own header is about.

The decision is to keep `essentials`, and the rule adopted with it is the part
worth stating, because it applies past this one case:

> Machinery that exists to serve code which does not load gets switched off in
> the same commit — commented out with the reason beside it, not annotated and
> left running.

So, all switched off and all reversible by uncommenting:

| Where | What |
|---|---|
| `modules/system/services.nix` | the four-hourly `recollindex` service + timer |
| `modules/home/emacs/default.nix` | `~/.recoll/recoll.conf`, `hdate`, and the `~/.cache/emacs/seforim` + `~/Documents/seforim/Bavli` scaffolding |
| `modules/home/toolkit.nix` | `recoll`, `xapian` |
| `home/focus.nix` | `recoll`, `xapian`, and its stated purpose rewritten |

`poppler-utils` deliberately **stays**: `essentials/11-pdf.org` probes `pdfinfo`
to decide whether pdf-tools is usable and Org export shells out to `pdftotext`.
It was listed beside `recoll`, which is the only reason it looked like part of
that group.

**The seforim library itself still downloads.** That is data, not machinery —
the texts are yours and readable without Emacs — so `modules/system/data.nix` is
untouched. It is the one place the line above was drawn by judgement rather than
by the rule, and it is one uncomment away from moving.

#### The thing nobody had noticed

The four-hourly timer **was never the index Emacs searched**, in any
configuration, `extras` loaded or not.

`extras/15-seforim-dream.org` keeps a *private* recoll config directory at
`~/.cache/emacs/seforim/recoll`, writes its own `recoll.conf` into it, and runs
`recollindex -c <that dir>` — deliberately, so that it *"never touches a
system-wide recoll setup"*. `seforim-recoll-search` queries that same private
index. The systemd unit ran `recollindex` with no `-c`, so it read
`~/.recoll/recoll.conf` and wrote `~/.recoll/xapiandb`: a second index, over the
same corpus, that no caller has ever opened.

So this was a nice-19 walk of the whole library, every four hours, producing an
artifact with no reader, since the day it was written. Turning `extras` back on
does not justify uncommenting it — `M-x seforim-recoll-index` maintains the
index that search actually uses.

### The gates now test the closure that was not fixed

`check-closure.sh` asserted `focus`'s *processes* and `study`'s *packages*, and
`study`'s entire claim is a process claim. The gap was not hypothetical: the
DHCP finding above was sitting in it. Added, using the anchoring pattern already
ten lines away —

- **`study` still runs the desktop it inherits** — `display-manager`, `ollama`,
  `cups`, `update-locatedb` present. Without this anchor, "NetworkManager is
  absent from `study`" and "I mistyped the path" are the same result.
- **`study`'s radios and daemons are off** — `NetworkManager`, `wpa_supplicant`,
  `ModemManager`, `sshd`, `bluetooth`, and both `shaulos-data-bootstrap` units.
- **`dhcpcd.service` is absent from `study`** — the assertion this section
  exists for.
- **the seforim stack and `EMACS_MODULE_GROUPS` agree** — `recoll`,
  `recollindex`, `xapian` and `hdate` absent from all three profiles, anchored
  by `pdftotext` present. Flip the groups back on and this goes red, by name, in
  every closure, telling you which blocks to uncomment.

#### `absent` and `masked` are different states, and the old helper could not tell them apart

Caught while writing the above, and it would have shipped a red build gate.

`systemd.services.<n>.enable = false` does **not** omit the unit. nixpkgs'
`makeUnit` in `nixos/lib/systemd-lib.nix` takes its other branch and emits

    ln -s /dev/null "$out/<name>.service"

— systemd's masking convention. The script's `absent` helper tests `[ -e ]`,
which **follows the symlink, finds `/dev/null`, and reports the unit as
present**. So asserting the two `shaulos-data-bootstrap` units absent from
`study` — which is exactly what `enable = lib.mkForce false` makes them — would
have failed.

Both states are live in this repo and they are not the same claim. The radios
are *absent*: study-offline.nix's forces make the modules that generate them
inert, so nothing is emitted at all. The data bootstrap is *masked*: it is
declared and switched off by name. A new `not_running` helper accepts either and
fails only on a real unit file, and it was tested against a fixture carrying one
of each rather than reasoned about:

    not_running  absent.service  ->  ok    (absent — nothing generated it)
    not_running  masked.service  ->  ok    (masked — symlink to /dev/null)
    not_running  live.service    ->  FAIL
    absent       masked.service  ->  FAIL  <- the bug

This is the same shape as everything else in this entry, one level down: a check
that cannot distinguish two states will eventually be asked to.

### Nine smaller findings

**`nrs` and `nrt` could silently rewrite `flake.lock`.** The `justfile` states
the rule in bold — *"Nothing in this file may change `flake.lock` except
`just lock`"* — and every recipe honours it. The two aliases README.md
recommends *as the ergonomic equivalent* did not. Measured, with `sops-nix`
dropped from the lock (the state this repo shipped in once): `just switch` exits
1 and leaves the file alone; `nrs` exited 0, emitted a system drv, and rewrote
it. Both carry `--no-update-lock-file` now. `nfu` deliberately does not — that
is its job.

**`~/Scripts/.git/hooks` was on `$PATH` in every shell.** `home/common.nix`
filtered hidden directories with `-not -path '.*'`, and `find -path` matches the
*whole* path, which always begins `/home/…` — so the glob could never match and
the filter did nothing. Measured against a fixture:

    as written  (-not -path '.*')    Scripts  .hidden  .git  .git/hooks  normal
    as fixed    (-not -path '*/.*')  Scripts  normal

Git hooks are executables named `update`, `pre-commit`, `post-checkout` and
`prepare-commit-msg`, and `update` is a real command on several distros. Four
characters.

**waybar rendered a point smaller than everything it matched.** Nix `/` on two
integers is integer division, so `font.sizes.desktop * 4 / 3` truncated `10.667`
to `10`. The reason nobody saw it: the formula arrived in the commit that fixed
waybar's hardcoded `12px`, and at that moment `uiSize` was 9, where `9 * 4 / 3`
is exactly 12 — README.md's own worked example. The truncation appeared one
commit later when `uiSize` dropped to 8. Now `* 4.0 / 3`, and there is an
independent check on the result: stylix emits its own `* { font-size: 8pt; }`
above this block, and 8pt at 96 DPI **is** 10.667px. Two derivations that never
consult each other now agree to the digit; before, this rule came later in the
cascade and quietly overrode stylix's correct value.

**The three `emacs-scratch` window rules could never match.** They matched
`class:^(emacs-scratch)$`, but `modules/home/scripts.nix` creates the frame with
`(make-frame '((name . "emacs-scratch") …))` and an Emacs frame's `name` sets
the **title**. Under Wayland the app-id of every Emacs frame stays `emacs`;
Emacs exposes no per-frame app-id at all. So `Super+Shift+grave` opened a frame
meant to be a centred 1100x600 float and got it tiled at the default size, with
three lines asserting otherwise. `scripts.nix` had the answer in it the whole
time — it focuses the same frame with `hyprctl dispatch focuswindow
"title:$NAME"`, and selects the terminal scratchpad on `.app_id` while selecting
the Emacs one on `.title`. Now `title:` in all three, **plus the matching niri
rule that had never existed** — that session had no rule for this frame at all.

**README's CI table was wrong in two of four "by hand" rows**, both in the same
direction: claiming a local command matched a CI job when it did not. `lint`
offered `just check`, which is `nix flake check` — all four checks including the
40-minute closure build. `eval` offered `just eval`, which ran one of that job's
three steps; proven by construction, deleting the whole `specialisation.focus`
block left `just eval` **green** while CI went red. Fixed by making the commands
true rather than by softening the claim: `just lint` is new, and `just eval` now
runs all three steps.

**`font_size = 64`** in `modules/home/lock.nix` was the one number in the repo
with no argument beside it, in a repo that claims Plasma's toolbar font is the
only exception. It stays a literal — the lock clock is read at a glance from
across a room, not at a desk, and tying it to `uiSize` would mean fixing a
cramped panel also resizes the lock screen — but it now has the paragraph the
claim owes it.

**Two file headers still said there was one specialisation**
(`hosts/desktop/configuration.nix:3`, `modules/system/study-offline.nix:3`),
118 lines above the block declaring two. Both were made stale by (q)'s `focus`
commit, which updated the README and the body of the very file whose line 3 it
left contradicting the change.

**`sops-nix` stays inert, and now says so.** `.sops.yaml` still holds the
literal `age1REPLACE_WITH_YOUR_HOST_AGE_PUBLIC_KEY`, `secrets/secrets.yaml` does
not exist, and every `sops.secrets."…"` block is commented out — while
`flake.nix:8-17` deletes `nixpkgs-unstable` for being *"a second fetch, a second
lock entry and a second full evaluation on every rebuild, bought for zero call
sites."* The two got opposite verdicts in the same repo. The verdict is
unchanged and the reasoning is now written down rather than implied; see
README.md.

**`palette.nix` changed the rendered theme and nothing said so.** Entry (n)
recorded the mechanism and not the outcome. The old hand-written literals were
`#7aa2f7` (accent) and `#414868` (dim); neither appears anywhere in
`tokyo-night-dark.yaml`, and the value used for `fg`, `#c0caf5`, is that
scheme's `base08`. Deriving the roles from `config.lib.stylix.colors` — which is
unambiguously right, and is what that file argues for — therefore moved three of
the four colours:

| role | was | is |
|---|---|---|
| accent | `#7aa2f7` | `#2ac3de` |
| dim | `#414868` | `#444b6a` |
| fg | `#c0caf5` | `#a9b1d6` |

Not a defect — the derivation is correct and the literals were the bug. But
**the borders are cyan now, not blue**, and that is a visible change to how the
machine looks which arrived as a side effect of a commit about provenance.

### The three commits that shipped without an entry here

`48be4fb`, `9e34074` and `2cc0946` updated neither this file nor `README.md`, in
a repo whose changelog discipline is real and documented. That lapse is the
mechanism behind the two stale headers above and behind the whole first section
of this entry — not carelessness, just the changelog falling behind the tree.
They are logged here retroactively:

| Commit | What it did |
|---|---|
| `48be4fb` | the module that failed to load, and the sub-feature nobody required |
| `9e34074` | the menu entry the previous bump could not have carried |
| `2cc0946` | set `EMACS_MODULE_GROUPS = "essentials"` in both session-variable paths — the commit this entry's second section is about |

### `emacs-config` bumped, and the audit's reasoning for it had already expired

The audit called `just update-emacs` cosmetic, on solid evidence: the lock
pinned `9f865ac`, whose tree is byte-identical to `c71e2c5` because the 14
intervening commits are grafted-in ancestry from the archived repo. Verified
independently here — both are `7bc60caeccf0ef9b87b41a0978634c6995cc1383`.

It is no longer the tip. The bump landed on **`7e39fbf`**, from later the same
day, and the narHash moved with it — so this is not the no-op the audit
described. What changed:

    LICENSE | 675 ++++++++++++++++++++++++++++++++++++++++++++++++
    1 file changed, 675 insertions(+)

A GPL-3.0 licence file. No module, no `init.el`, no flake change. **The input
hash changes, so the closure rebuilds; nothing it builds behaves differently.**

Recorded at this length because the general point outlives the instance: a
"cosmetic bump" is a claim about two specific revisions, and it stops being
true the moment either end moves. The evidence gets re-derived at bump time or
it is not evidence.

### What was actually run, and the two bugs it found — both in the checker

Every gate in `.github/workflows/check.yml` was run against this tree before it
shipped — `lock`, `lint`, all three steps of `eval`, the closure build, and
`tools/check-closure.sh` against the built artifact. The lock pins all six
inputs, `statix` and `deadnix` exit 0, both specialisations evaluate by name,
and the closure check ends `closure check passed` on 86 assertions.

It did not end that way the first time, and the story is the useful part.

`tools/check-closure.sh` first got the treatment it exists to give everything
else: a fixture builds a fake closure with the layout the script asserts, then
mutates it one regression at a time — a live `dhcpcd.service` in each
specialisation, `recoll` back in each of the three profiles, `firefox` as a
system package, a live `sshd.service` in the airgap, an unmasked
`shaulos-data-bootstrap.timer`, a deleted anchor — and requires the script to go
**red** for each. That is not a flourish. A closure check is made almost
entirely of absence assertions, and an absence assertion that has never been
*seen* to fail is indistinguishable from one that cannot.

**Bug one, found by the fixture.** The paired present-test for `pdftotext` ran
against the base and `focus` profiles and skipped `study`'s, so every seforim
absence asserted about the airgap had no anchor beneath it and would have stayed
green against a mistyped path. `poppler-utils` is in
`modules/home/toolkit.nix`'s `always` list rather than in `offInStudy`, so the
airgap keeps it and the anchor belongs there. Fixed.

**Bug two, which the fixture could not find, because the fixture had it too.**
The suite went 17/17 green. The real closure then reported both
`shaulos-data-bootstrap` units as **live in the airgap** — the one claim in this
whole entry that would have meant the machine phones home.

It does not. `makeUnit` (`nixos/lib/systemd-lib.nix:76`) does not emit
`ln -s /dev/null` where the unit sits. It builds a store path named
`unit-<name>-disabled` and puts the `/dev/null` symlink *inside* it, so the
closure holds two hops:

    /etc/systemd/system/<name>
      -> /nix/store/…-unit-<name>-disabled/<name>
           -> /dev/null

The helper compared `readlink "$path"` against `/dev/null`. Plain `readlink`
prints only the first hop — the `-disabled` store path — so the comparison never
matched and a correctly masked unit was reported as running. `readlink -f`
resolves the chain to its end and both forms now pass, with a zero-length unit
accepted as inert for good measure.

The fixture missed it because the fixture wrote `ln -s /dev/null` directly:
**it encoded the same wrong belief the checker did, so it confirmed the belief
instead of testing it.** That is the failure mode this repo keeps rediscovering
in new clothes — a check that agrees with its author rather than with the
machine — and the only thing that caught it was building the closure and asking
the artifact. Which is precisely the argument for having a `build` gate at all,
demonstrated at this repo's own expense. The fixture now models the two-hop form
taken from the artifact, and carries mutations for both masking shapes and for a
`-disabled` path that has been quietly refilled with a real unit: 19/19.

The fixture itself is deliberately not committed: it hard-codes the layout it is
testing, so a copy in-tree would be a second source of truth about the closure
shape that nothing keeps in sync with the first. Its value was never the file —
it was being forced to write down what "off" looks like, and then discovering
that what got written down was wrong.

### The two packages your machine compiles, and the one it must keep

Building the closure surfaced something no source reading would have: a rebuild
was 19 minutes in, still compiling `graphite`, with nothing else left to do. So
every package in the creative suite was asked the only question that matters for
build time — *does `cache.nixos.org` have a substitute?* — by fetching each
derivation's `.narinfo` against the pinned nixpkgs (`445d861c`).

The answer is not the one "big packages are slow" predicts. `krita`, `digikam`,
`darktable`, `rawtherapee`, `scribus`, `calligra`, `gimp-with-plugins`,
`tor-browser` (336 MB), `vlc`, `audacity` — all substituted. They cost a
download and nothing else. Exactly two are not:

| | | |
|---|---|---|
| `graphite` | 404 | Rust, an `0-unstable-2026-05-02` snapshot — Hydra does not build unstable snapshots, so this compiles locally forever |
| `inkscape-with-extensions` | 404 | C++; plain `inkscape` was checked too and is also 404, so dropping the wrapper buys nothing |

Both are commented out in `modules/home/toolkit.nix`, with the measurement and
the restore note beside them. `inkscape` is the one real loss — for vector work
nothing else in the list replaces it; `graphite` is an alpha-stage editor that
does the same job less completely.

**`texlive.combined.scheme-full` stays**, and that is the interesting half. It
is the largest single thing in the closure and it is *never* substituted —
`texlive.combined.*` is a union derivation, so scheme-full, scheme-medium and
scheme-small all 404 alike and all build locally. Removing it would have been
the obvious economy and it would have been a new instance of this entry's own
headline bug, pointing the other way:

- `essentials/07-latex.org` — a full AUCTeX setup
- `essentials/05-org.org:108` — `(setq org-latex-compiler "lualatex")`
- `essentials/05-org.org:111` — `org-latex-pdf-process` shells out to `latexmk`

All of that **loads** under `EMACS_MODULE_GROUPS = "essentials"`. Dropping TeX
leaves live code calling a binary that is not installed, failing at export time
with nothing in the config admitting it. Provisioning without code and code
without provisioning are the same defect; this entry opened by fixing the first
and would have closed by shipping the second.

`scheme-medium` is the real economy and is deliberately **not** taken here,
because it is unverified: it would have to be *shown* to carry `latexmk`,
`lualatex` and `fontspec` — `05-org` keeps `org-latex-packages-alist` to
fontspec alone — before the swap is anything better than a guess. Noted in the
file as the next move rather than guessed at.

### Still yours

- **GitHub's default branch is `master`**, five months and 54 commits stale.
  Anyone landing on the repo page — including you, from a phone — reads a config
  that predates the entire 2026-08 overhaul.
  `gh repo edit --default-branch specializations`.
- **`Super+Shift+grave`.** The `title:` fix is derived from Emacs's and
  Wayland's matching semantics and corroborated twice in `scripts.nix`, but it
  is the one change here not observed on hardware. Press the key.

---

## 2026-08-13 (r) — the two surfaces (q) missed, one of which was never written down

Entry (q) was rebuilt on the machine and the reply was "nothing changed at all."
Both halves of that turned out to be worth chasing, and neither was a fault in
(q)'s reasoning about sizes.

**Nothing had re-read anything.** Generation 230 was correct on disk — every
file checked: `/etc/fonts/local.conf` at 9, `kdeglobals` at `Noto Sans,8`,
`foot.ini` at `size=9`, `user.js` at `"0.8"`, waybar at `10px`, and a fresh
`fc-match Monospace` answering 9 where it used to answer 12. The uptime was six
days and fourteen hours. Font sizes are read once, at process start, so
`plasmashell` and `kwin_wayland` were holding an Aug 6 `kdeglobals` and the
Emacs daemon had resolved fontconfig's default the week before. The one process
that *had* restarted — Firefox — was visibly smaller, which is what confirmed
the mechanism. This is now stated in the README, because "it applied and you
cannot see it" is the expected outcome of a switch, not a symptom.

**konsole was never in this repo.** `grep -rni konsole` over the tree returned
nothing and `~/.local/share/konsole/` was empty, while `pgrep` under the running
Plasma session found konsole and did not find foot. The terminal actually in use
was outside the derivation entirely. (q) fixed three bad literals; this was the
harder case, because a literal leaves something to grep for and an undeclared
program leaves nothing. It is `modules/home/konsole.nix` now, at
`stylix.fonts.sizes.terminal`, the same size foot gets — and its default profile
is declared, because `overrideConfig = true` rewrites `konsolerc` on every
activation and a profile picked in the settings dialog is reverted by the next
rebuild. That is the `kxkbrc` keyboard bug from entry (p), in a second file.

**Emacs: (q) got the right answer for the wrong reason.** (q) recorded that
Emacs "stated no font anywhere, checked" and would therefore inherit the new
fontconfig default. The first clause is false. `01-ui.el` in the emacs-config
repo states `:height 90` — but inside `(when (display-graphic-p) …)` evaluated
at *load* time, and under `emacs --fg-daemon` there is no frame yet, so it is
nil and the block never runs. With `EDITOR=emacsclient` every frame is a daemon
frame, so that statement has never executed on this machine. A grep finds the
size; only running it shows the size is dead code.

Measured, on the real config: `family=DejaVu Sans Mono height=90 pixelsize=12`.
Two more things fall out of that. The family is wrong — `01-ui.el` searches for
`"JetBrains Mono"` with a space, and `fc-list` calls the installed patch
`JetBrainsMono Nerd Font` without one, so the search fell through four entries
to DejaVu. And 90 is a literal in a repo that knows nothing about this panel.

`modules/home/emacs/default.nix` now generates `99-local-fonts.el` into the
module tree — numbered to load after `01-ui.el`, setting family and height from
`uiSize`, and hooking `after-make-frame-functions`, which is the half
`display-graphic-p`-at-load-time cannot do. Emacs still names its own size; the
number is this repo's. Verified by loading the generated file into a live frame:
`DejaVu Sans Mono 12px` → `JetBrainsMono Nerd Font 11px`, and daemon frames go
from fontconfig's old 16px to 11px.

`nix flake check` passes. As with (q), **nothing here is applied until the next
switch, and nothing is visible until you log out** — which is the entry's own
first finding.

---

## 2026-08-12 (q) — the text was too big, and the three surfaces that decided it derived from nothing

The report was "text on my laptop is too big, always" — everything, not one app.
It was accurate, and the reason is not the one the symptom suggests.

### It was never a DPI problem

`eDP-1` is 1366x768 over 344x193 mm, which is **101 real DPI** against the 96
this machine forces in `kcmfonts`. Every scale factor was already 1 —
`QT_SCALE_FACTOR`, `GDK_SCALE`, `GDK_DPI_SCALE`, `KScreen.ScaleFactor`,
`_JAVA_OPTIONS`, and niri's and Hyprland's `scale 1.0`. So a point was rendering
*slightly smaller* than its physical size and nothing was mis-scaled. Reading
down the scale settings — which is where "too big" sends you — finds nothing,
because there was nothing there.

The problem is a pixel budget. 768 rows is not many, and the Nix-managed sizes
were already modest: 9pt applications and desktop, 10pt terminal, verified live
in `kdeglobals`, `gtk-3.0/settings.ini` and `foot.ini`. What was big was
everything those three options did not reach — and that turned out to be most of
what the day is spent in.

### Three surfaces, all at their vendors' defaults, all ≈12pt

- **Emacs stated no font at all.** Not in `init.el`, not in `early-init.el`, not
  in one of the 29 modules the loader requires — grepped for `set-frame-font`,
  `default-frame-alist`, `:height` and `face-attribute` across every file the
  config ships. So Emacs asked fontconfig for an unsized `Monospace`, and
  fontconfig's built-in default is **12.0pt**: a third larger than the desktop
  around it, in the application this machine mostly exists to run.

  That default is reachable from no NixOS option. `fonts.fontconfig` has
  families — stylix sets those — and hinting, and no size. It now comes from
  `fonts.fontconfig.localConf`, as `<edit name="size" mode="append">`. `append`
  is what makes it a *default* rather than an override: it adds the size after
  any the application already asked for and fontconfig reads index 0. Checked
  both directions with `FONTCONFIG_FILE=… fc-match -v` — an unsized `Monospace`
  resolves to the new number, `Monospace-14` still resolves to 14.

- **Firefox was pinned at `layout.css.devPixelsPerPx = "1.0"`**, a literal, while
  the desktop around it ran at three quarters of stylix's default. It is the one
  surface where the knob cannot be a point size: Firefox sizes neither its chrome
  nor a page in points, and `font.size.variable.*` is overridden by every site
  that styles its own text, so it would have shrunk roughly the pages that needed
  it least. The ratio is against 10 — stylix's default `desktop` size, and
  therefore the density Firefox's chrome and the 16px CSS default are drawn for.

- **waybar's `font-size: 12px` was labelled a deliberate exception** — the
  comment above it argued the bar needed 12 for the Nerd Font glyphs while
  `stylix.fonts.sizes.desktop` was 9. It was not an exception. CSS fixes 4 pixels
  to every 3 points, so **9pt is 12px exactly**: the literal was the derived
  value written in the other unit and then pinned by hand. That is the expensive
  kind of hardcode — it rendered identically, so nothing could tell you, and it
  was the one surface that would not have followed when the desktop size changed.

### One number

`uiSize` in `modules/system/appearance.nix`, in points, with the arithmetic and
the floor written above it. `uiSize` for Plasma, GTK, dunst and waybar;
`uiSize + 1` for foot and the fontconfig default, because monospace reads smaller
than sans at equal points; `uiSize / 10` for Firefox. Set to **8**, from 9.

`home/shaul.nix` loses its three `stylix.fonts.sizes.*` lines. They were the same
fault as the Qt variables in entry (h), one layer over: stylix's home-manager
integration copies all four sizes down from the system config with `mkDefault`
(`homeManagerIntegration.followSystem`, on by default), so the home-side
statements were shadowing the value they existed to receive. Deleting them
changes nothing but which file you edit — confirmed by evaluating
`home-manager.users.shaul.stylix.fonts.sizes`, which reads `8/8/8/9` with
nothing stating it there.

`forceFontDPI` stays 96 and the scale factors stay 1, and both now say why in
the file: they are the denominator that makes a point mean 4/3 of a pixel, not a
second size knob. Lowering one of them instead would arrive at the same effect
twice, and would move Qt without moving GTK or foot.

Verified: `nix flake check` green (lints, both specialisations, the closure),
and the built system's `/etc/fonts/local.conf`, `foot.ini` (`size=9`),
`kdeglobals` (`Noto Sans,8`, toolbar `7`), waybar CSS (`10px`) and the Firefox
profile (`"0.8"`) all read the derived values. **Not switched** — the running
generation is 229 from Jun 10, two months behind this tree, so applying it is a
`just switch` with more in it than this change.

---

## 2026-08-07 (p) — the first pass with a NixOS machine under it

Every entry above this one was authored on Windows, and each says so. This one
was not: it was run against `nixos-26.05` on the laptop, with `nix eval`, `nix
build`, `statix`, `deadnix`, `niri validate`, and — for the findings that no
evaluator can reach — the actual binaries out of the actual store paths.

That distinction is the entry. Entry (o) built the CI that would have caught
this class of thing, and (o)'s own gates had never been green, so what it
proved was nothing.

### The lock still pinned four of six

(o) opens by saying `flake.lock` accounts for four of six inputs and that "the
repo as committed does not evaluate". It is written in the past tense. It was
still true: the lock in the tree pinned `nixpkgs` at **`nixos-unstable`**, not
`nixos-26.05`; `stylix` at **`danth/stylix`**, not `nix-community`;
`home-manager` at no branch at all; and it had no entry for `sops-nix` or
`emacs-config`. `nix flake check` did not fail a gate — it failed to start.

Re-locked. All six inputs, on the branches `flake.nix` names. **With that one
file fixed the whole configuration evaluates**, which is the first time that has
been true of this repo, and everything below is what was found behind it.

### `statix check .` exited 1, so the `lint` gate could not go green

34 findings, in eleven files, and 33 of them were `repeated_keys` — W20's
objection to `services.a = …; services.b = …;`, i.e. to the house style of
nixpkgs itself, including in `hardware-configuration.nix`, which is generated
and cannot be edited to satisfy it. A gate that fires on generated code teaches
you to pass `--ignore`.

`statix.toml` now disables that one lint and argues why; the other nineteen stay
on, and the four genuine findings they made are fixed in the tree. `statix` and
`deadnix` both exit 0.

### The class the evaluator cannot see: names inside strings

Nix checks that `pkgs.foo` exists. It does not check that
`${pkgs.foo}/bin/bar` does, because that is a string. Four bugs lived there,
none of which any amount of `nix eval` would ever have found:

- **The wallpaper never loaded, in either session.** nixpkgs 26.05 renamed
  `swww` to `awww`. `pkgs.swww` is an alias that still evaluates — it prints a
  rename warning and hands back the awww derivation — but the binaries are
  `awww` and `awww-daemon`. So `${pkgs.swww}/bin/swww-daemon` was a store path
  that does not exist, and the `until ${pkgs.swww}/bin/swww query` that follows
  it could never succeed: both compositors spawned a shell at login that spun a
  half-second loop for the life of the session with no wallpaper on screen.
- **`pgrep -x Hyprland` cannot match, and never could.** `pgrep -x` matches
  `comm`, which Linux takes from the basename of the *executable*, truncated to
  15 characters. nixpkgs wraps Hyprland, so the process is `.Hyprland-wrapped`
  and comm is `.Hyprland-wrapp`; `exec -a` rewrites argv[0] so that every human
  check — `ps`, the process list — agrees it is called Hyprland. niri is not
  wrapped, which is why one branch of the same `if` worked and the asymmetry
  was invisible. Under Hyprland: `spotlight` and `teleport` refused with "this
  session is plasma", both scratchpad keys spawned a *new* terminal on every
  press instead of focusing the existing one, and `session-dpms` matched
  nothing, so the 10-minute listener never blanked the panel — a bug whose only
  symptom is a flatter battery in the morning. Detection now reads
  `NIRI_SOCKET` / `HYPRLAND_INSTANCE_SIGNATURE`, which the compositors export
  for exactly this and which `niri msg` and `hyprctl` already depend on.
- **waybar is wrapped too**, so `spotlight`'s `pkill -x waybar` killed nothing
  and its `pgrep -x waybar` then found nothing and started a second bar. The
  two halves failed in opposite directions and added up: every spotlight round
  trip left another waybar running.
- **`plasma-wipe` had never run to completion.** `killall` is psmisc, which
  nothing here installs, so the line failed with "command not found" and
  `|| true` swallowed it — leaving the wipe to run against a live Plasma that
  rewrote its config on exit, which is the one thing the script exists to
  prevent. Its argument order was also not `killall`'s syntax, and matching
  those two processes by name does not work on NixOS for the reason above.

### Verbs that do not exist

Checked against the real `niri msg action` and `hyprctl` on this machine:

- `niri msg action focus-window` takes `--id` **and nothing else**. Both
  scratchpad toggles called it with `--app-id` / `--title`, so under niri the
  scratchpad opened once and the key did nothing ever after — the spawn branch
  is the one that works, so it read like a missing hide half rather than an
  error.
- `niri msg action set-window-opacity` is not an action at all.
- `hyprctl dispatch setprop …` puts a top-level hyprctl command behind the
  dispatcher; `setprop` is `dispatch`'s sibling. And `opaque` forces a window
  *fully opaque* — the opposite of swallowing it — while `toggle` is not a
  value. `swallow` was wrong in every line that touched a compositor; only
  `"$@"` ever ran. It now restores from a `trap`, so an interrupted command
  cannot leave the terminal stuck invisible.

### `just switch` ended the session under niri and Hyprland, and only there

Reported from the chair as "it reboots when it rebuilds", in the two tiling
sessions and never in Plasma. It is neither a reboot nor a crash — the
graphical session is torn down and `display-manager.service`, which is
`Restart=always`, brings SDDM straight back.

Three facts, and the bug is entirely in how they compose:

1. **`switch-to-configuration` restarts *user* units**, not only system ones —
   it builds `units_to_stop` / `units_to_restart` for the per-user manager and
   drives them over D-Bus before running home-manager activation.
2. **Under uwsm the compositor is a user unit.** `programs.uwsm` ships its units
   via `systemd.packages`, so they land in `/etc/systemd/user` and NixOS owns
   them — `wayland-wm@Hyprland.service` *is* the running Hyprland. Plasma is not
   a user unit at all; SDDM execs `startplasma-wayland` into a session scope
   switch-to-configuration never looks at. That is the entire asymmetry.
3. **Restarting one of them ends the session rather than the unit.** Four carry
   `OnSuccess=`/`OnFailure=wayland-session-shutdown.target` at
   `replace-irreversibly`, `wayland-wm@.service` has
   `PropagatesStopTo=graphical-session.target`, and `wayland-session@.target`
   has `BindsTo=graphical-session.target`. `wayland-wm-env@.service` is the
   worst: `RefuseManualStop=yes`, so the restart request *fails* and the failure
   fires the same irreversible teardown, with `ExecStopPost=uwsm aux cleanup-env`
   erasing the session environment on the way past.

The trigger is the unit *files* changing — i.e. whenever the uwsm store path
moves, which is `just update` rather than every rebuild. That is why it read as
intermittent.

Fixed with the measure NixOS already applies to itself for the same reason
(`systemd.services.systemd-user-sessions.restartIfChanged = false; # Restart
kills all active sessions.`): a drop-in setting `X-RestartIfChanged=false` on
those four units, so a switch leaves a running session alone and the new units
apply at the next login — the only moment a compositor's unit definition can
honestly change. One drop-in covers **both** compositors, because uwsm names the
instance after the binary and both are instances of the same template
(`wayland-wm@Hyprland` / `wayland-wm@niri`, confirmed with `uwsm start -n -o`
against each `binPath`).

Written as `systemd.user.units` with verbatim `text` rather than the obvious
`systemd.user.services.<n>.restartIfChanged = false`, and that is not style.
systemd-lib builds every generated service's environment as
`cfg.globalEnvironment // def.environment`, so the high-level spelling also
emits `Environment="PATH=…"` — five entries — plus LOCALE_ARCHIVE and TZDIR.
`wayland-wm@.service` takes its real environment from
`EnvironmentFile=-%t/uwsm/env_session.conf`, and systemd applies `Environment=`
*over* `EnvironmentFile=`, so that spelling would have fixed the rebuild by
handing the compositor — and everything any keybind spawns — a five-entry PATH.
Verified by reading the generated drop-in both ways.

### Three references to a program nothing installed

`pavucontrol` is waybar's `on-click` for the volume module and has a float rule
in both compositor configs. No list installed it. Clicking the bar did nothing.

### `backupCommand = "true"` reads like a boolean and is not one

It takes a *command* to run on each existing file home-manager is about to
replace. `true` is the shell builtin that succeeds and does nothing — so every
colliding dotfile in `$HOME` was "backed up" by doing nothing to it and then
overwritten, with no copy and no warning. The one activation in the machine's
life that meets your pre-Nix dotfiles is the one that silently destroyed them.

That also contradicted this repo's own position one directory over:
`modules/home/emacs/default.nix` goes to the trouble of *moving*
`~/.config/emacs/modules` aside and argues that a hand-edit in there could be
the only copy. `backupFileExtension = "hm-bak"` keeps the file. The hand-rolled
`force-clean-git-files` activation went with it — it `rm -f`'d two paths in the
entry scheduled immediately *before* the mechanism that would have kept them.

### Smaller, and all of them real

- `myConfig.flakePath` was `/home/shaul/nixOS_config-specializations` — the name
  of the *branch*, not of any directory that has ever existed. `nrs`, `nrt` and
  `nfu` exist to work regardless of the current directory and resolved to a path
  with no flake in it, from everywhere. `just` uses `.#desktop` and is only run
  from the checkout, which is exactly why nothing caught it.
- yazi's video opener called `vlc`, which is in `offInStudy`. It was the one
  binding in this config that broke precisely when you booted the
  specialisation. It calls `mpv` — the "one local media player" study is
  documented to keep — like every other opener already called something in
  `always`.
- `toggle-scratchpad-emacs` shelled out to `${pkgs.emacs}`: plain X11 emacs-30.2
  from nixpkgs, not the `emacs-pgtk-with-packages` the daemon runs. A second
  entire Emacs in the home closure to run one `emacsclient`, against a server it
  is only compatible with by coincidence of version.
- The uwsm entry started `${pkgs.hyprland}/bin/Hyprland`, the raw store binary.
  NixOS's Hyprland module builds `security.wrappers.Hyprland` with
  `cap_sys_nice+ep` because Hyprland asks for SCHED_RR at startup, and a store
  path cannot carry file capabilities. So the two Hyprland entries in the same
  greeter menu did not start the same thing. It is `/run/wrappers/bin/Hyprland`.
  niri's `binPath` now comes off `programs.niri.package` rather than a second
  statement of which niri this machine runs.
- `noaspell` in `recoll.conf` was indented four columns past its neighbours, and
  indentation is how that format spells a *continuation of the previous value*.
- **`just fmt` formatted nothing.** A bare formatter binary is no longer a
  working `formatter` output: `nix fmt` runs it with the paths you passed, you
  normally pass none, and nixfmt 1.4 with no file arguments reads *stdin* — so
  the recipe printed `<stdin>:1:1: unexpected end of input`, exited 0, and left
  the tree alone. Fourteen files were unformatted, which is how long that had
  been going on. `formatter` is `pkgs.nixfmt-tree` now (nixfmt behind treefmt),
  which walks the tree when invoked with no arguments, and the whole repo is
  formatted. `pkgs.nixfmt-rfc-style` was separately an alias that warns on
  every evaluation touching it, dev shell included.
- `just fmt` was also the one recipe missing `--no-update-lock-file`, which is
  the single rule stated at the top of the justfile. `nix fmt` resolves the
  flake.
- `programs.yazi.shellWrapperName` warned on every rebuild; stated explicitly,
  keeping `yy`.
- `screenshot-edit` treated cancelling the region select — Escape, the common
  path — as a capture, running `grim -g ""` into a session with no terminal to
  see the error, after `mkdir -p` had already created `~/Pictures/Screenshots`.
- `volctl` had no default case, so any typo exited 0 having done nothing.

### What is verified, and what still is not

`nix flake check` passes: `statix`, `deadnix`, the emacs-config build, and the
toplevel closure. The `study` specialisation evaluates. The generated
`niri/config.kdl` passes `niri validate`. Every `${pkgs.X}/bin/Y` in the tree
was resolved against the built store path. `tools/check-closure.sh` was run
against the real artifact rather than trusted.

Unchanged: CI still cannot tell you whether the system *switches*. The greeter,
activation, and everything that only happens on real hardware are still yours,
and the checklist at the bottom of this file still stands.

---

## 2026-08-06 (o) — nothing had ever built this repo

The Lamdan report's biggest finding ended on a diagnosis rather than a defect:
*"That's not carelessness; that's a missing CI job."* It was written about the
elisp — `tools/verify.sh` byte-compiled every module, was wired to nothing that
runs, and 1,569 lines of the seforim system stopped loading for weeks with no
build going red anywhere. Entry (a) fixed the modules and entry (b) moved the
config to `emacs-config`, **where it got the CI job**.

The diagnosis was about the repo. The fix went to half of it.

### The bill was already in the tree

`flake.nix` declares six inputs. `flake.lock` pins four. `sops-nix` and
`emacs-config` were added in entries (b) and (c) and never locked, so **the
repo as committed does not evaluate** — not "builds something slightly stale",
does not evaluate.

This is written down. Step 1 of the checklist below is `nix flake lock`, in bold,
with *"nothing will evaluate until this runs"* next to it. And that is exactly
the shape the report kept naming: a check you have to remember is a check that
breaks quietly. Fourteen entries were authored on a Windows box with no Nix on
it, against a flake that did not evaluate, and the only thing standing between
that and a bad afternoon was a line in a markdown file.

### Four gates

`.github/workflows/check.yml`, cheapest first, each strictly stronger than the
last, every one of them a command you can also run by hand:

| Gate | ~ | What it proves | By hand |
|---|---|---|---|
| `lock` | 1m | the lock accounts for every input | `nix flake metadata --no-update-lock-file` |
| `lint` | 2m | statix and deadnix are clean | `just check` |
| `eval` | 5m | the module system evaluates; `study` is the only specialisation | `just eval` |
| `build` | 40m | the closure builds, and is the machine README.md describes | `just closure` |

`eval` is the one that earns its runtime. Forcing the toplevel's `drvPath` walks
the entire module system — every option type, every `pkgs.<name>`, both
compositors, plasma-manager, home-manager, the specialisation — and builds
nothing. Every build-blocking bug this repo has actually shipped is in that net:
`awww` for `swww`, `gtk.gtk4.theme = null`, `kb_options` where niri's KDL wants
`options`. Three eval errors, none of which needed a byte downloaded to find,
all three of which reached the machine.

`lint`, `eval` and `build` all `needs: lock`. An unlocked input is then **one**
red job and three skipped ones, rather than four identical failures with the
cause buried in each — and 40 minutes of runner time not spent proving something
about a flake that cannot resolve.

### `--no-update-lock-file`, on every invocation

That flag is the `lock` gate, and it is on every nix command in every job and on
every `justfile` recipe that touches the flake — including `switch`, `test` and
`build`, which reach it through the same forwarding `emacs-dev` already used for
`--override-input`. One rule, and it fits in a sentence:

> Nothing changes `flake.lock` except `just lock`.

Without the flag, nix resolves an input the lock does not pin, writes the entry
and carries on — which is precisely how a six-input flake with a four-input lock
sat here looking fine, and why the consequence is not merely a misleading green:
`just switch` would have put the machine on a system built from inputs nobody
had committed, silently. `just lock` prints the diff.

That does mean a `just switch` can now fail on a lock error where it used to
proceed. That is the trade, taken deliberately, and the error names the fix.

### `tools/check-closure.sh` — the gate that reads the artifact

`build` does not stop at "it built". It reads the result and asks whether the
README is true of it:

- **no browser is a system package, in either closure.** That is the rule
  `base-tools.nix` states, and it is the exact route `firefox` and `lynx` took
  into the airgap: a NixOS-level `programs.firefox.enable = true`, inherited by
  a specialisation that cannot subtract it.
- **`study` has no browser and no downloader in the home profile at all** —
  `lynx`, `qutebrowser`, `tor-browser` (both spellings nixpkgs has used),
  `firefox`, `aria2`, `yt-dlp`, `ytfzf`, `rclone`, `persepolis`.
- **`study` still has what it is supposed to keep** — one binary per clause of
  the README sentence: `rg`, `fd`, `nnn`, `pandoc`, `gcc`, `mpv`, and `emacs`.
  The airgap is only worth booting if it loses the things it exists to lose.

The presence tests are not padding, and this is the part worth arguing. An "is X
absent" test passes trivially when you are looking in the wrong directory, and a
check that cannot distinguish *absent* from *I could not find the profile* goes
green forever and reports nothing — which is the failure mode this whole entry
exists to kill, reproduced inside the tool built to kill it. So every absence
test is paired with a presence test in the same directory, and a missing
directory exits `2` as a hard failure rather than passing.

One property comes free and is worth naming, because it is finding 1.1's other
half: **CI checks out from git.** Six `.org` modules were once untracked —
invisible on the machine that already had them, simply gone on a fresh install.
An untracked `.nix` file cannot make a run pass here. The runner has never seen
it.

### Not a gate, on purpose

`nix fmt --check` is absent and stays absent. Nothing this config has suffered
was a formatting problem; the register of defect in this repo is *a claim that
is false*, not *a bracket in the wrong column*. A check that goes red for
cosmetics is a check people learn to scroll past, and the ones above are worth
more than that. `just fmt` stays a thing you run.

Also absent: a scheduled `nix flake update` PR bot. Bumping inputs is a decision
with a rollback attached, `just update` and `just update-emacs` are two words,
and a robot opening pull requests against a personal laptop config is ceremony.

### Rider — `nix develop` had been lying

README.md has claimed the dev shell carries `sops` and `age` for as long as
there has been a README, and `secrets/README.md`'s entire walkthrough is written
in terms of `sops` and `ssh-to-age`. None of the three were in `devShells`. Same
defect as a documented airgap with a browser in it, one order of magnitude down,
and found while writing the CI section that describes the shell. They are in it
now.

### Expect the first run to be red

`lock` will fail, and three jobs will skip. That is not the workflow being
broken; that is the workflow doing the only thing it was built to do, against a
tree that has been in this state since entry (b). On the machine:

```sh
just lock          # writes the sops-nix and emacs-config entries
just eval          # ~5 min, no build — the fast confirmation
git add flake.lock && git commit -m 'lock sops-nix and emacs-config' && git push
```

Then the four gates go green or they tell you something true. Either is progress
on fourteen entries of "authored off-machine, untested."

### Rider — `.gitattributes` pinned `*.sh` and not `*.yml`

That file exists because a CRLF shebang inside a Nix build costs you an hour and
reads like a nix bug. A workflow's `run:` block is a bash script with no shebang
to go wrong, so the CR lands *inside* the commands instead — `fi<CR>`, or a
trailing `\<CR>` that eats the next line — which reads like a nix bug for
exactly the same reason and takes exactly as long. This repo is edited from
Windows. `*.yml` and `*.yaml` are pinned to LF now.

**Cost.** One workflow file, one shell script, one new `checks` attribute
(`toplevel`), four new `justfile` recipes plus one flag on three existing ones,
three packages in the dev shell, two lines of `.gitattributes`, and about 40
minutes of GitHub Actions per push — cancelled automatically when you push
again. Nothing about the running system changes.

---

## 2026-08-06 (n) — Plasma had never been told about the keyboard at all

Follow-up to (m), and the more serious half of it. The question was "does the
Caps Lock remap even work in KDE — I had races there." It does not, and neither
does anything else, and it was never a race.

**Three facts, in order.**

1. KWin does not read `services.xserver.xkb`. NixOS does not export
   `XKB_DEFAULT_*` from it either — the NixOS wiki documents doing that by hand
   *precisely because* the console and some Wayland compositors ignore the
   option. So the statement (m) put in `desktop.nix` reaches the X server and
   stops there.
2. KWin reads `kxkbrc`.
3. `programs.plasma.overrideConfig = true` in `home/shaul.nix` means
   plasma-manager owns `kxkbrc` outright and resets it on every activation —
   and **no keyboard was declared**.

So Plasma, the *default* session, has been falling back to bare `us` with no
options. Set it in System Settings and it survives exactly until the next
`just switch`. That is the "race": not a timing bug, a value with an owner who
had no opinion, being restored to the default by something that runs later.

This is the palette finding one more time and in its purest form. niri and
Hyprland were configured, X was configured, and the one surface that was neither
declared *nor* left alone — because `overrideConfig` actively resets it — was
the session you are in most of the time.

`programs.plasma.input.keyboard` writes `LayoutList` and `Options` with
`ResetOldOptions = true`, so it is now the whole statement for KWin, and it
comes off the same `myConfig.keyboard` as the other three. Repeat delay and rate
went with it: Plasma had been on its own defaults for those too.

### `caps:escape` is gone

Your call, and it is worth recording that it was not the fix. Caps Lock had not
been unreliable, it had been *unstated in Plasma*, which is a different problem
and the one above. Caps Lock is Caps Lock and Escape is Escape now; restoring
the remap is one string in `myConfig.keyboard.options`, and it will behave the
same in all three sessions when you do — which was not previously true of it.

### `myConfig.keyboard` renders both spellings

xkb's own config format, niri's KDL and `hyprland.conf` take comma-joined
strings; plasma-manager's `input.keyboard` takes lists. Both are built in
`flake.nix`, so no consumer reformats a keyboard value — the same rule
`palette.nix` follows, and for the same reason: this repo has already paid once
for a consumer that reformatted a value slightly wrong, and the receipt was
`rgb(#7aa2f7)`.

**Still not claimed by anything, stated rather than guessed at:** the SDDM
greeter. It runs as its own user with its own `kxkbrc`, nothing here writes it,
and I have not verified which layout it ends up with. It matters only if your
password contains Hebrew.

**On the machine:** `just switch`, then log out and back in. In a Plasma
session, tap Left Shift then Right Shift and type — Hebrew. Then open System
Settings → Keyboard and confirm it reads `us, il` and shows the shortcut,
because that file is now generated and no longer yours to edit.

---

## 2026-08-06 (m) — the Hebrew toggle was sitting on the VT switch, and the keymap had a sixth copy

Not from the Lamdan report — you asked for it — but it landed straight on top of
the report's biggest structural finding, so it belongs here.

**The ask.** The Hebrew/English toggle was `grp:lctrl_lalt_toggle`. Ctrl+Alt is
the prefix the console VT switch is built out of (`Ctrl+Alt+F1..F12`), and
sharing a chord with the thing that takes your session away is a poor trade for
a key you press all day.

**The answer: `grp:shifts_toggle` — hold either Shift, tap the other.** The
reasoning, because "no conflicts" is a claim that has to be checked rather than
asserted:

- Super is `$mainMod` and carries about forty binds; Alt carries the resize
  layer; Ctrl+Alt is the VT switch. All three are spent.
- Caps Lock is already Escape, so `grp:caps_toggle` is spent too.
- `Super+Space` is FSearch, so `grp:win_space_toggle` is out; `M-SPC` is
  `just-one-space` in Emacs, so `grp:alt_space_toggle` is out.
- Scroll Lock, Menu and Break are the genuinely-unused keys, and this is a
  laptop — it may not have any of them.
- **The single-key options are a trap.** xkeyboard-config's `rctrl_toggle`,
  `lctrl_toggle` and `sclk_toggle` are written as
  `symbols[Group1] = [ ISO_Next_Group ]`, which *replaces* the key. Take
  `grp:rctrl_toggle` and Right Ctrl stops being a Ctrl key. That is spending a
  modifier to save a keystroke, and on this machine — Emacs, both hands, Caps
  already remapped — it is the wrong currency.
- `shifts_toggle` is `key <LFSH> { [ Shift_L, ISO_Prev_Group ] }` and
  `key <RTSH> { [ Shift_R, ISO_Next_Group ] }`. **Both keys keep their modifier
  role.** The toggle needs both Shifts and nothing else, which no application
  binds, and it works identically in Plasma, niri, Hyprland and at the greeter —
  which a compositor keybinding would not.

  (`grp:rctrl_rshift_toggle` is the runner-up and also keeps both roles, but it
  eats right-hand-only `Ctrl+Shift+X` — and `Ctrl+Shift+C`/`V` is how you copy
  out of foot.)

### The part that was not in the ask

`modules/home/keys.nix` is the file this repo wrote *because the keymap had five
hand-written copies*. It had a sixth. `modules/system/desktop.nix` was carrying

```nix
  services.xserver.xkb = {
    layout = "us,il";
    options = "grp:lctrl_lalt_toggle,caps:escape";
  };
```

— the same two strings, in the other module system, for XWayland, SDDM and the
X-only apps. Changing only `keys.nix` would have given you both Shifts in niri
and Hyprland and Ctrl+Alt at the greeter, with nothing anywhere to say so. You
would have diagnosed it by logging out.

A home-manager module and a NixOS module cannot read each other, so the shared
statement is in **`myConfig.keyboard`** (`flake.nix`) — the same reason
`seforimPath` is up there, and for the same reason: *"the two disagreeing
silently is precisely the class of failure this module was built out of."* The
repeat rates stay in `keys.nix`, because nothing outside a compositor config
reads them.

### And the guide had two typed sentences in it

The generated guide's keyboard table said `Layout toggle | Ctrl+Alt (NOT Caps
Lock, whatever the old guide said)` and `Caps Lock | Acts as Escape`. Both were
true, and both were hand-typed restatements of `keyboard.options` sitting
directly beside it — the one thing the guide is not allowed to contain. The rows
are generated from the option string now, through a small table of glosses; an
option with no gloss prints its own name rather than a neighbour's sentence. A
guide that says `grp:foo_toggle` is unhelpful; a guide that says "Ctrl+Alt"
while the config says both Shifts is the failure this whole mechanism exists to
prevent.

**On the machine:** `just switch`, then log out and back in — the X/SDDM half
only takes effect on a new session. Tap Left Shift, then Right Shift, and type;
you should get Hebrew. `Ctrl+Alt` should now do nothing except with an F-key,
where it belongs. Then check the greeter, which is the half that used to be a
separate statement.

---

## 2026-08-06 (l) — it is a laptop

The Lamdan report closed with two questions it could not answer from the repo.
This is the first one, and the answer is now in the file rather than in a
report.

The evidence pointed both ways and the report laid it out fairly: the host is
called `desktop`, it lives in `hosts/desktop/`, and
`hardware-configuration.nix` shows a swap *partition* and `kvm-intel` with
nothing battery-shaped in it — against `hardware.nix` saying "Laptop hardware",
configuring TLP with `START/STOP_CHARGE_THRESH_BAT0`, enabling thermald and
`powerManagement`, and Hyprland once hardcoding a 1366x768 panel. *"If it's a
desktop, the TLP battery-threshold block is configuring hardware that doesn't
exist."*

It is a laptop — one of several, some of which live on mains. So nothing is
deleted: the whole power stack stays, **including** the 40/80 charge
thresholds, which are precisely the half that only earns its keep on a machine
that spends its life plugged in. `hardware.nix` now says which of the two it
is, why the thresholds are the right trade here, and which two numbers to change
if that stops being true.

**Not acted on, deliberately, and both are recorded in the file:**

- `hosts/desktop/` and `networking.hostName = "desktop"` are now *known* to be
  misnomers rather than merely suspicious. Renaming a live machine's hostname
  touches ssh host keys, `known_hosts` and `myConfig.flakePath`; it is a
  deliberate act, not tidying, and it is yours to schedule.
- **"Several machines" is half the answer to the report's other closing
  question.** It changes nothing today — the repo has one host and building
  `hosts/<name>/` for a host count of one is the `lxqt`-branch mistake again —
  but `hardware.nix` is the file that has to stop being a singleton first, and
  it now says so at the top. Finding 1.1 was already resolved the way a second
  machine wants it: the Emacs config is a pinned flake input, so machine number
  two consumes it rather than forking it.

---

## 2026-08-06 (k) — two ports out of fifty-one, transcribed instead of derived

Entry (h) ended with this under *Noted, not changed*, because whether you want
phone pairing at all is a decision and a cleanup pass does not get to make it.
You want it. So:

`core.nix` opened TCP 22, 1714 and 1764, plus UDP 1714 and 1764. **1714 and 1764
are the two endpoints of a range.** KDE Connect uses all of 1714-1764 and picks
freely inside it, so this opened two ports out of fifty-one — pairing worked
only if both ends happened to land on exactly those two, and when it didn't, the
firewall looked configured for it. That is the palette-literal finding in its
smallest possible form: a fact copied by hand out of the thing that knows it,
and copied wrong.

`programs.kdeconnect.enable = true` in `desktop.nix` states the requirement
once — the upstream module contributes the whole range to
`allowedTCPPortRanges`/`allowedUDPPortRanges` and installs the app Plasma's
indicator talks to. No file in this repo names a KDE Connect port now.

### And it would have opened a hole in the airgap

This is the part that matters more than the ports.

`study-offline.nix` forced `allowedTCPPorts` and `allowedUDPPorts` to `[ ]`. KDE
Connect does not contribute to either of those — it contributes to the
**Ranges** options, which those two forces do not touch. Enabling it properly
would have left a 51-port range open in the specialisation whose stated
guarantee is "the firewall denies everything", and nothing anywhere would have
printed a word.

The two extra forces are the fix, but the reason is the general one: a backstop
that enumerates which *modules* to undo is not a backstop, it is a list you have
to remember to extend — the same fault the package rule exists to kill, one
layer over. The four forces are written in terms of the firewall's own surface,
so the next feature that wants a port cannot punch through the airgap by using
an option nobody thought to force.

**On the machine:**

```sh
sudo iptables -S nixos-fw | grep 17          # expect a 1714:1764 range, not two ports
# pair the phone: KDE Connect on Android, both devices on the same network
# then reboot into `study`:
sudo iptables -S nixos-fw | grep 17          # expect nothing
```

---

## 2026-08-06 (j) — the third sync client follows the other two

Lamdan 3.4, first bullet, taken to the end. The report found three tools for one
drive; commit (d) deleted `onedriver` and rewrote `file-sync.nix`, and kept
`services.onedrive` with a comment saying what it actually does. This deletes
that too, which was your call and not the config's.

`enable = true` does less than it looks like: it installs abraunegg's client and
defines a per-user unit, but the sync only runs for a user who has
interactively authenticated (`onedrive` once, for a refresh token) and started
their instance. **Nothing in this repo has ever done either**, on any machine,
since the initial import.

So it is finding 3.1 again — *a config knob with no call sites and no history of
changing was never a requirement, it was a hedge* — except this hedge was
charging rent. `study-offline.nix` carried a `lib.mkForce false` for it, so the
airgap had to remember to switch off a daemon that has never run. That force is
gone with it, and the file's own closing argument ("every line is a service or a
radio") is one line truer.

Re-adding it is one line, on the day you type `onedrive` and authenticate.

```
modules/system/data.nix          services.onedrive.enable deleted; the header
                                 now argues the deletion instead of the keep
modules/system/study-offline.nix one fewer mkForce
modules/system/services.nix      the pointer comment updated
hosts/desktop/configuration.nix  import comment
README.md                        layout + the `study` table row
```

**On the machine:** nothing to do. If you had somehow authenticated it, the
client is no longer installed — `onedrive --version` will stop resolving, and
`~/OneDrive` is left exactly where it is, because Nix never owned it.

---

## 2026-08-06 (i) — `spotlight` cached a fact the compositor was holding

Lamdan 3.4, fifth bullet: *"`spotlight` keeps toggle state in
`/tmp/spotlight-state`. If the toggle ever desyncs from reality it stays
desynced until reboot."*

It is worse than "if". The file was written on the way in and removed on the way
out, and the branch that removes it is the branch the stale file sends you away
from — so a desync is not a state the script can leave. Unfloat the window with
any other key, or close it while spotlighted, and every subsequent press does
the wrong half of the toggle until `/tmp` is wiped.

Both compositors have always been able to answer the question. niri's IPC
`Window` struct carries `is_floating`; Hyprland's `activewindow -j` carries
`floating`. The state file was a cache of a value one query away, with no
invalidation — which is the same finding as the five hex literals in
`palette.nix` and the hand-copied Qt theme in `core.nix`, in a shell script
instead of a Nix file.

```sh
floating=$(niri msg --json windows |
  jq -r 'map(select(.is_focused))[0].is_floating | tostring')
```

`tostring` rather than jq's `//` default operator, which treats `false` as
absent and would have reported every tiled window as unknown — the kind of
detail that turns a correct rewrite into a differently-wrong one.

**waybar got the same treatment, and this is the part that would have been easy
to miss.** `pkill -SIGUSR1 waybar` is a *toggle*. Reading the window truthfully
and then hitting the bar blind does not fix the bug, it splits it: the two
halves drift apart instead of one file drifting from both. The bar is stopped
and started now, because "is waybar running" is a question `pgrep` can answer
and "is waybar hidden" is not. It costs a couple of hundred milliseconds of bar
on the way out, which the old code already paid on any press where waybar had
died.

Also new: pressing it on an empty workspace says so instead of dispatching
`togglefloating` at nothing.

**On the machine:** press `Super+Alt+S` (spotlight) twice — window in, window out,
bar out, bar in. Then float the window by hand, press it once, and confirm it
*tiles* rather than floating harder. That second test is the whole finding.

---

## 2026-08-06 (h) — the look had six definitions, and the one that derives it was switched off

The README has said this for a while:

> There is one place that decides how this machine looks: `stylix` in
> `modules/system/core.nix`. Everything else derives from it.

It was true of the colours and the fonts, because `modules/home/palette.nix` was
built to make it true. It was false of everything else — and one of the six
places has been stopping `nixos-rebuild` from evaluating at all since the 26.05
bump.

### The Qt theme, written out four times to avoid the nine lines that compute it

Stylix's NixOS Qt target is this:

```nix
qt.platformTheme = if plasma6.enable && !(gnome.enable || lxqt.enable)
                   then "kde" else …;
qt.style         = { kde = "breeze"; gnome = …; qtct = "kvantum"; }
                   .${config.qt.platformTheme};
qt.enable        = true;
```

`plasma6.enable` is unconditionally true on this machine, so that computes
`"kde"` and `"breeze"`. Here is what the repo had instead:

| Where | What |
|---|---|
| `modules/system/desktop.nix` | `stylix.targets.qt.enable = false` — the target, off |
| `modules/system/core.nix` | `qt.enable = lib.mkForce true; platformTheme = "kde"; style = "breeze";` — its output, by hand |
| `modules/system/core.nix` | `QT_STYLE_OVERRIDE`/`QT_QPA_PLATFORMTHEME` in `environment.sessionVariables`, both `mkForce` — a second transcription |
| `home/shaul.nix` | the same two variables again, in `home.sessionVariables`, also both `mkForce` — a third |

**None of the three `mkForce`s overrides anything.** `services.desktopManager.plasma6`
already sets `qt.enable = true` twenty lines away, and two definitions of `true`
never conflicted. The two variables are exported by nixpkgs' own `qt` module
(`nixos/modules/config/qt.nix`) from `qt.style` and `qt.platformTheme`, into
`environment.variables` — a *different option*, which a `mkForce` in
`environment.sessionVariables` cannot override. It can only outrank it in the
session, which is the actual damage: the hand-written pair wins, so changing
`qt.style` could never change what a Qt app sees.

That is the `palette.nix` lesson exactly — a value copied by hand out of the
thing that computes it, kept in force by an operator that hides the copy — and
it cost eleven lines of config to say what zero lines say correctly.

### `gtk.gtk4.theme = null` is an evaluation error

`home/common.nix` carried `gtk.gtk4.theme = null;`, commented *"FIX: Silence GTK4
warning"*. The warning was real: home-manager 26.05 changed that option's default
from `config.gtk.theme` to `null`, and a profile on `stateVersion = "25.11"` gets
a deprecation warning until it says which one it wants.

It stopped being the right answer when stylix's GTK target started setting the
same option — `gtk.gtk4.theme = config.gtk.theme`, ordinary priority. The option's
type is `nullOr`, and `nullOr`'s merge function does not pick a winner:

```
The option `gtk.gtk4.theme' is defined both null and not null
```

That is a `throw`, not a warning. `nixos-rebuild` never reaches the build. It has
been latent since the 26.05 upgrade, which was authored off-machine like
everything else here and has never been evaluated — so this is the first thing
`just check` will hit, and now it won't.

Deleted rather than forced to `null`: with stylix defining the option, the
deprecation default is never reached, so the warning stays gone — and GTK 4 apps
get the same adw-gtk3 that GTK 3 apps already had, instead of being the one
toolkit left unthemed.

### The cursor: three statements, two sizes, and a theme that no longer exists

`stylix.cursor` was never set, so the four surfaces that need a pointer each
answered for themselves:

| Where | What it said |
|---|---|
| `core.nix` | `XCURSOR_SIZE = "24"` |
| `home/shaul.nix` (plasma-manager) | theme `Breeze_Snow`, size 24 |
| `niri/config.kdl` | `cursor { xcursor-size 12 }`, no theme |
| `hyprland.conf` | nothing at all |

So the pointer changed size when you changed session. And the only statement that
named a *theme* named one that does not exist: KDE's breeze repo installs
`share/icons/breeze_cursors` and `share/icons/Breeze_Light` — `Breeze_Snow` was
the Plasma 5 spelling and is gone on the 6.5 branch nixpkgs 26.05 builds. Plasma
falls back silently when a cursor theme is missing, which is why nobody found
out.

`stylix.cursor` is now set once. Stylix's home-manager side turns it into
`home.pointerCursor` (GTK, X11, `~/.local/share/icons`), and `palette.nix` hands
the same name and size to plasma-manager, to niri's KDL and to `hyprland.conf`.
`XCURSOR_SIZE` is gone: it was a fifth statement that only some of those four
ever read.

### And the font list repeated what stylix installs

Stylix's font-packages target sets `fonts.packages` to the four families named in
`stylix.fonts`. `desktop.nix` listed three of them again — `noto-fonts`,
`noto-fonts-color-emoji`, `nerd-fonts.jetbrains-mono` — plus `jetbrains-mono`
beside the Nerd Font patch of the same typeface. That is the rule from
`base-tools.nix` (*a package is declared in exactly one list*) broken in the one
list that pass never looked at. Harmless until you change
`stylix.fonts.monospace`, at which point the list keeps installing the family you
stopped using.

### What changed

```
NEW modules/system/appearance.nix   stylix (scheme, image, fonts, cursor), the
                                    font list, OSFONTDIR, the scaling variables
modules/system/core.nix             → the machine: Nix, boot, network, locale,
                                      the user. Reformatted; it was the drawer.
modules/system/desktop.nix          → X, SDDM, Plasma, audio, printing, Flatpak
modules/system/wayland.nix          + NIXOS_OZONE_WL, MOZ_ENABLE_WAYLAND,
                                      QT_WAYLAND_RECONNECT (a session fact that
                                      had been filed under "the machine")
modules/system/hardware.nix         + hardware.graphics.enable (it is hardware)
modules/home/palette.nix            + .cursor
home/shaul.nix                      Plasma cursor derived; the duplicate QT_*
                                    and GDK_* variables deleted; the two stylix
                                    targets that stay off now argued
home/common.nix                     the gtk4 line deleted
niri/, hyprland/                    cursor from the palette
```

Two `core.nix` duplicates fell out of the split and are worth naming:
`services.displayManager.sddm` was declared in **both** `core.nix` and
`desktop.nix` (both `enable = true`, so the module system merged them and said
nothing), and it now lives once, in the graphical stack.

### Riders — the last two ranked Lamdan findings

- **3.1, `unstable`.** The `nixpkgs-unstable` input, the second full nixpkgs
  evaluation it was imported into, and the `unstable` special-arg threaded
  through `specialArgs` and `extraSpecialArgs` are gone. A repo-wide grep for
  `unstable.` found the input URL and the comment explaining how to use it, and
  nothing else. Re-adding it is four lines, on the day a package needs it.
- **3.4, `system.nixos.version = "current"`.** Deleted. It did nothing for the
  boot menu — `system.nixos.label = "ShaulOS"` already replaces the whole suffix
  — and made `nixos-version` and `/etc/os-release` report the string `current`
  instead of the release you are on. Cosmetic right up until a rebuild goes wrong
  and that is the command you reach for.

That closes the Lamdan ranked table. What is left from it is one paragraph of
3.4 smalls (`services.onedrive` is enabled and nothing has ever given it
credentials; `spotlight` keeps toggle state in `/tmp` and stays desynced until
reboot if it ever drifts) and the two questions the report could not answer from
the repo — whether this box is a laptop or a desktop, and what you are building
next.

**Noted, not changed:** `networking.firewall` opens TCP 22, 1714 and 1764. The
last two are the *endpoints* of KDE Connect's 1714-1764 range, so pairing works
only if both ends happen to pick them; `programs.kdeconnect.enable = true` opens
the range itself. Whether you want phone pairing at all is a decision, and this
pass does not get to make it. — **decided, and done in (k)**: you want it, and
enabling it properly turned out to also expose a hole in the `study` firewall
that the two hand-written port lists were hiding.

**⚠ Not evaluated**, like everything else here — but note that the gtk4 finding
means the *previous* state did not evaluate either. Expect `just check` to be
the first honest signal this tree has had since the 26.05 bump.

**On the machine, in order**

```sh
just update      # flake.lock predates sops-nix AND emacs-config; it must be relocked
just check       # statix + deadnix + the emacs-config input
just build
just switch
```

Then, one per finding above: `echo $QT_QPA_PLATFORMTHEME` should say `kde` in a
Plasma session; a GTK 4 app (nautilus, or any libadwaita thing) should not look
like the odd one out; and the pointer should be the same size in Plasma, niri and
Hyprland — which is the one you can check in ten seconds by logging in three
times.

---

## 2026-08-06 (g) — every package lived in the system closure, so the airgap could not remove one

`study` is the only specialisation left, and the README's claim for it is
*"offline airgap, no browsers."* It had a browser on `$PATH`.

```
modules/system/cli-tools.nix:31
    aria2 bat navi lynx ytfzf yt-dlp mpv xapian
                   ^^^^
```

**Why the previous fix did not fix it.** The Lamdan report's finding 3.2 caught
`programs.firefox.enable = true` in that same file — the NixOS option, which puts
firefox in `environment.systemPackages`, which a specialisation *inherits* — and
fixed it with a `lib.mkForce false` in `study-offline.nix`. That worked, for
firefox. `lynx` was two words away on line 31 and nobody wrote it a second
`mkForce`, because the fix was aimed at the package and the fault was in the
drawer.

**The fault.** There was no rule about where a package goes, so the answer
defaulted to `environment.systemPackages`. `cli-tools.nix` and `development.nix`
between them installed about sixty user applications machine-wide. A
specialisation can only ever *add* — inheriting is the mechanism — so every one
of those sixty is unremovable, and every subtraction has to be spelled as a force
you remembered to write.

`modules/system/profile.nix` already records the home-manager half of exactly
this lesson: `home-manager.users.<name>` is a submodule, so a second `imports`
merges rather than replaces, which is how the old study mode ended up with the
full desktop profile bolted underneath it. This is the same fault one layer down,
and it survived the fix to the other one.

**The bill, all of it already in the tree.**

| | |
|---|---|
| `lynx` | a browser, on `$PATH` in the no-browsers airgap |
| `programs.firefox.enable` | stated in two module systems, plus a third statement to cancel the first |
| the study package branch | called itself *"a different list, not a subset"*; four of its five entries were already in `systemPackages` |
| `ytfzf`, `yt-dlp` | YouTube clients, requested by the airgap |
| `libreoffice-qt-fresh` | written out in **both** arms of the conditional |
| 13 packages | declared once in a system list and once in a home list |
| `fzf`, `bat`, `git` | listed as packages beside the `programs.*` modules that install them |

A conditional in which one side is a no-op and the other is a copy is not a
decision, it is a shape.

**The rule** (stated in `modules/system/base-tools.nix` and
`modules/home/toolkit.nix`, and in the README under *Where a package goes*):

1. A package is declared in exactly **one** list.
2. `environment.systemPackages` holds only what must work when home-manager is
   broken, absent, or not yours — the set you repair a bad generation with, in a
   TTY, possibly *because* the home profile is what failed. That is now ten
   packages and one argued exception.
3. Everything a person types goes to home-manager, in the module that owns it,
   and everything else to `toolkit.nix` where `shaulos.study` can reach it.
4. A program a script calls by store path needs no list entry at all.

**What moved.**

```
modules/system/cli-tools.nix  →  base-tools.nix   30 packages → 10 + the spell stack
modules/system/development.nix                    the toolchains → toolkit.nix
modules/system/wayland.nix                        systemPackages block → deleted entirely
modules/system/data.nix                           rclone → toolkit.nix
home/shaul.nix                                    the if/else app suite → toolkit.nix
home/common.nix                                   7 packages → 1 (the script it defines)
modules/home/emacs/default.nix                    6 general tools → toolkit.nix
NEW modules/home/toolkit.nix                      all of it, in two lists
```

**What study actually removes now**, by construction rather than by remembering:
browsers (`lynx`, `qutebrowser`, `tor-browser`, firefox), anything whose job is
fetching (`aria2`, `persepolis`, `ytfzf`, `yt-dlp`, `opencode`, `rclone`), and
the creative and media suite. **Nothing else** — it keeps the search tools, the
file managers, the editors, the document toolchain, the compilers and `mpv`. The
airgap is two claims: the firewall means nothing gets out, and the absent
programs mean you don't open one out of habit. Removing `ncdu` serves neither.

**Deleted rather than moved**, both deliberate:

- `nixpkgs-fmt` — `nix fmt` and `just fmt` run `nixfmt-rfc-style`. A second Nix
  formatter on `$PATH` is a coin-flip about which one reformats the file you are
  looking at.
- `polkit_gnome` from `systemPackages` — `keys.nix` starts the agent by store
  path, so it is in the closure regardless, and it is a libexec helper nobody
  invokes by name.

Also: `modules/home/scripts.nix` called `jq` by bare name, which worked because
`home/common.nix` happened to install it on a line that also carried five
duplicates. It is a store path now, like every other program those scripts call.
`niri`, `hyprctl`, `waybar` and `pgrep` stay bare on purpose — the first three
come from the running session and the last from the NixOS required-packages set.

**Check it on the machine.**

```sh
just build                        # the merge of six package lists into one home
                                  # profile is the only real risk here — a file
                                  # collision between two packages that were
                                  # previously in different profiles shows up
                                  # as a build failure, before activation
just switch
command -v lynx qutebrowser firefox   # present

# now reboot and pick `study` in the systemd-boot menu
command -v lynx qutebrowser firefox   # ALL THREE SHOULD BE ABSENT
command -v rg fd recoll nvim ncdu gcc mpv libreoffice   # all still present
brightnessctl set 50%             # moved home; still on $PATH
```

**Still open from the Lamdan report**, untouched by this pass: finding 3.1, the
second full `nixpkgs-unstable` evaluation with zero call sites.

---

## 2026-08-06 (f) — the keymap had five definitions, and four of them were wrong

Lamdan finding 2.2, finished. The report's verdict there was about the two
*system* compositor modules, and commit (c) factored those into
`modules/system/wayland.nix`. But the argument it made was general, and it named
the reason the repo kept producing this shape:

> This isn't "abstract on the third," it's "you already abstracted this exact
> thing, in this exact repo, and stopped halfway."

It stopped halfway again. The keymap is the largest instance of the pattern in
the tree, and it had **five hand-written transcriptions**: `niri/config.kdl`,
`hypr/hyprland.conf`, and a `guide.org` cheat-sheet sitting beside each of them.

**Why it got worse rather than better.** Commit (c) is what exposed this.
`modules/system/wayland.nix` explains the mechanism: duplication between two
mutually exclusive boot closures is invisible, "you could never see them side by
side." Now there is one closure and you pick the session at the greeter — so the
drift stopped being a fact about two files and became a fact about your hands.

**The drift, in full.**

| | niri | Hyprland |
|---|---|---|
| File search | `Mod+Space` | `Mod+P` |
| File manager | *nothing* | `Mod+E` → dolphin |
| Emacs frame | *nothing* | `Mod+Shift+E` |
| Workspaces 1–5 | *nothing* | `Mod+1..5` |
| Quit compositor | `Mod+Shift+Alt+Q` | *nothing* |
| Move to workspace | follows you | followed you to 1–3, silent for 4–5 |
| swww start | `sleep 1` and hope | waits for the daemon |
| nm-applet | no tray flag | `--indicator` |

None of that was a decision. `Mod+Space` versus `Mod+P` is one script — the same
`power-search` — on two different keys, and the Hyprland cheat-sheet had a row
whose entire content was the drift: `Super+Space | (unbound – power-search is
Super+P)`.

**The cheat-sheets were worse than stale.** They were a fourth and fifth copy of
the config, written by hand, and essentially every factual row had rotted:

- `hyprland/guide.org` documented resize on `Super+Ctrl+H/L/K/J`. It has always
  been `Super+Alt`. `Super+Ctrl` has exactly one binding, and the guide never
  mentioned it.
- It documented a three-bind *"Dwindle Layout (Emacs-style splitting)"* section —
  `Super+V`, `Super+Shift+V`, `Super+Shift+H` — none of which have ever existed
  in `hyprland.conf`. It then listed `Super+V` as the clipboard 34 lines later,
  contradicting itself on the same page.
- It claimed `Super+Shift+1…5` moves a window to workspaces 1–5, and separately
  that `Super+Shift+4…5` moves it silently. Both rows described the same two keys.
- `niri/guide.org` had **three** concatenated `#+TITLE` lines from three drafts.
  It told you to switch sessions by rebuilding a specialisation — untrue since
  (c). It said Caps Lock toggles Hebrew; Caps Lock is Escape and the toggle is
  Ctrl+Alt. It pointed at `~/nixos-config` for the source. It hardcoded `#7aa2f7`
  and `#414868` — the exact literals commit (e) removed from `palette.nix`.

A wrong bind in a config file is a key that does nothing. A wrong bind in the
cheat-sheet is a key you believe in.

**The fix, same shape as `palette.nix`.** `modules/home/keys.nix` is one
definition that hands out values already in the target syntax. A bind is data —
`{ mods, key, desc, group }` plus one action:

- `spawn = [ argv ]` — a program the session provides. Rendered into niri's
  `spawn "a" "b";` (KDL strings are JSON-escaped) and Hyprland's
  `exec, <shell-quoted>` from one argv list. This is the shared layer: every
  target comes from `wayland-common.nix`, `scripts.nix` or `lock.nix`, modules
  both compositors import, so the key must not depend on which is running.
- `cmd = "…"` — a compositor verb, already in that compositor's dialect, declared
  only inside that compositor's own module. niri scrolls columns and Hyprland
  tiles; those genuinely differ and nothing pretends otherwise.

That split is the one `wayland-common.nix` already draws. 19 shared binds, 38
niri verbs, 35 Hyprland verbs, zero duplicate chords in either session.

The autostart list and the xkb settings went the same way — one list each,
rendered to `spawn-at-startup` and `exec-once`.

**The guide is now output, not documentation.** `~/.config/shaulos/keys.org` is
generated from the same lists that write the configs, plus the colours from
`palette.nix`. Both `guide.org` files are deleted. Open it with `Super+Shift+/`
in either session — one document covering both, which is a thing you could not
have had while they were separate closures.

It documents only what it *derives*. Gaps, opacity, animation curves and window
rules are still literals inside each compositor's config text, so the guide says
nothing about them. Restating an underived fact is how the last cheat-sheet
started.

**Also gone:** `power-search`, which was
`writeShellScriptBin "power-search" "exec fsearch"` — a script whose entire body
renamed a binary (Lamdan 3.4's fourth bullet). That is only worth doing if the
caller cannot name the real program, and the only caller was a keybinding. The
keymap names `fsearch`.

**On the machine — keys that moved.** This is the one change here you will feel:

| Key | Before | Now |
|---|---|---|
| `Super+Space` | search (niri only) | search, both sessions |
| `Super+P` | search (Hyprland only) | **unbound** |
| `Super+E` / `Super+Shift+E` | Hyprland only | both |
| `Super+1..5`, `Super+Shift+1..5` | Hyprland only | both |
| `Super+Shift+Alt+Q` | niri only | both |
| `Super+Shift+/` | — | opens the generated guide |
| `Super+Shift+Return`, `Super+Ctrl+Return` | Hyprland scratchpad aliases | **unbound** — `Super+` ` is the pair both sessions always had |

If you want the Return aliases back they are two entries in the `session` list in
`keys.nix`; they were dropped because they existed in one session out of two and
duplicated keys that existed in both.

Hyprland's waybar and nm-applet now start two seconds late, which is the niri
side's spelling — a tray icon that starts before the tray exists does not appear,
and waybar is the tray. Cosmetic either way; unified rather than left to differ.

**Verify after switching:** `Super+Shift+/` should open the guide in Emacs; every
row in it should be a key that works. `Super+Space` should open FSearch in *both*
tiling sessions, and `Super+P` should do nothing.

---

## 2026-08-06 (e) — the theme had two definitions, and the copy was in the wrong syntax

Lamdan finding 2.4. The report rated it `wrong-but-keep` — "a two-source-of-truth
arrangement whose second source you touch once a year," not worth a dedicated
pass. That was the right call on the evidence the report had. It was working from
the *values*, and the values were correct. The bug was in the **format**.

**What the file said about itself.** `modules/home/palette.nix` was five hex
literals with a comment that named its own problem:

> These mirror the Stylix base16 scheme (tokyo-night-dark) … Kept as literals so
> every module evaluates without reaching into Stylix internals. To re-theme,
> change the scheme in `modules/system/core.nix` and update these five values
> (or later wire them to `config.lib.stylix.colors`).

One theme, two definitions, and the second only updates if you remember it is
there. Change `stylix.base16Scheme` and the bar, the lock screen and both
compositors' borders keep the old colours — silently, because nothing connects
them. That is the finding as written, and on its own it really is a once-a-year
annoyance.

**The part underneath it.** Copying a colour by hand is two jobs and only the
first is obvious. `#7aa2f7` has to be spelled three different ways in this repo —
CSS for waybar, a quoted string for niri's KDL, and hyprlang's function syntax
for `hyprland.conf` and `hyprlock.conf` — and `lock.nix` was emitting

```
outer_color = rgb(#7aa2f7)
```

hyprlang's `rgb()` takes six **bare** hex characters. The `#` makes seven, it
fails the length check, and hyprlang answers `rgb() expects length of 6
characters (3 bytes) or 3 comma separated values`. All four coloured lines in
`hyprlock.conf` — the password field's outline, its fill, its text, and the
clock — were parse errors, and those four properties have been running on
hyprlock's defaults since the day they were written.

Nobody could have noticed. Until commit (c) nothing started `hypridle`, and
wlogout's lock button named a `swaylock` this config does not install, so
hyprlock had never been on screen. The idle chain works now, which is precisely
why this had to be fixed now: the first thing that lock screen was ever going to
do is show you the bug.

Getting a colour into the wrong *format* is a failure a value-level review does
not see and a `nix flake check` cannot see either — statix and deadnix read Nix,
not the heredocs Nix writes. The only defence is not hand-writing the format.

**The change.** `palette.nix` stops being a bare-`import` data file and becomes a
home-manager module that derives everything from `config.lib.stylix.colors` and
`config.stylix.fonts`, exposing `config.shaulos.palette`:

| View | Form | Consumers |
|---|---|---|
| `.css` | `#rrggbb` | `waybar.nix`, `niri/default.nix` (KDL takes the same spelling) |
| `.hypr` | `rgb(rrggbb)` — already wrapped | `hyprland/default.nix`, `lock.nix` |
| `.font` | `mono` / `sans` names + the `sizes` set | `waybar.nix`, `lock.nix`, Plasma in `home/shaul.nix` |

No consuming module writes a colour, wraps one in a function, or names a font any
more. There are two formats now instead of three: the hand-written
`0xAARRGGBB` variant that existed alongside the `#rrggbb` literals for the same
two colours is gone, because hyprlang takes `rgb()` perfectly well.

The palette also loses `magenta`, a fifth literal with zero call sites in the
tree — the same thing the report says about `unstable` and the `lxqt` branches.

**Fonts had the same disease.** `modules/home/foot.nix` was

```nix
font = lib.mkForce "JetBrainsMono Nerd Font:size=10";
```

Stylix's foot target writes exactly `${fonts.monospace.name}:size=${fonts.sizes.terminal}`
along with the whole base16 colour table. So this was a hand-copy of a font
stylix had *just derived from the scheme*, wrapped in the one operator
guaranteed to win, carrying a size that lived nowhere near the other three font
sizes. `foot.nix` is now one line; the size is
`stylix.fonts.sizes.terminal = 10` in `home/shaul.nix`, beside
`sizes.applications` and `sizes.desktop`. Same rendered value.

Likewise Plasma's four hardcoded font strings in `home/shaul.nix`
(`"Noto Sans,9,-1,5,50,0,0,0,0,0"` and friends) are now built by a `qtFont`
helper from `config.stylix.fonts`. `stylix.targets.kde` stays off — that is a
decision, and plasma-manager still writes the files; what changed is that it no
longer decides *which font* independently of the thing that decides every other
font.

**Two exceptions, both said out loud in the file that makes them:** waybar's
`font-size: 12px` (Nerd Font glyph sizing, not UI scale — `sizes.desktop` is 9)
and Plasma's toolbar font at one point below `sizes.applications`, which is
Plasma's own convention. Deriving those would have been a visible change nobody
asked for; leaving them silent is how the original problem started, so they are
annotated instead.

**On the machine:** nothing to do. Every rendered value is byte-identical to what
you had *except* the four hyprlock colours, which change from hyprlock's defaults
to the tokyo-night blue they were always supposed to be. Lock the screen once
(`Mod+Shift+Q` → Lock, or wait seven minutes) and you should see a blue password
outline on a `#1a1b26` fill instead of hyprlock's stock grey. Nothing else moves.

---

## 2026-08-06 (d) — the seforim library was never downloading

Lamdan finding 3.4's first bullet ("three sync tools, one user, one drive"),
taken at the root — and the root turned out to have a live bug under it.

**The bug.** `file-sync.nix` decided whether to fetch anything by asking
`[ ! -d "$dst" ]`. But `modules/home/emacs/default.nix` runs

```sh
mkdir -p "${seforimPath}/Bavli"
```

in its home-manager activation — that is, on **every `just switch`**, including
the one that installs the machine, which happens long before this unit gets a
boot. So the directory always existed by the time the question was asked,
`unified:seforim` never copied, and the log said

```
[GDrive 2/2] seforim already exists, skipping.
```

for the rest of the machine's life. That is recoll's `topdirs` and the entire
subject matter of the seforim Emacs system — the one resurrected two commits
ago — silently absent and reported as success. Two modules in one closure, one
of which scaffolds directories and one of which reads directories as evidence.

The fix is the predicate: **ask about files, not about the directory.**

```sh
provisioned() { [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ]; }
```

Empty scaffolding no longer counts as data, and a machine that already has its
files still skips — so this needs no stamp file and no migration.

**It was never a service either.** Its own header said "no updates, no
overwrites" — a bootstrap, not a sync. It was wired `wantedBy =
multi-user.target` with `after = network-online.target`, and a `Type=oneshot`
unit wanted by a target is one the target *waits for*. Every boot for the life
of the machine therefore waited on NetworkManager-wait-online so a script could
run three `[ -d ]` tests and exit. That is the ~90s stall `study-offline.nix`
credited itself with fixing; it was never fixed, it was only absent from the
airgap closure. It is now a timer at `OnBootSec = 2min`. The service keeps
`After=network-online.target`, so the *job* still waits for the network — it
just waits somewhere nobody is standing behind it.

**And it failed on the one machine it exists for.** A missing `rclone.conf` was
counted as an error and exited 1 with `Restart=on-failure`, so a fresh install —
the only time the unit has work to do — retried three times over 90s and parked
in `failed` forever. "You have not set rclone up yet" and "the transfer broke"
no longer share an exit code. `Restart=` is gone entirely: when a bootstrap
fails, the answer is to run it again once the reason is gone, and that is a
command (`just bootstrap-data`), not a systemd policy.

**Three tools became one place.** `file-sync.nix` → `modules/system/data.nix`,
which now also owns `services.onedrive` (moved out of `services.nix`). The
`onedriver` package is deleted: it is a *different project* that FUSE-mounts the
same OneDrive account, with no service, no config, no README mention and no
history since the initial import — two clients for one remote is one client.
`services.onedrive` survives with a comment saying what it actually does, which
is install the client; nothing here has ever given it credentials.

Smaller things in the same pass:

- `git` dropped from that module's `systemPackages` — it is already in
  `cli-tools.nix`, and listing it here made it look like a dependency of the
  sync rather than of the machine.
- The seforim destination comes from `myConfig.seforimPath` instead of a second
  hardcoded copy. `modules/home/emacs/default.nix` reads the same value; the two
  disagreeing silently is the exact shape of the bug above.
- `git clone` now lands in `$dst.incoming` and swaps, so a clone killed mid-
  transfer leaves nothing the new file-based predicate would read as complete.
  The `curl https://github.com` pre-flight is gone — a failed clone is the same
  information one step later, without the second failure mode.
- `SSL_CERT_FILE` set explicitly: a unit with an explicit `Environment=` is not
  a login shell, and git needs a CA bundle.
- The 68-line rclone setup manual that lived in `.nix` comments is now in
  `README.md` under "First-boot setup", where someone setting up a machine
  might actually find it.

**On the machine:** nothing to do if your `~/Documents` is already populated —
the new predicate sees the files and skips. If `~/Documents/seforim` is empty or
only has `Bavli/`, this is the commit that finally fills it: run
`just bootstrap-data` (after `rclone config`, if you have not).

---

## 2026-08-06 (c) — four specialisations became one, and the sessions became sessions

Findings 2.1 and 1.2 of the Lamdan review, taken at the root rather than patched.

**Why.** A specialisation is a whole second system closure. Three of the four
were buying one with money they didn't need to spend:

- `hyprland` and `niri` were answering *"which session should the display
  manager start"* — which is the entire job description of a display manager.
  Both compositors install cleanly beside Plasma and register `.desktop`
  sessions through uwsm; SDDM lists them. The price of asking the bootloader
  instead was: every `nixos-rebuild` built all four closures, each was a GC
  root, and changing your mind about a compositor cost a reboot rather than a
  logout.
- `minimal` was answering *"how do I get a shell when the desktop is wedged"* —
  which systemd-boot already answers with ten kept generations, any of which
  boots the system you had *before* you broke it. And it was not minimal:
  specialisations inherit, so force-disabling xserver/sddm/plasma6 left
  pipewire, printing, flatpak, all 16 font packages and the whole of
  `cli-tools.nix`. Its home side didn't shrink either — `lib.mkIf false` around
  the home-manager block contributes nothing, it does not *retract* the
  parent's, so "recovery mode" still built GIMP, Krita, digiKam and darktable.
- `study` stays, and it is the whole reason the mechanism is in the repo: the
  radios are off and the firewall denies everything. That state genuinely
  cannot coexist with the base system at runtime.

**The bug the split was hiding, and it is worse than the review said.**
`home-manager.users.<name>` is a submodule, so two definitions of it *merge*.
The base set `users.shaul.imports = [ home/desktop.nix ]`; each specialisation
set `users.shaul.imports = [ its own profile ]`. Both were imported. **The
study specialisation was therefore running the full desktop profile
underneath its own** — tor-browser, qutebrowser and the entire graphics suite,
in the session whose stated purpose is not having them. That is fixed by
construction now: one import site, and a `shaulos.study` boolean the profile
branches on.

**And the drift the split had already produced**, all of it now structurally
impossible rather than individually patched:

| Was | Now |
|---|---|
| `p10k.nix` and `foot.nix` imported only by `desktop.nix`, while `common.nix` loads the p10k plugin and sources `~/.p10k.zsh` everywhere — so niri and study booted with an unconfigured prompt and an unconfigured `Mod+Return` terminal | one profile imports both |
| `dolphin` installed by the niri and study profiles; Hyprland is the session that binds `Mod+E` to it and is yazi's `reveal` opener. Invisible until you booted the one session with Plasma forced off | in `wayland-common.nix`, present in every session |
| **niri never auto-locked** — `lock-niri.nix` was three lines installing swaylock, no idle daemon, no timeout | one `lock.nix`: hyprlock + hypridle for both compositors |
| Hyprland's hypridle config was never started either — `lock-idle.nix` said "started via exec-once in Hyprland" and `hyprland.conf` had no such line. Both sessions shipped an idle config nothing ran | `spawn-at-startup "hypridle"` / `exec-once = hypridle`, explicitly |
| wlogout's stock layout hardcodes `swaylock`, installed in exactly one session — so the power menu's lock button did nothing under Hyprland | `programs.wlogout` with an explicit layout naming `hyprlock` |
| `hyprland.conf` hardcoded `monitor = , 1366x768@60, 0x0, 1` while niri used `output ".*" { scale 1.0 }` — plug in an external display and the sessions behaved differently, for no reason anyone chose | `monitor = , preferred, auto, 1` |
| `modules/system/{niri,hyprland}.nix` were the same file: 22 of ~30 non-blank lines byte-identical | `modules/system/wayland.nix`, imported by both; each compositor module is now four lines |

**Changed**

- `hosts/desktop/configuration.nix`: imports the three session modules; one
  `specialisation.study`; one home-manager import site. The per-specialisation
  portal lists are gone — plasma6, `programs.niri` and `programs.hyprland` each
  register their own backend and per-desktop `portals.conf` via
  `xdg.portal.configPackages`, which only works when they coexist.
- **Deleted:** `lib/mk-specialization.nix` (its only remaining caller was the
  one specialisation, and it carried three `lxqt` branches for a desktop
  environment nothing in the repo ever passed it), `modules/system/minimal.nix`,
  `modules/home/lock-idle.nix`, `modules/home/lock-niri.nix`,
  `home/desktop.nix`, `home/niri.nix`, `home/study.nix`.
- **New:** `modules/system/wayland.nix`, `modules/system/profile.nix`,
  `modules/home/lock.nix`, `home/shaul.nix`.
- `modules/home/wayland-common.nix` stopped being a function. It took an
  `xdgDesktop` argument to pin `XDG_CURRENT_DESKTOP`, and also pinned
  `WAYLAND_DISPLAY = "wayland-1"`. Both are gone: uwsm and SDDM set the former
  from the session's `DesktopNames`, and the compositor exports the latter. A
  hardcoded `WAYLAND_DISPLAY` in `home.sessionVariables` is a guess sourced by
  every login shell — i.e. a guess with the power to override the truth. It
  happened to be right.
- `modules/home/scripts.nix`: the `pgrep` compositor detection **stays**, and
  is now correct rather than merely harmless — one closure serves three
  sessions, so the compositor genuinely isn't knowable until the key is
  pressed. What changed is the silent fall-through: under Plasma, `spotlight`
  and `teleport` matched no branch and exited 0 having done nothing. They now
  say so.
- One-line rider, finding 3.2: `programs.firefox.enable = lib.mkForce false` in
  `study-offline.nix`. `cli-tools.nix` sets the *NixOS* option, which puts
  firefox in `environment.systemPackages`; the home-side `mkForce false` never
  touched it, so "offline airgap, no browsers" had a browser on `$PATH`.

**What this costs you.** One boot-menu entry (`minimal`) and two boot-menu
entries (`hyprland`, `niri`) disappear; the compositors move to the greeter.
`pcmanfm-qt` and `thunar` moved from the Hyprland module — which every session
imports now — to the non-study application list, so study mode loses two file
managers it never asked for. niri's `XCURSOR_SIZE = 12` override is gone; the
KDL's `cursor { xcursor-size 12 }` already did that job for the session that
wanted it.

**⚠ Not evaluated.** Authored off-machine as usual, but this one restructures
the module graph rather than editing leaves, so it is the change most likely to
fail at `nix flake check`. Run `just check`, then `just build`, before
`just switch`. Specifically worth watching: `programs.niri.enable` and
`programs.hyprland.enable` in one closure (they should merge cleanly — both
contribute to `xdg.portal.*` and `environment.sessionVariables` as lists or as
equal values), and `programs.wlogout`'s default CSS finding its icons.

**On the machine, in order**

```sh
just check                    # statix + deadnix + the emacs-config input
just build                    # full closure, no activation
just switch
# log out; SDDM should now list Plasma, Niri (uwsm) and Hyprland (uwsm)
# reboot only to reach `study` in the boot menu
```

Sanity checks after switching, one per drift row above: `which dolphin` in a
Hyprland session; `pgrep hypridle` in a niri session; `cat ~/.p10k.zsh` exists
in every session; `spotlight` under Plasma should now pop a notification rather
than nothing.

---

## 2026-08-06 (b) — the Emacs config moved to its own repo

Finding 1.1 of the Lamdan review, the other half. The config now lives at
**[github.com/SYKhayyat/emacs-config](https://github.com/SYKhayyat/emacs-config)**
and arrives here as a pinned flake input.

**Why.** By line count this was never a NixOS configuration that includes
Emacs — ~6,900 lines of Emacs config against ~2,300 of Nix. And it is
explicitly a different product: `init.el` advertises "ONE config, everywhere"
and carries `w32-pipe-read-delay`, `~/scoop/shims`, `C:/msys64` and a darwin
branch; `00-core` self-installs from MELPA on a bare box; `tools/deploy.sh`
exists to put it on a non-Nix machine and has to warn you away from the machine
this repo is named after.

**What that cost, and what's gone.** The store is read-only and the config
tangles `.el` next to `.org` at runtime, so `default.nix` staged the modules at
`~/.config/emacs/modules-src` and then ran an mtime-gated `cp` into a *writable*
`~/.config/emacs/modules`. That copy was a directory Nix did not own: no
rollback, no GC, and the sync only ever added. Edit a module in place and either
your edit silently became the live config while the repo went stale, or it was
clobbered with no backup — with nothing to tell you which. It also hid its own
failures: six untracked modules never entered the store at all, invisible
because the writable copy still had them from an earlier deploy.

The new repo's flake tangles **at build time**, so what lands here is an
immutable store symlink. The staging hop and the syncer are deleted.

**Changed here**

- `flake.nix`: new `emacs-config` input; `myConfig.emacsConfig` (pre-tangled
  config) and `myConfig.emacsPackage` (Emacs + package set) threaded to the one
  module that needs them. New `emacs-config` check so a bad input bump fails
  `nix flake check` rather than halfway through a switch.
- `modules/home/emacs/default.nix`: down to packages, `services.emacs`,
  `recoll.conf`, directory scaffolding, and three `home.file` symlinks.
- Removed: `init.el`, `early-init.el`, `modules/` (40 modules), `tools/`,
  `emacs-package.nix`, and the four Emacs READMEs — all now in the other repo,
  **with their history** (`git subtree split`).
- The `emacs-modules` / `emacs-bytecompile` checks added earlier today moved to
  the new repo, where they run in GitHub Actions on every push.
- `justfile`: `just update-emacs` bumps the input; `just emacs-dev [PATH]`
  rebuilds against a local checkout for a fast edit loop.

**The new edit loop.** Commit in `emacs-config` → `just update-emacs` →
`just switch`. Slower than editing in place; the trade is that the revision you
are running is written in `flake.lock` and can be rolled back. While actively
hacking, `just emacs-dev ~/emacs-config` skips the round trip entirely.

**⚠ Migration, read before switching.** `~/.config/emacs/modules` is currently a
real writable directory and becomes a store symlink. home-manager refuses to
clobber a real directory, so an activation step **moves it to
`~/.config/emacs/modules.pre-flake-input`** first. That is deliberate: under the
old scheme a hand-edit there could silently have become your live config, so
those files may be the only copy of something.

```sh
just update-emacs && just build      # dry build first
just switch
diff -ru ~/.config/emacs/modules.pre-flake-input ~/emacs-config/modules
# nothing you care about? then: rm -rf ~/.config/emacs/modules.pre-flake-input
```

---

## 2026-08-06 (a) — the seforim system was dead, and nothing could have told you

Acting on finding 1.1 of `lamdan/shaulos-config-2026-08-06.md`. This is the
root-cause fix, not the symptom fix.

**The symptom.** Five of the six seforim modules did not load — **1,569 of the
system's 1,775 lines.** No mefarshim linking, no search layer, no study log, no
bookmarks, no TOC, no reader mode, no dashboard. Only `10-seforim-core` (which
requires nothing) survived.

**Why.** A module's feature symbol *is* its filename. The essentials/extras
split renumbered the tree; `11`–`15` kept requiring the pre-split names
(`14a-seforim-core` …). Nothing provided those, `require` signalled, and
`init.el` caught it in `condition-case` — deliberately, so one broken module
can't take the session down. It logged one line to `*Messages*` and carried on.

**Why nothing caught it — this is the actual finding.** `tools/verify.sh`
existed the whole time and byte-compiles every module. It ended its pipeline
with:

```sh
... | grep -vE "…|Cannot open load file.*no such|…" || true
```

Three independent reasons it could never have helped: `|| true` pinned the exit
status at 0; even without it a pipeline reports `grep`'s status, not Emacs's;
and the filter dropped *the exact message an unresolvable `require` produces*.
`modules/README.md` claimed "`tools/verify.sh` will tell you if they drift." It
could not tell you anything. Wiring it into CI as it stood would have produced a
green check over 1,569 lines of dead elisp.

Meanwhile `nix flake check` ran statix and deadnix over `.nix` files only.
Nothing in this repo had ever looked at the elisp — which is ~3× the Nix
configuration by line count.

**What was fixed**

- The 12 stale `require` forms across `11`–`15`. Prose and `#+TITLE`s that
  referenced modules by *number* now reference them by *name*, since the
  numbers are the part that rots.
- Six `extras/*.org` modules were **untracked**: `01-hebrew-completion`,
  `02-hebrew-org`, `03-hebrew-typesetting`, `06-torah-search`,
  `16-seforim-integration`, `17-hydras`. A flake copies the *git tree* to the
  store, so they existed on exactly one machine — and the writable
  `~/.config/emacs/modules` sync never deletes, so that machine kept a stale
  copy from an earlier deploy and never noticed. Now tracked.

**What was fixed so it cannot happen again**

- **`tools/check-modules.sh`** (new) — static consistency over the module tree.
  No Emacs, no packages, no network, ~1 second. Verifies: `provide` matches
  filename and is unique; explicit `:tangle` target and `;;; name.el ---`
  header match; **every local `require` resolves to a module that exists**;
  dependencies point essentials → extras and never back, and only backwards in
  load order within a group; no orphaned `.el`; no `my/module-enabled-p`
  capability gate naming a module that isn't there; every `.org` tracked by git.
- **`tools/verify.sh`** — rewritten so it *can fail*. Emacs's exit status is
  captured before anything touches the pipeline, `Cannot open load file` is
  surfaced rather than hidden, and only genuine noise is filtered. It also no
  longer points `package-user-dir` at a non-existent `~/.emacs.d/elpa` on Nix,
  where the packages are on the Emacs binary's own load-path.
- **`nix flake check` now checks the elisp** — two new checks, `emacs-modules`
  (the static pass) and `emacs-bytecompile` (tangle + byte-compile against the
  real package set). `just check-emacs` and `just verify-emacs` run them
  directly.
- **`emacs-package.nix`** (new) — the Emacs package set, factored out of
  `default.nix`'s `let`. A verification job that compiles against a *different*
  package set than the one you run is verifying a lookalike; this makes the
  flake check build the identical Emacs.
- **`init.el`** — a failed module now raises `display-warning` at `:error`
  level, so the *Warnings* buffer pops and stays, instead of one line in
  `*Messages*` that scrolls away unread. `M-x my/load-report` lists what failed
  and why, and names `check-modules.sh` when the error looks like this one.
- **`.gitattributes`** (new) — `eol=lf` for `*.sh`/`*.nix`/`*.el`/`*.org`. Those
  scripts now execute inside a Nix build, and a CRLF shebang fails with `bad
  interpreter: /usr/bin/env^M`.

**Known limitation, stated deliberately.** This does *not* decouple module
identity from load order — renumbering still renames a module and still
invalidates every reference to it. Doing that properly means changing the
tangle target of all 40 modules, and it could not be tested from the Windows
mirror. What changed is that breaking the coupling is now **loud**: a renumber
that misses a dependant fails `nix flake check` instead of silently deleting a
subsystem. See `modules/README.md` → *Renumbering a module*.

**Verify on the machine.** Entry (b) above moved these tools into the
`emacs-config` repo, so run them there — `just check-emacs` / `just
verify-emacs` no longer exist here:

```sh
cd ~/emacs-config                  # or wherever you clone it
bash tools/check-modules.sh        # expect: "check-modules: 40 modules OK"
nix flake check                    # + the real tangle & byte-compile

cd ~/nixOS_config-specializations
just update-emacs && just switch
# then, in Emacs:  M-x my/load-report     → "All modules loaded cleanly."
#                  M-x seforim-mefarshim  → should exist
```

The byte-compile check is new and has never run. If it fails on a module that
`check-modules.sh` passes, that is a *real* finding — a syntax error, or a
`require` of a package missing from `emacs-package.nix` — not a false positive.

---

## Do this on the machine (in order)

1. **Lock the new inputs** (adds sops-nix and emacs-config). `flake.lock` was
   authored off-machine and has no entry for either — **nothing will evaluate
   until this runs**, and as of entry (o) nothing will quietly paper over it
   either: every other recipe passes `--no-update-lock-file`.
   ```sh
   just lock                  # nix flake lock, then the diff
   ```
   Commit and push `flake.lock` — CI's `lock` gate is red until you do, and the
   other three gates skip.
2. **Evaluate, then lint.** `just eval` is the fast one: it forces the whole
   module system and builds nothing, so it finds a bad option or a typo'd
   package in minutes.
   ```sh
   just eval
   just fmt && just check     # nix fmt ; then statix, deadnix, Emacs, the closure
   ```
   First `just check` may list pre-existing statix/deadnix findings — fix or
   ignore. Note that it now also **builds the system closure**, so the first run
   is long and every one after it is cached.
3. **Dry build** before switching, and ask the result whether it is what the
   README says:
   ```sh
   just build
   just closure               # build + tools/check-closure.sh
   ```
4. **Switch**: `just switch`. Then reboot and test each specialisation from the
   systemd-boot menu (niri, hyprland, study, minimal).
5. **Emacs** — nothing to copy any more. The config is the `emacs-config` flake
   input and the modules arrive pre-tangled; see entry (b) at the top,
   including the one-time `modules.pre-flake-input` migration.
   ```sh
   just update-emacs      # lock the input
   ```
6. **Secrets (optional)** — follow `secrets/README.md` to set up sops-nix, then
   uncomment the secret blocks in `modules/system/secrets.nix`. Until then the
   secrets module is inert.

## Bugs fixed (were broken)

- `awww` → `swww` in niri + hyprland (the package `awww` does not exist — this
  was an evaluation error; wallpaper daemon + `swww img`).
- `modules/home/yazi.nix`: rewritten from malformed Lua (a non-existent config
  API, plus a `run = run =` typo) to the real `programs.yazi` TOML surface.
- Hyprland window rules: `match:class … float on` (unreleased syntax) →
  documented `windowrule = float, class:^(…)$` form; removed invalid Sway-style
  `preselect` binds.
- niri keyboard: `kb_options = …` → `options "…"` (valid KDL) so caps→escape and
  the layout toggle actually apply.
- `file-sync.nix`: `StartLimitBurst`/interval moved from `serviceConfig` (where
  systemd ignores them) to the Unit level.
- Emacs `services.emacs.client.arguments`: `"-a ''"` split into `"-a" ""`.
- Git email placeholder `shaul@example.com` → `myConfig.email` (real address).
- Wallpaper path unified to the nix-store path (was a hardcoded
  `/home/shaul/nixos-config/…` that broke if the repo moved).
- Rebuild alias uses `myConfig.flakePath` (was `~/nixos-config`, wrong name).

## Inefficiencies fixed

- **niri & study specialisations now import `common.nix`** — previously they
  booted with no zsh/p10k/aliases (silent shell regression).
- New `modules/home/wayland-common.nix` holds the shared Wayland toolkit that
  was copy-pasted across `home/niri.nix` and `home/study.nix`.
- **Removed double-started daemons**: mako/udiskie/waybar were launched by *both*
  the compositor module and a systemd user service. Now the compositor module is
  the single source (added `spawn-at-startup "mako"` to niri).
- `modules/home/palette.nix`: one source of truth for the Tokyo-Night ricing
  colors (were duplicated across waybar/lock/niri/hyprland).
- Removed the redundant `firefox` package entry (already enabled via
  `programs.firefox`), and the stale `combined.txt` dump.

## Added

- Repo hygiene: `.gitignore`, `README.md`, a `justfile`, and flake `formatter` /
  `checks` (statix + deadnix) / `devShells` — no new inputs required for these.
- Reproducible Emacs: repo-managed `modules/home/emacs/modules/*.org`, staged and
  copied to a writable dir so runtime tangling still works.
- sops-nix scaffold (input + guarded module + `.sops.yaml` + docs), inert until
  you create `secrets/secrets.yaml`.
- `modules/system/hardware.nix`: Bluetooth (+blueman), zram (zstd, 50%),
  `boot.tmp.cleanOnBoot`, thermald, and TLP power management.
- Flatpak (`services.flatpak.enable`) — portals were already configured.
- Hardened `study-offline.nix` into a genuine airgap: NM/wifi/Bluetooth off,
  firewall deny-all, and sshd/onedrive/file-sync disabled (also fixes the ~90s
  boot stall waiting on network-online.target).

## Deliberately NOT changed (flagged for you to decide)

- **Secure boot (lanzaboote)**: needs hands-on key enrollment (`sbctl`) and
  migrating off systemd-boot — too risky to wire blind. Do it as a focused pass.
- ~~**Three overlapping sync tools**: `services.onedrive` + `onedriver` package +
  rclone file-sync. Pick the ones you actually use.~~ — **done 2026-08-06 (d)**:
  one module (`modules/system/data.nix`), `onedriver` deleted; and
  **(j)**: `services.onedrive` deleted too, so the count is one.
- ~~**QT vs Stylix theming fight** (many `mkForce breeze`/`kde` in core + desktop):
  functional but messy; left alone to avoid regressing your Plasma look.~~ —
  **done 2026-08-06 (h)**: it was not functional-but-messy. The stylix target
  that computes `kde`/`breeze` was switched off and its answer hand-copied four
  times, and one line of the same fight (`gtk.gtk4.theme = null`) was an
  evaluation error. `modules/system/appearance.nix` states it once.
- **`nix-ld` `steam-run.args.multiPkgs` hack**: fragile across nixpkgs bumps but
  currently works — left as-is.
- `pkgs.ollama-cpu` — verified this attribute is valid; no change needed.

---

# 26.05 + Lix upgrade (2026-08-02)

Also authored off-machine — **untested**. Work through this on the NixOS box.

## Do this on the machine (in order)

1. **Relock.** Every input URL changed and `flake.lock` was already stale (it
   predates the sops-nix input, so it was never re-locked after that pass):
   ```sh
   just update            # nix flake update
   ```
2. **Build, don't switch.** This is a cross-release jump plus a new Nix
   implementation; the first build is large:
   ```sh
   just build
   ```
3. **Switch.** The nix-daemon restarts here as it becomes Lix:
   ```sh
   just switch
   ```
4. **Verify Lix took:**
   ```sh
   nix --version          # expect: nix (Lix, like Nix) 2.94.x
   ```
5. **Reboot** — you're crossing to a systemd stage-1 initrd and kernel 6.12 →
   6.18. If the new initrd misbehaves, pick the previous generation at the
   systemd-boot menu; `configurationLimit = 10` means it's still there.
6. Re-check the specialisations (`niri`, `hyprland`, `study`, `minimal`) boot —
   they're the least-exercised paths and plasma-manager/stylix churn lands there.

`nixos-version` will still say "current" — see the last note below.

## What changed

- **nixpkgs `nixos-unstable` → `nixos-26.05`.** The lock was pinned at ~2026-04-30,
  i.e. just *before* the 26.05 branch point, so this is a genuine upgrade, not a
  downgrade to stable. 26.05 "Yarara" is supported through 2026-12-31.
- **home-manager `master` → `release-26.05`**, **stylix `danth/stylix` →
  `nix-community/stylix#release-26.05`** (stylix moved orgs; its release branch
  must match nixpkgs + HM or you get option-set mismatches). Stylix now also
  `follows` our nixpkgs — previously it didn't, so the lock carried a second
  full nixpkgs (`nixpkgs_2`) just for stylix. One fewer eval, one fewer skew.
- **plasma-manager stays on `trunk`** — it has no release branches, only `trunk`,
  which targets home-manager *master*. It `follows` our pinned HM, so if trunk
  starts using an API that isn't in `release-26.05`, pin it to a rev. This is the
  single most likely thing to break on a future `just update`.
- **sops-nix stays on master** (no release branches; tracks nixpkgs, fine on stable).
- **New `nixpkgs-unstable` input.** The `unstable` special-arg is no longer a
  no-op alias for `pkgs` — it's a real second nixpkgs, threaded through
  `specialArgs` into the host config, every specialisation, and home-manager's
  `extraSpecialArgs`. Use it as `unstable.foo` for the odd package worth chasing.
- **Lix replaces CppNix**: `nix.package = pkgs.lixPackageSets.stable.lix`
  (Lix 2.94 in 26.05; `lixPackageSets.latest` is 2.95 if you want it). Lix is a
  fork of Nix 2.18 — same store layout, same store DB, same flake semantics, so
  there's no `/nix` migration and nothing gets re-downloaded. The daemon restarts
  during `switch`; that's the whole migration.

## Checked against the 26.05 backward-incompatibility list — no action needed

- `fileSystems.<name>.fsType` lost its default: both entries in
  `hardware-configuration.nix` already set it explicitly.
- systemd stage-1 initrd is now the default. No LUKS and no `/dev/root`
  references here, so nothing to adjust.
- `system.rebuild.enableNg` removed (bash `nixos-rebuild` is gone) — never set it.
- `linux_hardened` / `linux-rt` / `profiles/hardened` removed — none in use.
- `services.xserver` now *errors* on unknown `videoDrivers` instead of ignoring
  them — `videoDrivers` isn't set.
- dbus → dbus-broker by default; `services.dbus.enable` and
  `services.dbus.packages` are unaffected.
- `services.openssh.settings.AcceptEnv` now needs a list — not set.

## Deliberately NOT changed

- **`system.stateVersion` / `home.stateVersion` stay at `25.11`.** These are not
  version numbers to keep current — they declare which release's *stateful*
  defaults your existing data was created under. Bumping them silently changes
  service defaults out from under live state. Leave them until you rebuild the
  machine from scratch.
- **`system.nixos.version = "current"`** in `core.nix` is why `nixos-version`
  won't tell you you're on 26.05. Cosmetic, left alone — but that's the reason.
