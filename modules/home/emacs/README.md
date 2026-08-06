# A portable, literate Emacs — in two halves

One Emacs configuration that runs **the same on NixOS/Linux, Windows, and
macOS**, split into two groups that you can take separately:

| | |
|---|---|
| **`modules/essentials/`** | A good general Emacs config: completion, Org, LaTeX/Typst/ConTeXt/Markdown editors, LSP, git, terminals, a file manager. **Nothing in it knows about Hebrew.** Take just this and you have a complete, coherent setup. |
| **`modules/extras/`** | The personal half: Hebrew and RTL, the *seforim* (Jewish-texts) system, the rich-footnote apparatus, Torah web search. **Layers on top of essentials.** |

`init.el` loads essentials first, then extras, so the dependency can only point
one way. Essentials never reaches into extras; where extras needs to appear in
something essentials owns, it appends to a documented extension point (listed in
[modules/README.md](modules/README.md)).

New to Emacs? Read **[EMACS-PRIMER.md](EMACS-PRIMER.md)** first — it explains the
key notation (`C-c`, `M-x`, …), buffers/windows, and the survival commands.

The *seforim* system has its own deep-dive: **[README-SEFORIM.md](README-SEFORIM.md)**.

---

## 1. What makes it tick (the 60-second model)

- **Literate.** Every module is an Org file, `NN-name.org`, whose code blocks
  *tangle* (extract) to `NN-name.el`. **The `.org` is the source of truth**;
  the `.el` is generated. Edit the `.org`, save, and it re-tangles.
- **Self-assembling loader.** `init.el` loads **every** `NN-*.el` in each group
  directory, in filename order — there is no hand-maintained list to forget.
  Zero-padded numbers make the sort equal the intended load order. Drop in a
  new `25-foo.org` and it just loads.
- **Portable package sourcing, auto-detected** (in `00-core`):
  - **Nix/distro mode** — packages are already on the load-path. Nothing is downloaded.
  - **Portable mode** — a fresh machine with none of them: `use-package`
    auto-installs from MELPA. The *same* config bootstraps itself anywhere.
  - Force it with env var `EMACS_PACKAGES=1` (portable) / `0` (nix).
  - ⚠️ **In Nix mode a package that is not in `default.nix`'s `epkgs` list is
    silently absent** — `use-package-always-ensure` is nil, so the form is a
    no-op and the feature simply is not there, with no error. If a feature does
    nothing, check that list first.
- **Fast.** `early-init.el` raises the GC ceiling and neutralises the
  file-name-handler during startup, then restores both; native-compilation is
  enabled when a toolchain is present.
- **Resilient.** A module that fails to load is caught, logged to
  `my/load-errors`, and reported after startup — it never takes the config down.
- **Capability-gated, not OS-gated.** jinx needs Enchant, pdf-tools needs
  poppler, vterm needs cmake + a C toolchain. `00-core` provides
  `my/package-usable-p`, and modules gate individual `use-package` forms on it —
  per **package**, not per module. `M-x my/report-capabilities` lists what was
  skipped here and why. The module-level gate in `init.el`
  (`my/module-enabled-p`) matches on the module **name**, not its number, so
  renumbering cannot silently un-gate anything.

---

## 2. Install / deploy (cross-platform)

**The same files run on every OS.** Only two things differ per platform: *where
the config folder lives*, and *how you install the external tools*.

### Step 0 — where the config folder goes

| OS | Put the config here | Notes |
|----|---------------------|-------|
| **NixOS** | managed by the nix module (§ NixOS below) | declarative — don't hand-copy |
| **Linux** (non-Nix) | `~/.config/emacs/` | Emacs 27+ default |
| **macOS** | `~/.config/emacs/` | same as Linux |
| **Windows** | `%APPDATA%\.emacs.d\` (i.e. `~/.emacs.d/`) | your `C:\Users\<you>\AppData\Roaming\.emacs.d` |

The layout:

```
<config>/
  init.el
  early-init.el
  modules/
    essentials/  00-core.org  01-ui.org  …
    extras/      00-hebrew.org  10-seforim-core.org  …
