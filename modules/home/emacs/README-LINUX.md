# This Emacs on Linux

How the config gets onto a Linux machine, what it needs there, and how to fix it
when it breaks. It covers **both** Linux paths:

- **NixOS** — declarative, via this repo. The recommended path.
- **Any other distro** — copy the files, packages come from MELPA.

New to Emacs itself? Read **[EMACS-PRIMER.md](EMACS-PRIMER.md)** first — it
explains `C-c`, `M-x`, buffers vs. windows, and the dozen commands that get you
through the day. What the config *does* is **[README.md](README.md)**; the
Jewish-texts system is **[README-SEFORIM.md](README-SEFORIM.md)**. This file is
only about *running it on Linux*.

The Windows machine has its own, separate config — see
`~/.emacs.d/README-WINDOWS.md` there. It is a deliberately trimmed subset and is
**not** produced from these files.

---

## 1. Which path am I on?

| | NixOS (this repo) | Other Linux (Debian, Fedora, Arch, …) |
|---|---|---|
| How it installs | `just switch` | `bash tools/deploy.sh` |
| Emacs packages | baked into the Emacs binary by Nix, pinned by `flake.lock` | installed from MELPA on first launch |
| External tools | declared in `home.packages` | you install them (§4) |
| Config location | `~/.config/emacs/` (managed) | `~/.config/emacs/` (yours) |
| Emacs daemon | `services.emacs` starts it | start it yourself |

**Do not mix them.** On NixOS, home-manager writes `~/.config/emacs/init.el` as a
read-only symlink into the nix store; `tools/deploy.sh` tries to `cp` over that
exact path and will fail or fight it. Pick one per machine.

---

## 2. Where everything lives

```
modules/home/emacs/          ← you are here; this is the whole config
├── default.nix              the home-manager module (packages + wiring)
├── init.el                  the loader — ONE copy, used on every OS
├── early-init.el            pre-GUI performance knobs
├── modules/*.org            the 33 literate modules (source of truth)
├── tools/                   tangle.sh · verify.sh · deploy.sh
└── README*.md, EMACS-PRIMER.md
```

`default.nix` consumes `init.el` and `early-init.el` as *files*
(`.source = ./init.el`), not as embedded Nix strings. That matters: it is the
reason the Nix and portable versions of the loader can no longer drift apart,
which is exactly what had happened before.

---

## 3. Install

### NixOS

```sh
cd ~/nixOS_config-specializations
just build      # dry build first — catches evaluation errors
just switch
```

Then start Emacs. First launch tangles every `.org → .el`; later starts skip
anything already current.

> `justfile` hardcodes `host := "desktop"`, and `flake.nix` defines only
> `nixosConfigurations.desktop`. **For a laptop you must add `hosts/laptop/` and
> a matching `nixosConfigurations.laptop` first**, then `just switch host=laptop`.
> There is no laptop host in this repo today.

### Any other distro

```sh
bash tools/deploy.sh                 # → ~/.config/emacs (backs up what's there)
emacs                                # first launch installs from MELPA
```

