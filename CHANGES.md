# Overhaul — what changed and what you must do next

This pass fixed build-blocking bugs, de-duplicated the config, added repo tooling,
made Emacs reproducible, and added laptop hardware + a real study airgap.
It was authored off-machine, so **nothing here has been `nixos-rebuild`-tested** —
work through the checklist below on the NixOS box.

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
   until this runs**:
   ```sh
   nix flake lock
   ```
2. **Format + lint** to catch anything I couldn't:
   ```sh
   just fmt && just check     # nix fmt ; nix flake check (statix + deadnix)
   ```
   First `just check` may list pre-existing statix/deadnix findings — fix or ignore.
3. **Dry build** before switching:
   ```sh
   just build
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
