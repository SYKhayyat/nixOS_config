# A portable, literate Emacs — for Torah study, writing & code

One Emacs configuration that runs **the same on NixOS/Linux, Windows, and macOS**,
tuned for Hebrew/Jewish-texts scholarship (*seforim*), academic writing
(LaTeX/Typst/Org), and general programming.

New to Emacs? Read **[EMACS-PRIMER.md](EMACS-PRIMER.md)** first — it explains the
key notation (`C-c`, `M-x`, …), buffers/windows, and the survival commands. This
file assumes that much and describes *this* config.

The *seforim* system has its own deep-dive: **[README-SEFORIM.md](README-SEFORIM.md)**.

---

## 1. What makes it tick (the 60-second model)

- **Literate.** Every module is an Org file, `NN-name.org`, whose code blocks
  *tangle* (extract) to `NN-name.el`. **The `.org` is the source of truth**;
  the `.el` is generated. Edit the `.org`, save, and it re-tangles.
- **Self-assembling loader.** `init.el` loads **every** `NN-*.el` in filename
  order — there is no hand-maintained list to forget. Zero-padded numbers make
  the sort equal the intended load order. Drop in a new `28-foo.org` and it just
  loads.
- **Portable package sourcing, auto-detected** (in `00-core`):
  - **Nix/distro mode** — packages are already on the load-path (installed by
    Nix/Guix/your distro). Nothing is downloaded.
  - **Portable mode** — a fresh machine with none of them: `use-package`
    auto-installs from MELPA. The *same* config bootstraps itself anywhere.
  - Force it with env var `EMACS_PACKAGES=1` (portable) / `0` (nix) if the
    auto-detect ever guesses wrong.
- **Fast.** `early-init.el` raises the GC ceiling and neutralises the
  file-name-handler during startup, then restores both; native-compilation is
  enabled when a toolchain is present. OS-specific speedups (Windows pipe/stat
  tuning) are guarded so they are no-ops elsewhere.
- **Resilient.** A module that fails to load (e.g. a package missing on this
  box) is caught, logged to `my/load-errors`, and reported after startup — it
  never takes the whole config down.
- **Capability-gated, not OS-gated.** Several packages are useless without
  something Emacs cannot install: jinx needs Enchant, pdf-tools needs poppler,
  vterm needs cmake + a C toolchain, envrc needs direnv. Asking *"is this
  Windows?"* is the wrong question — a Fedora box with no `direnv` is the same
  case. So `00-core` provides `my/package-usable-p`, and modules gate individual
  `use-package` forms on it. Crucially the gate is per **package**, not per
  module: jinx lives inside `03-completion`, and a missing Enchant must not take
  vertico/consult/corfu down with it. `M-x my/report-capabilities` lists whatever
  was skipped here and why.

---

## 2. Install / deploy (cross-platform)

**The same files run on every OS.** Only two things differ per platform: *where
the config folder lives*, and *how you install the external tools*. Pick your OS
below.

### Step 0 — where the config folder goes

| OS | Put the config here | Notes |
|----|---------------------|-------|
| **NixOS** | managed by the nix module (§ NixOS below) | declarative — don't hand-copy |
| **Linux** (non-Nix) | `~/.config/emacs/` | Emacs 27+ default |
| **macOS** | `~/.config/emacs/` | same as Linux |
| **Windows** | `%APPDATA%\.emacs.d\` (i.e. `~/.emacs.d/`) | this is your `C:\Users\<you>\AppData\Roaming\.emacs.d` |

Two layouts are accepted anywhere (the loader detects which):

```
Layout A (flat)                 Layout B (modules subdir)
<config>/                       <config>/
  init.el                         init.el
  early-init.el                   early-init.el
  00-core.org  01-ui.org  …       modules/
                                    00-core.org  01-ui.org  …