`00-core` auto-detects that the packages aren't on the load-path and switches to
portable mode. Force it either way with `EMACS_PACKAGES=1` (MELPA) or `0` (use
what's installed) if the guess is ever wrong.

---

## 4. External tools

Emacs shells out to a handful of programs. **Everything degrades gracefully** —
a missing tool disables its feature, it never breaks startup. `M-x
my/report-capabilities` lists what was skipped on this machine and why.

On **NixOS these are already declared** in `default.nix` → `home.packages`; the
table is for other distros.

| Feature | Needs | Debian/Ubuntu | Fedora | Arch |
|---|---|---|---|---|
| Search (core) | `ripgrep`, `fd` | `ripgrep fd-find` | `ripgrep fd-find` | `ripgrep fd` |
| Search inside PDFs | `ripgrep-all` | `cargo install ripgrep_all` | `ripgrep-all` | `ripgrep-all` |
| PDF viewing (11) | poppler + `M-x pdf-tools-install` | `libpoppler-glib-dev` | `poppler-glib-devel` | `poppler-glib` |
| Spell check (03) | enchant + a C compiler | `libenchant-2-dev` | `enchant2-devel` | `enchant` |
| Terminal (23) | cmake + libvterm + cc | `cmake libvterm-dev` | `cmake libvterm-devel` | `cmake libvterm` |
| Notes (07) | sqlite | `libsqlite3-dev` | `sqlite-devel` | `sqlite` |
| LaTeX (08) | `latexmk`, `lualatex` | `texlive-full` | `texlive-scheme-full` | `texlive-meta` |
| Typst (09) | `typst` (+ `tinymist`) | `cargo install typst-cli` | same | `typst` |
| **Markdown preview (28)** | **`pandoc`** | `pandoc` | `pandoc` | `pandoc` |
| **AI (21)** | `ollama` for local models | [ollama.com](https://ollama.com) | same | `ollama` |
| Indexed search (14f) | `recoll` | `recoll` | `recoll` | `recoll` |
| Fast file find | `plocate` | `plocate` | `plocate` | `plocate` |
| Direnv (12) | `direnv` | `direnv` | `direnv` | `direnv` |

---

## 5. Editing the config

**Edit the `.org`, never the `.el`.** The `.el` is generated and will be
overwritten on the next tangle. Saving a module `.org` re-tangles it
automatically (`17-utils`), and `init.el` re-tangles anything stale at startup.

```sh
bash tools/tangle.sh 28-markdown   # tangle one module by name
bash tools/tangle.sh               # tangle all
bash tools/verify.sh               # byte-compile everything, report warnings
```

To add a module, drop in `29-foo.org` with a matching `:tangle` header. The
loader globs `NN-*.el` in filename order — there is no list to update.

On NixOS, after editing: `just switch`. Adding a *package* (not just config)
means editing the `emacsWithPackages` list in `default.nix` too.

---

## 6. What's Linux-only here

- **`25-nix-system`** — `nixos-rebuild` / `home-manager` / GC helpers. Gated on
  the Nix tooling actually being present, so it is skipped on Debian rather than
  erroring.
- **`23-vterm-pro`** — needs a compiled module. Gated on either a prebuilt
  `vterm-module` or cmake + a C compiler. Where it's unavailable, `26-terminal`
  (built-in shells) covers the same ground and always loads.
- **`~/.recoll/recoll.conf`** — written by `default.nix` on NixOS only; on other
  distros run `recollindex` yourself if you want `14f`'s indexed search.
- **The eln cache** goes to `~/.cache/emacs/eln-cache` on Linux (via
  `startup-redirect-eln-cache`), keeping generated artefacts out of the config
  directory.

---

## 7. Troubleshooting

**A module didn't load.** `M-x view-echo-area-messages`, or inspect
`my/load-errors`. Almost always a missing tool from §4.

**A feature is silently absent.** `M-x my/report-capabilities` — it names each
skipped package and the program it wanted.

**Package installs fail with `…/foo-<date>.tar: Not found`** (non-Nix only). The
cached package index is stale: MELPA rebuilds daily and deletes the superseded
tarball. `M-x my/package-refresh`. The config now auto-refreshes any index older
than a week, so this should not recur.

**Hebrew search returns nothing.** Check `rg` is on `PATH` (`M-x
seforim-status`). Do **not** force a UTF-8 process coding system — the default
locale coding is what makes ripgrep match Hebrew.

**Edits to a `.el` keep disappearing.** Expected — it's generated. Edit the
`.org`.

**`just switch` fails after a module edit.** Run `just build` for the full error;
`nix fmt` and `just check` (statix + deadnix) catch most `.nix` mistakes.

**PDF buffers show raw bytes.** `pdf-tools` isn't usable, so `11-pdf` no longer
claims `.pdf` in `auto-mode-alist` — install poppler and run `M-x
pdf-tools-install`.
