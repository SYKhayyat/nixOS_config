# Emacs literate modules

`init.el` loads these modules in filename order (`00-core` … `28-markdown`).
Each is a literate Org file that is **tangled to `.el` on Emacs startup**.

**The `.org` files here are the source of truth.** Edit them, run `just switch`.
Never edit the generated `.el` — it is overwritten on the next tangle.

`.el` files are deliberately *not* checked in: they are build output, and
committing them is how a stale generated file ends up shadowing its source.

## How they reach the running Emacs

`just switch` stages this directory (read-only) to `~/.config/emacs/modules-src`;
the home activation in `../default.nix` copies each `.org` into the *writable*
`~/.config/emacs/modules`, where Emacs tangles it next to the source. That extra
hop exists because the nix store is read-only and Emacs must be able to write the
`.el` beside the `.org`.

The loader itself (`../init.el`, `../early-init.el`) is consumed by `default.nix`
via `.source = ./init.el` — one copy, shared with every non-Nix machine.

## Expected files

```
00-core   01-ui   02-hebrew   03-completion   04-editing   05-navigation
06-org    07-org-roam   08-latex   09-typst   10-context   11-pdf
12-programming   13-magit   14a-seforim-core   14b-seforim-candidates
14c-seforim-search   14d-seforim-extras   14e-seforim-mefarshim
14f-seforim-dream   15-rich-footnotes   16-hydras
17-utils   18-academic   19-hebrew-extra   20-projectile   21-local-ai
22-dirvish   23-vterm-pro   24-scholar-search   25-nix-system
26-terminal   27-tabs   28-markdown
```

The loader globs `NN-*.el` in filename order — there is no list to maintain in
code, so this one is documentation only. Drop in a `29-foo.org` and it loads.

Missing modules are non-fatal: `init.el` wraps each `require` in
`condition-case`, so it logs `Failed: <module>` and continues.