```

`init.el` also accepts the two group directories sitting directly next to it
(no `modules/` level), and falls back to a flat layout so an older checkout
still boots rather than silently loading nothing.

**Want only the general config?** Delete `modules/extras/`. Nothing in
essentials references it.

Then **start Emacs**. First launch tangles every `.org → .el` and, in *portable
mode*, installs the packages from MELPA (one-time). Nothing else is required to
boot — missing optional tools just disable their feature.

### Step 1 — install the external tools for your OS

**Core tools (recommended everywhere):** `ripgrep` (rg), `fd`, plus `ripgrep-all`
(rga) for searching inside PDFs.

| OS | One-liner for the core tools |
|----|------------------------------|
| **NixOS** | already in the nix module's `home.packages` |
| **Debian/Ubuntu** | `sudo apt install ripgrep fd-find` then `cargo install ripgrep_all` |
| **Fedora** | `sudo dnf install ripgrep fd-find ripgrep-all` |
| **Arch** | `sudo pacman -S ripgrep fd ripgrep-all` |
| **macOS** | `brew install ripgrep fd ripgrep-all` |
| **Windows** | `scoop install ripgrep fd` (rga: `scoop install ripgrep-all`) |

**Optional, per feature** (install only what you use):

| Feature / module | Needs | Linux | macOS | Windows |
|---|---|---|---|---|
| PDF viewing (`11-pdf`) | poppler + `M-x pdf-tools-install` | distro `poppler` | `brew install poppler` | hard — use rga for PDF *search* |
| EPUB (`11-pdf`, nov) | nothing external | — | — | — |
| Full terminal (`16-vterm`) | cmake + libvterm + C compiler | distro pkgs | `brew install cmake libvterm` | **skipped** — `17-terminal` is used instead |
| Spell-check (jinx) | enchant + C compiler | `enchant-2` | `brew install enchant` | optional |
| Notes (`06-org-roam`) | sqlite | usually present | present | `scoop install sqlite` |
| LaTeX (`07-latex`) | `latexmk` + `lualatex` | `texlive` | MacTeX | MiKTeX / TeX Live |
| Typst (`08-typst`) | `typst` (+ `M-x treesit-auto`) | `typst` | `brew install typst` | `scoop install typst` |
| ConTeXt (`09-context`) | `context` (TeX Live scheme-full) | `texlive` | MacTeX | TeX Live |
| Markdown preview (`10-markdown`) | `pandoc` | `pandoc` | `brew install pandoc` | `scoop install pandoc` |
| AI assistant (`20-local-ai`) | `ollama` for local models | `ollama` | `brew install ollama` | [ollama.com](https://ollama.com) |
| Indexed search (extras) | `recoll` | distro `recoll` | `brew install recoll` | rare — use rg/rga |

> **Windows note:** everything Windows-specific is auto-detected and guarded.
> `16-vterm` is skipped automatically and **`17-terminal`** (PowerShell/bash/nu
> tabs, `` C-` ``) takes over. Hebrew ripgrep search works out of the box —
> **do not** set a UTF-8 process coding system; the default locale coding is
> what makes it work.

### Step 2 — verify

`M-x my/report-capabilities` shows which optional packages were skipped and why.
`M-x seforim-status` (extras) shows the library path and search tools. After
startup, `M-x view-echo-area-messages` shows any module that failed to load.

### NixOS (declarative — the recommended path on Linux)

This config lives inside the nix repo at `modules/home/emacs/`. `default.nix`
consumes those *files* (`home.file.".config/emacs/init.el".source = ./init.el`)
rather than duplicating the loader as a Nix string, so there is exactly one copy
and the Nix and portable paths cannot drift. Edit the `.org`, run `just switch`.

### Build tooling (`tools/`)

All of them walk `modules/<group>/`.

- `bash tools/check-modules.sh` — static consistency over the module tree: every
  `provide` matches its filename, **every local `require` resolves to a module
  that exists**, dependencies point essentials → extras and never back, nothing
  is orphaned, every `.org` is tracked by git. No Emacs, no packages, ~1 second.
  Wired into `nix flake check` as `emacs-modules`; `just check-emacs` locally.
- `bash tools/tangle.sh [NAME|GROUP]` — tangle everything, one module, or one
  group, forcing LF output.
- `bash tools/verify.sh [NAME…]` — byte-compile and report errors. Both group
  directories go on the load-path, so cross-group references resolve the way
  they do at runtime. Uses `~/.emacs.d/elpa` if it exists (portable/MELPA
  machines); on Nix the packages are already on the Emacs binary's own
  load-path. Wired into `nix flake check` as `emacs-bytecompile`;
  `just verify-emacs` locally.
- `bash tools/deploy.sh [target]` — back up and mirror the config into a live
  Emacs dir, preserving the group structure. Use on **non-Nix** machines. Do
  **not** point it at `~/.config/emacs` on NixOS: home-manager owns `init.el`
  there as a read-only store symlink.

`check-modules.sh` is the one that matters. It exists because the
essentials/extras split renumbered most of the tree, five modules kept
requiring the pre-split feature names, and **1,569 of the seforim system's
1,775 lines silently stopped loading** — with no crash and a green build, for
weeks. See `modules/README.md` → *Renumbering a module* for the full story and
the invariants it now enforces.

---

## 3. Module map

### `essentials/` — the general config