```

Then **start Emacs**. First launch tangles every `.org → .el` and, in *portable
mode*, installs the Emacs packages from MELPA (one-time; later starts are fast).
Nothing else is required to boot — missing optional tools just disable their
feature, they don't break startup.

### Step 1 — install the external tools for your OS

The config *shells out* to a few command-line tools and a few Emacs packages need
system libraries. Install the ones whose features you want; everything degrades
gracefully if they're absent.

**Core tools (recommended everywhere):** `ripgrep` (rg), `fd`, plus `ripgrep-all`
(rga) for searching inside PDFs.

| OS | One-liner for the core tools |
|----|------------------------------|
| **NixOS** | already in the nix module's `home.packages` |
| **Debian/Ubuntu** | `sudo apt install ripgrep fd-find` then `cargo install ripgrep_all` (rga) |
| **Fedora** | `sudo dnf install ripgrep fd-find ripgrep-all` |
| **Arch** | `sudo pacman -S ripgrep fd ripgrep-all` |
| **macOS** | `brew install ripgrep fd ripgrep-all` |
| **Windows** | `scoop install ripgrep fd` (rga: `scoop install ripgrep-all`) |

**Optional, per feature** (install only what you use):

| Feature / module | Needs | Linux | macOS | Windows |
|---|---|---|---|---|
| PDF viewing (11-pdf) | poppler + `M-x pdf-tools-install` | distro `poppler` | `brew install poppler` | hard — use rga for PDF *search*; view externally |
| Full terminal (23-vterm) | cmake + libvterm + C compiler | distro pkgs | `brew install cmake libvterm` | **skipped on Windows** — 26-terminal (built-in shell) is used instead |
| Spell-check (jinx) | enchant + C compiler | `enchant-2` | `brew install enchant` | optional |
| Notes (07-org-roam) | sqlite | usually present | present | `scoop install sqlite` |
| LaTeX (08) | `latexmk` + `lualatex` | `texlive` | MacTeX | MiKTeX / TeX Live |
| Typst (09) | `typst` (+ `M-x treesit-auto`) | `typst` | `brew install typst` | `scoop install typst` |
| Typst preview in Emacs (09) | a PDF renderer: poppler (pdf-tools) or ghostscript/mupdf (doc-view) | distro `poppler` | `brew install poppler` | `scoop install ghostscript` — else opens externally |
| Markdown preview (28) | `pandoc` (or `cmark`, `markdown_py`) | `pandoc` | `brew install pandoc` | `scoop install pandoc` |
| AI assistant (21) | `ollama` for local models; a key for cloud ones | `ollama` | `brew install ollama` | [ollama.com](https://ollama.com) installer |
| System file search | `plocate` (Linux) | `plocate` | — (uses fd) | — (uses fd) |
| Indexed search (14f `g`) | `recoll` | distro `recoll` | `brew install recoll` | rare — use rg/rga instead |

> **Windows note:** everything Windows-specific is auto-detected and guarded, so
> you never do manual steps to *boot*. `23-vterm` is skipped automatically and
> the built-in **`26-terminal`** (PowerShell/bash/nu tabs, `` C-` ``) takes over.
> Hebrew ripgrep search works out of the box — **do not** set a UTF-8 process
> coding system; the default locale coding is what makes it work.

### Step 2 — verify

`M-x seforim-status` shows the library path and which search tools are found
(`[OK]`/`[MISSING]`). After startup, `M-x view-echo-area-messages` shows any
module that failed to load and why (almost always an optional tool from the table
above).

### NixOS (declarative — the recommended path on Linux)

**This config now lives inside the nix repo** at
`modules/home/emacs/` — `init.el`, `early-init.el`, `modules/*.org`, these docs,
and `tools/`. `default.nix` consumes those *files*
(`home.file.".config/emacs/init.el".source = ./init.el`) rather than duplicating
the loader as a Nix string, so there is exactly one copy of everything and the
Nix and portable paths cannot drift apart. Edit the `.org`, run `just switch`.

Nix builds Emacs with every package baked in and pinned by `flake.lock`, declares
all the external tools above in `home.packages`, runs the Emacs daemon, and
writes `~/.recoll/recoll.conf`. That is why Nix is the better deployment on
Linux even though the loader is identical everywhere.

### Moving between machines

