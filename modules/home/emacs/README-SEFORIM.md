# Seforim system — what changed & how to run it

This documents the six "seforim" modules — `extras/10-seforim-core` through
`extras/15-seforim-dream` — after the 2026 rewrite. It is written to be read by
a human *or* a future AI agent maintaining this config.

> **TL;DR of the current state:** search works on pointed Hebrew; mefarshim
> linking runs against the Otzaria corpus; a **hybrid** keypress (`o`) jumps from
> your `.org` library into the line-accurate Otzaria twin; and a **dream layer**
> (15-seforim-dream) adds bookmarks, a per-book TOC, a non-destructive reader mode, a
> reference-jump index, optional recoll search, and a dashboard. Everything runs
> on **Windows, Linux and macOS**.

> ### ⚠ It was all dead, and this is how it happened
>
> Between the essentials/extras split and 2026-08-06, **five of these six
> modules did not load at all** — 1,569 of the system's 1,775 lines. Everything
> above except `10-seforim-core` was inert: no mefarshim linking, no search
> layer, no study log, no bookmarks, no TOC, no reader mode, no dashboard.
>
> The split renumbered every module, and a module's feature symbol *is* its
> filename. `11`–`15` kept requiring the pre-split names (`14a-seforim-core`
> and friends). Nothing provided those, so `require` signalled — and `init.el`
> catches module load errors on purpose, so one broken file can't take the
> session down. It logged one line to `*Messages*` and carried on. No crash, no
> failing build. The only symptom was `M-x seforim-mefarshim` not existing.
>
> Fixed, and — more to the point — now impossible to reintroduce quietly:
> `tools/check-modules.sh` fails the build on any `require` that doesn't
> resolve, and it runs as part of `nix flake check`. See
> `modules/README.md` → *Renumbering a module*.
>
> **If you are reading this after a rename and something here doesn't work,
> run `just check-emacs` before you debug anything else.**

## The bugs that were fixed

| Symptom (from `toFix.txt`)                | Cause                                                                 | Fix |
|-------------------------------------------|----------------------------------------------------------------------|-----|
| "Directory picking starts on wrong dir"   | Hard-coded `~/Documents/seforim/`; casing/location mismatch on NixOS | `seforim--default-directory` auto-detects `seforim`/`Seforim`; `seforim--base-dir` falls back to it. |
| "Directory picking returns error"         | `seforim--choose-dirs` prompt machinery + non-existent path          | Removed that machinery; the 5 commands drive stock Consult in the base dir. |
| "Searching inside files does not work"    | `seforim-search-rg` ran **plain** ripgrep; niqqud in texts never matched a plain query | `seforim-search-rg`/`-rga` bind a **niqqud-insensitive Consult regexp compiler** (`seforim--niqqud-regexp-compiler`, 10-seforim-core). Type plain Hebrew, match pointed text. |
| "Faster" / dead weight                    | ~200 lines of unused async engine using changed Consult internals    | Deleted; the code path is now small and version-stable. |

## Files

- **10-seforim-core** core: options, Hebrew numerals, **niqqud compiler**, path auto-detect.
- **11-seforim-candidates** file opening (normal / new tab / external) + study-log state.
- **12-seforim-search** the 5 search commands (niqqud-insensitive rg/rga, fd, plocate).
- **13-seforim-extras** daf jump, study-log browser, niqqud isearch, status, Embark actions.
- **14-seforim-mefarshim** Otzaria-style mefarshim (commentary) linking **+ the hybrid twin-opener**.
- **15-seforim-dream** **NEW** — dream extras: bookmarks, TOC sidebar, reader mode,
  reference jump, recoll, dashboard.

All are pure-Emacs and cross-platform. On Windows note two hard-won rules baked
into the code: (1) **don't override the process coding system** — the default
locale coding is what lets `rg` match Hebrew; (2) enumerate Hebrew-named files
with `directory-files-recursively` + `string-suffix-p`, not `fd`/anchored
regexps, which are unreliable on non-ASCII paths there.

## Activate it

Nothing to wire up by hand: `init.el`'s **glob loader** loads every `NN-*.el` in
each group directory in filename order, so everything in `modules/extras/` is
picked up automatically (this is exactly the drift that used to drop the
mefarshim module). Just have the `.org` files present; they tangle on first
start.

These modules all live in **`modules/extras/`** — the personal half of the
config. `modules/essentials/` is a general Emacs setup that knows nothing about
any of this, and extras loads after it, so anything here may build on
essentials but never the other way round. The few places the library reaches
back into the base config — the dirvish quick-access entry, the ibuffer
"Seforim" group, `G` in pdf-view — are gathered in
`extras/16-seforim-integration`.

- `seforim-directory` is auto-detected (`~/Documents/seforim`, any casing).
  Override if needed: `(setq seforim-directory "~/Documents/seforim/")`.
- `seforim-otzaria-directory` is auto-detected too, or set it live with
  `M-x seforim-set-otzaria-directory`.

## Search commands (hydra: `C-c S`)

| Key | Command                | What |
|-----|------------------------|------|
| `f` | `seforim-find-plocate` | filenames, whole system |
| `F` | `seforim-find-fd`      | filenames, exact, library |
| `z` | `seforim-find-fuzzy`   | filenames, fuzzy (full path) |
| `s` | `seforim-search-rg`    | **text in .org**, niqqud-insensitive |
| `S` | `seforim-search-rga`   | **text incl. PDFs**, niqqud-insensitive |

`C-u` before any of them prompts for a different directory.
In a library buffer, `C-c s` starts a niqqud-ignoring isearch.

## Mefarshim linking (Otzaria) — the big new feature