| # | Module | What |
|---|--------|------|
| early-init / init | boot | GC/perf, package auto-detect, group loader |
| 00 | core | package bootstrap, capability detection, gcmh, process perf |
| 01 | ui | theme (doom-one), modeline, fonts, icons, pulsar |
| 02 | completion | vertico + orderless + marginalia + consult + embark + corfu, jinx |
| 03 | editing | undo-tree, multiple-cursors, olivetti/focus reading room |
| 04 | navigation | avy/ace-window, tab-bar workspaces, ibuffer groups |
| 05 | org | org-modern, capture, agenda, LaTeX export |
| 06 | org-roam | zettelkasten notes (needs sqlite) |
| 07 | latex | AUCTeX, lualatex, SyncTeX, RefTeX |
| 08 | typst | typst-ts-mode + tinymist LSP + **live side-by-side PDF preview** |
| 09 | context | ConTeXt mode, compile/view |
| 10 | markdown | markdown-mode + **live preview rendered inside Emacs** |
| 11 | pdf | pdf-tools (needs poppler), nov (EPUB) |
| 12 | programming | eglot LSP, envrc, languages |
| 13 | magit | Git UI (+ perf tuning) |
| 14 | projectile | project management (alien indexing) |
| 15 | dirvish | file manager **+ `<f8>` IDE sidebar** |
| 16 | vterm | full terminal (skipped where cmake/libvterm are absent) |
| 17 | terminal | portable multi-shell tabbed terminal (PowerShell/bash/nu) |
| 18 | tabs | centaur-tabs buffer strip + `C-c T` tabs hydra |
| 19 | academic | citar/bibliography |
| 20 | local-ai | gptel — local Ollama by default; cloud backends documented in-module |
| 21 | web-search | engine-mode: Google Scholar, nixpkgs, DuckDuckGo |
| 22 | nix-system | nixos-rebuild/home-manager helpers (skipped without Nix tooling) |
| 23 | hydras | the general menus (`C-c C-n` roam, `C-c W` writing) |
| 24 | utils | open/reload config, auto-tangle-on-save, window splits, server |

### `extras/` — the personal config

| # | Module | What |
|---|--------|------|
| 00 | hebrew | bidi/RTL core, Hebrew input, Hebrew fontset, RTL hooks for the prose and typesetting modes, Hebrew doc templates |
| 01 | hebrew-completion | **niqqud-insensitive** Orderless dispatcher, seforim embark actions |
| 02 | hebrew-org | RTL footnote marker + repair command, `article-hebrew` export class, Hebrew capture/roam templates |
| 03 | hebrew-typesetting | Hebrew preambles for LaTeX/Typst/ConTeXt (`C-c p h`) |
| 04 | hebrew-scholarship | gematria, Hebrew date insertion |
| 05 | rich-footnotes | the note-apparatus preambles for all three backends (`C-c p f`) — see §5 |
| 06 | torah-search | Sefaria, Otzar HaChochma |
| **10–15** | **seforim** | **the Jewish-texts system — see [README-SEFORIM.md](README-SEFORIM.md)** |
| 16 | seforim-integration | where seforim hooks into dirvish, ibuffer and pdf-view |
| 17 | hydras | the seforim (`C-c S`) and direction (`C-c D`) menus |

---

## 4. Key bindings you'll actually use