Because the `.org` files are the source of truth and the loader is
self-assembling, migrating is just *copy the folder*: drop the same files in the
Step-0 location on the new OS and start Emacs. Portable mode installs packages;
Nix mode uses the store. No per-machine edits.

### Build tooling (`tools/`)
- `bash tools/tangle.sh [NAME]` — tangle one module (or all), forcing LF output.
- `bash tools/verify.sh` — byte-compile every module against your elpa and
  report warnings/errors.
- `bash tools/deploy.sh [target]` — back up and mirror the config into a live
  Emacs dir. Use this on **non-Nix** machines. Do **not** point it at
  `~/.config/emacs` on NixOS: home-manager owns `init.el` there as a read-only
  store symlink, and the copy will fail or fight it.

---

## 3. Module map

| # | Module | What |
|---|--------|------|
| early-init / init | boot | GC/perf, package auto-detect, glob loader |
| 00 | core | package bootstrap, gcmh, process perf, bidi |
| 01 | ui | theme (doom-one), modeline, fonts (auto-picks an installed mono + Hebrew face), icons, pulsar |
| 02 | hebrew | input methods, RTL helpers |
| 03 | completion | vertico + orderless + marginalia + consult + embark + corfu |
| 04 | editing | editing niceties, reading-room / focus toggles, spell |
| 05 | navigation | avy/ace-window, workspaces (tab-bar), buffer-kill commands |
| 06 | org | org-modern pretty Org, capture, agenda |
| 07 | org-roam | zettelkasten notes (needs sqlite) |
| 08 | latex | AUCTeX + Hebrew preamble/footnote machinery |
| 09 | typst | Typst + tree-sitter |
| 10 | context | ConTeXt support |
| 11 | pdf | pdf-tools (needs poppler) |
| 12 | programming | eglot LSP, envrc, languages |
| 13 | magit | Git UI (+ perf tuning) |
| **14a–14f** | **seforim** | **the Jewish-texts system — see README-SEFORIM.md** |
| 15 | rich-footnotes | multi-level footnote tooling |
| 16 | hydras | the discoverable menus (`C-c S`, `C-c D`, …) |
| 17 | utils | open/reload config, auto-tangle-on-save, window splits, server |
| 18 | academic | citar/bibliography |
| 19 | hebrew-extra | extra Hebrew tooling |
| 20 | projectile | project management (alien indexing) |
| 21 | local-ai | **gptel — local Ollama by default; Claude/OpenAI documented in-module** |
| 22 | dirvish | file manager **+ `<f8>` IDE sidebar** |
| 23 | vterm-pro | full terminal (skipped where cmake/libvterm are absent) |
| 24 | scholar-search | web search engines |
| 25 | nix-system | nixos-rebuild/home-manager helpers (skipped without Nix tooling) |
| 26 | terminal | portable multi-shell tabbed terminal (PowerShell/bash/nu) |
| 27 | tabs | centaur-tabs buffer strip + `C-c T` tabs hydra |
| **28** | **markdown** | **Markdown + live side-by-side preview rendered inside Emacs** |

Bold = added/changed in the unification pass. Module **09 (typst)** also gained a
live side-by-side PDF preview in the same pass.

---

## 4. Key bindings you'll actually use

Most features hang off **hydras** — press the prefix and a menu appears, so you
never have to memorise the leaves.