This reproduces how the [Otzaria](https://github.com/Sivan22/otzaria) app links a
base text to its commentaries. It reads Otzaria's **own data**, which is a
separate corpus from your personal `.org` library (your org files carry no link
data, so segment-level linking is only possible on the Otzaria corpus).

### Setup
1. Download the library from
   <https://github.com/Sivan22/otzaria-library/releases> (plain `.txt` + `.json`).
2. Point the config at the folder that contains `links/` and `אוצריא/`:
   ```elisp
   (setq seforim-otzaria-directory "~/Documents/otzaria")  ; auto-detected if standard
   ```
3. `M-x seforim-status` shows whether it was found and how many link files exist.

### Commands (hydra `C-c S`, mefarshim row)
| Key | Command                        | What |
|-----|--------------------------------|------|
| `o` | `seforim-open-in-otzaria`      | **the hybrid bridge** — open the Otzaria `.txt` twin of the book you're reading, matched by title (niqqud-insensitively); then `m`/`M` link line-accurately (`C-u` = new tab) |
| `m` | `seforim-mefarshim`            | from the current line, pick a linked mefaresh and jump (`C-u` = new tab) |
| `M` | `seforim-mefarshim-show`       | side pane listing *all* mefarshim on this line, with clickable refs |
| `T` | `seforim-mefarshim-follow-mode`| keep that pane in sync as you move |
| `x` | `seforim-otzaria-search`       | niqqud-insensitive rg over the whole Otzaria corpus |
| `X` | `seforim-otzaria-browse`       | open the corpus in Dired |

Set/point the corpus at runtime with `M-x seforim-set-otzaria-directory` (prompts
for the folder containing `links/` and `אוצריא/`, validates it, clears caches,
and reports the link-file count). `M-x seforim-status` shows the active path.

### How the linking works (verified against Otzaria source)
- Each book is one `.txt` file; **line number = segment id** (1-based).
- `links/<book>_links.json` is an array of objects:
  `line_index_1` (line in *this* book) → `path_2` + `line_index_2` (the linked
  book + line), plus `heRef_2` (display ref).
- `seforim--otzaria-targets-at-point` matches the current line against
  `line_index_1`, resolves `path_2`→a `.txt` path, reads `line_index_2`, strips
  HTML for display.

### If it finds nothing — assumptions to check (all flagged in 14-seforim-mefarshim's header)
- **A1** links filename = `<book-basename>_links.json`. Verify:
  `(directory-files (seforim--otzaria-links-dir) nil "_links\\.json\\'")`
- **A2** open book is the `line_index_1` side. If a corpus is stored the other
  way, swap `_1`/`_2` in `seforim--otzaria-targets-at-point`.
- **A3** buffer line numbers equal Otzaria's indices (true for the raw `.txt`).
- **A4** `path_2` is rooted at the library dir (handles the double-`אוצריא`
  layout). See `seforim--otzaria-root` / `seforim--otzaria-resolve-path`.

After editing/replacing the library, run `M-x seforim-otzaria-clear-cache`.

### How this compares to Otzaria (the "compare" ask)
- **Same** data + linking model (line-index ↔ line-index JSON).
- **Search**: Otzaria builds a Tantivy index; we use ripgrep with live
  niqqud-insensitive matching. No index to maintain; slightly slower on a huge
  corpus but zero setup.
- **Reading**: Otzaria renders the HTML and shows commentaries in split panes;
  here the base buffer stays raw text (so line indices remain valid) and
  commentaries appear cleaned in a popup/side pane — plus an opt-in **reader
  mode** that prettifies the display without touching the text (see below).
- **Now ported too** (module 15-seforim-dream): bookmarks, per-book TOC, reference search
  (`searchRefs`-style), and more.

## Dream extras (module 15-seforim-dream) — hydra `C-c S`

All optional, all off the startup path, each degrading gracefully when its data
or external tool is absent. State lives in `~/.cache/emacs/seforim/`.

| Key | Command | What |
|-----|---------|------|
| `H` | `seforim-dashboard` | clickable home screen: status, quick actions, recently-studied (each reopens its sefer) |
| `t` | `seforim-toc` | per-book **table of contents** in a side window — Org outline, or the `<h1>..<h4>` headings of a raw Otzaria `.txt`; click a heading to jump |
| `R` | `seforim-otzaria-reader-mode` | **prettified reader** for a raw Otzaria `.txt`: hides HTML markup, styles headings, RTL, comfortable margins. **Non-destructive** — it only adds text properties, so `line = segment-id` stays exact and mefarshim linking keeps working. Auto-enables when you open an Otzaria book (toggle with `seforim-otzaria-auto-reader`). |
| `r` | `seforim-goto-ref` | **reference jump**: jump to any `heRef` by name. Build the index once with `M-x seforim-build-ref-index` (it aggregates every `heRef_2 → (book, line)` from Otzaria's own link files and caches it to disk). |
| `k` / `j` | `seforim-bookmark-set` / `seforim-bookmark-jump` | a **seforim-only** persistent bookmark set (spot + human ref), separate from Emacs' global bookmarks. `seforim-bookmark-delete` removes one. |
| `g` | `seforim-recoll-search` | optional **recoll** indexed full-text search (mostly Linux/macOS). `M-x seforim-recoll-index` builds/refreshes the index under a private config dir whose `topdirs` points at your library. No-ops with a clear message if recoll isn't installed. |

### Reader-mode invariance (why it's safe)
Verified on the real corpus (6,618 books): enabling the reader leaves the buffer
**line count and every line's number unchanged** and the raw text byte-identical
— tags merely become `invisible` text properties. That is the contract mefarshim
linking depends on (assumption A3), so reading prettified and jumping to
commentaries compose cleanly.