| Prefix | Hydra / action |
|--------|----------------|
| `C-c C-n` | **Roam** — notes |
| `C-c W` | **Writing** — reading room, focus, width, spell language |
| `C-c T` | **Tabs** — workspaces, buffer tabs, kill/manage |
| `C-c S` | **Seforim** *(extras)* — find, search, mefarshim, reader, bookmarks |
| `C-c D` | **Direction** *(extras)* — RTL/LTR, Hebrew input, footnote repair |
| `<f8>` | Toggle the **IDE file-tree sidebar** (dirvish-side) |
| `` C-` `` | Toggle a **bottom terminal** panel |
| `C-c m p` | **Toggle live side-by-side preview** — Markdown *and* Typst |
| `C-c e i` / `e m` / `e r` / `e R` | Open init / open modules dir / reload / restart |
| `C-c a` / `C-c c` | Org agenda / capture |
| `C-c /` + key | Web search (`S` scholar, `p` nixpkgs, `d` ddg; `s` sefaria, `o` otzar in extras) |
| `C-c p h` / `C-c p f` | *(extras)* Insert Hebrew / rich-footnote preamble |
| `M-$` | Correct spelling at point |

---

## 5. The note apparatus (`extras/05-rich-footnotes`)

Parallel footnote blocks — the *Gemara* look — for all three backends. Every
claim below was **compiled and the laid-out PDF read back** on TeX Live 2025
and Typst, not inferred from documentation.

| | Separate stacked blocks | Independent counters | Nesting |
|---|---|---|---|
| **LaTeX** (bigfoot) | yes, B..J | yes, each restarts at 1 | **one direction only** |
| **ConTeXt** (`\definenote`) | yes, 10 classes | yes, with per-class markers (`a,b` / `i,ii`) | any direction |
| **Typst** | **no** — one native series | per *tier*, computed by query | any direction |

Things that were claimed and are not true, now removed or corrected:

- **LaTeX nesting is directional.** `\footnoteB{… \footnote{…} …}` compiles;
  `\footnote{… \footnoteB{…} …}` gives `! \footinsB forbidden in
  \footinsdefault`. The outer note must be the lettered one — the old insertion
  template had it backwards and could never compile.
- **"20 heading levels" was never real** in either LaTeX or ConTeXt.
  `secnumdepth` does not *create* levels (`\subsubparagraph` is undefined), and
  ConTeXt's `\definehead[levelseven][subsubsubsubsection]` makes a *sibling* of
  level five, not a seventh level. The 20 *list* levels are real, verified to L20.
- **ConTeXt's ten classes were one class.** `\definenote[X][footnote]` derives
  from the parent and shares its stream, counter and block — the notes ran
  1..14 in a single sequence. Dropping the parent argument fixes it.
- **`\setupnote` does not set numbering**; `\setupnotation` does. All ten
  classes had been rendering arabic regardless of their declared conversion.
- **LaTeX `fncode` never worked** — `lstlisting` cannot survive a
  `\NewDocumentEnvironment` wrapper, in a note or anywhere else. Removed;
  inline `\fnc` stays.
- **ConTeXt `bodyfont=small\tt`** is a fatal error that took the whole document
  down. `bodyfont=small` compiles.

Typst is the odd one: it has exactly one page-bottom series and no way to add a
second, so `fn1`..`fn5` are *tiers within* that series, each numbering itself
and drawing its own marker. That is genuinely useful and it is not separate
blocks — the module says so rather than implying otherwise. For real stacked
bands see the Ksav project.

---

## 6. Spell checking

English only, via jinx + Enchant. `M-x my/spell-set-language` switches the
buffer to any language tag Enchant has a dictionary for.

**Hebrew spell checking was removed.** Unvowelled Hebrew with optional *ktiv
male*/*chaser* spellings is not what `he_IL` hunspell/aspell dictionaries model,
so nearly every word came back flagged. It was noise, not help. The dictionaries
are gone from `modules/system/cli-tools.nix` too.

---

## 7. Troubleshooting

- **A module didn't load.** `M-x view-echo-area-messages`, or check
  `my/load-errors`. Usually a missing package/system library (§2.1).
- **A feature silently does nothing on NixOS.** Almost always a package that is
  `use-package`'d but missing from `epkgs` in `default.nix`. In Nix mode that is
  a no-op, not an error.
- **Hebrew search returns nothing.** Confirm `rg` is on `PATH`
  (`M-x seforim-status`). Do **not** override the process coding system on
  Windows — the default locale coding is what makes ripgrep match Hebrew.
- **Fonts look wrong.** `01-ui` picks the first *installed* mono family from a
  list; `extras/00-hebrew` does the same for Hebrew. Missing fonts never error.
- **Edits to `.el` keep disappearing.** Expected — `.el` is generated. Edit the
  `.org`; it re-tangles on save (`my/auto-tangle-module`).
- **Reset a module.** Delete its `.el`; it re-tangles from `.org` on next start.

---

## 8. Design principles (if you're extending it)

1. **Pick the group by one question:** would someone who does not read Hebrew
   want this? Yes → `essentials/`. No → `extras/`.
2. **Essentials must never reference extras.** If extras needs to appear in an
   essentials-owned list, essentials exports an extension point and extras
   appends to it. See the table in [modules/README.md](modules/README.md).
3. **Edit `.org`, never `.el`.** The first source block must start with
   `;;; NN-name.el --- … -*- lexical-binding: t; -*-`, and the file must
   `(provide 'NN-name)` matching its filename.
4. **Don't hardcode `:ensure t`.** Let modules inherit `use-package-always-ensure`.
   Built-ins get `:ensure nil`. (AUCTeX is the one special case — its package
   name ≠ its feature; see `07-latex`.) **And add the package to `default.nix`,**
   or it will be silently missing on NixOS.
5. **Guard OS-specific code** with `(when (eq system-type 'windows-nt) …)`.
6. **Gate on the module name, not its number**, in `my/module-enabled-p`.
7. **Keep startup cheap** — defer with `use-package` (`:defer`/`:hook`/`:bind`).
8. **Don't claim what you haven't run.** A comment saying a preamble gives you
   ten parallel note blocks is a promise; if nobody compiled it, it is a guess
   wearing a promise's clothes.