| Prefix | Hydra / action |
|--------|----------------|
| `C-c S` | **Seforim** — find, search, mefarshim, reader, bookmarks, dashboard (see below) |
| `C-c D` | **Direction** — RTL/LTR, focus/reading width, spell language |
| `C-c T` | **Tabs** — workspaces, buffer tabs, kill/manage |
| `C-c C-n` | **Roam** — notes |
| `<f8>` | Toggle the **IDE file-tree sidebar** (dirvish-side) |
| `` C-` `` | Toggle a **bottom terminal** panel |
| `C-c t n` / `t N` | New terminal tab (PowerShell) / pick shell |
| `C-c < ` / `C-c >` | Previous / next **buffer tab** (centaur) |
| `C-x d` | Dirvish (file manager) |
| `C-c e i` / `e m` / `e r` / `e R` | Open init / open modules dir / reload / restart |
| `C-c a` / `C-c c` | Org agenda / capture |
| `C-c m p` | **Toggle live side-by-side preview** — in Markdown *and* Typst buffers |
| `C-c m r` / `C-c m e` | Markdown: force re-render / export to `.html` |
| `C-c g g` / `C-c g s` / `C-c g m` | AI: chat buffer / send region / menu (switch model) |

### The Seforim hydra (`C-c S`) at a glance
```
FIND FILES            f plocate  F fd(exact)  z fuzzy
SEARCH TEXT           s rg(.org) S rga(+PDF)          ← niqqud-insensitive
MEFARSHIM (Otzaria)   o open twin  m jump  M side-pane  T follow  x search  X browse
READING/NAV           w reading-room  R reader-mode  d daf  i outline  t TOC  e EPUB
EXTRAS                H dashboard  r reference-jump  g recoll  k bookmark  j jump-bookmark
LIBRARY               l study-log  b browse  ? status
```

---

## 5. The seforim system in one paragraph

Point `seforim-directory` at your library (auto-detected at `~/Documents/seforim`,
any casing). **Search works on pointed Hebrew**: type plain, unvowelled Hebrew
and it matches text *with* niqqud (the core fix — `rg`/`rga` bind a
niqqud-insensitive matcher). For **commentary linking** (mefarshim), point
`seforim-otzaria-directory` at the [Otzaria library](https://github.com/Sivan22/otzaria-library/releases)
(plain `.txt` + `.json`); from any base-text line, `m`/`M` list and open every
commentary anchored to that exact line. The **hybrid** workflow: read and search
your curated `.org` library, and press `o` to jump into the Otzaria `.txt`
"twin" of the same book where linking is line-accurate. Plus **dream extras**:
seforim-only bookmarks, a per-book TOC sidebar, a non-destructive prettified
**reader mode** (hides HTML markup, RTL, comfortable margins — *without* shifting
line numbers, so linking stays exact), a `searchRefs`-style **reference jump**
built from Otzaria's own link data, optional **recoll** indexed search, and a
clickable **dashboard** (`H`). Full details: **[README-SEFORIM.md](README-SEFORIM.md)**.

---

## 6. Troubleshooting

- **A module didn't load.** After startup, `M-x view-echo-area-messages` (or
  check `my/load-errors`). Usually a missing package/system library (see §2.3).
- **Hebrew search returns nothing.** Confirm `rg` is on `PATH` (`M-x seforim-status`).
  Do **not** override Emacs' process coding system on Windows — the default
  locale coding is what makes ripgrep match Hebrew; forcing UTF-8 breaks it.
- **Fonts look wrong.** `01-ui` picks the first *installed* mono + Hebrew family
  from a list; install e.g. JetBrains Mono and a CLM/SBL Hebrew font for the best
  look. Missing fonts never error — it just falls back.
- **Edits to `.el` keep disappearing.** Expected — `.el` is generated. Edit the
  `.org`; it re-tangles on save (`my/auto-tangle-module`).
- **Reset a module.** Delete its `.el`; it re-tangles from `.org` on next start.

---

## 7. Design principles (if you're extending it)

1. **Edit `.org`, never `.el`.** The first source block of each module must start
   with the `;;; NN-name.el --- … -*- lexical-binding: t; -*-` line.
2. **Don't hardcode `:ensure t`.** Let modules inherit `use-package-always-ensure`
   so nix/portable auto-detection stays in control. Built-ins get `:ensure nil`.
   (AUCTeX is the one special case — its package name ≠ its feature; see 08.)
3. **Guard OS-specific code** with `(when (eq system-type 'windows-nt) …)` etc.,
   so every module still *loads* on every OS.
4. **Number new modules** with a zero-padded prefix; the loader orders by it.
5. **Keep startup cheap** — defer with `use-package` (`:defer`/`:hook`/`:bind`);
   avoid top-level `require` of heavy packages.
