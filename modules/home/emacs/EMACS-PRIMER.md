# Emacs, from zero — a survival primer

A short, practical introduction to Emacs for anyone opening this config for the
first time. It covers only what you need to be productive; the config's own
features are in **[README.md](README.md)**.

## 1. Reading the keys

Emacs describes keys with two modifiers:

- `C-x` means **hold Control, press `x`**.
- `M-x` means **hold Meta, press `x`**. *Meta* is **Alt** on most keyboards
  (on macOS, **Option** — or set the Command key as Meta).
- `C-c p` means Control-`c`, then `p`. Chords in sequence.
- `RET` = Enter, `SPC` = Space, `TAB` = Tab, `DEL` = Backspace, `<f8>` = the F8 key.

Two keystrokes do almost everything at first:

| Key | Meaning |
|-----|---------|
| `C-g` | **Cancel.** Stuck, mistyped, half a command? Press `C-g`. Your escape hatch. |
| `M-x` | **Run a command by name.** Type part of it; completion helps. |

## 2. The vocabulary

- **Buffer** — an open piece of text (a file, or a tool's output). You can have
  hundreds; only some are visible.
- **Window** — a pane showing one buffer. Split the frame into several windows.
- **Frame** — an actual OS window. (Yes, Emacs' names predate modern GUIs.)
- **Minibuffer** — the one-line prompt at the very bottom where you type command
  names, filenames, search terms.
- **Point** — the cursor. **Mark** — the other end of a selection (the *region*).
- **Mode line** — the status bar at the bottom of each window.
- **Major mode** — the buffer's "type" (e.g. Org, LaTeX, Python). **Minor modes**
  layer extra behaviour on top.

## 3. The dozen commands that get you through the day

### Files & buffers
| Key | Does |
|-----|------|
| `C-x C-f` | Open (find) a file |
| `C-x C-s` | Save |
| `C-x s` | Save all |
| `C-x b` | Switch buffer |
| `C-x C-b` | List buffers |
| `C-x k` | Kill (close) a buffer |

### Windows & frames
| Key | Does |
|-----|------|
| `C-x 2` / `C-x 3` | Split below / to the right |
| `C-x o` | Move to the other window |
| `C-x 1` | Keep only this window |
| `C-x 0` | Close this window |
| `C-x 5 2` | New frame |

### Moving & editing
| Key | Does |
|-----|------|
| `C-a` / `C-e` | Start / end of line |
| `M-<` / `M->` | Start / end of buffer |
| `C-s` / `C-r` | Search forward / backward (incremental) |
| `C-SPC` | Set the mark, then move to select a region |
| `C-w` / `M-w` | Cut / copy the region |
| `C-y` | Paste (*yank*); `M-y` cycles earlier cuts |
| `C-/` | **Undo** (repeat to keep undoing) |
| `M-x` then a command | Anything not on a key |

### Getting help (Emacs is self-documenting)
| Key | Shows |
|-----|-------|
| `C-h k` then a key | *What does this key do?* |
| `C-h f` | Describe a function |
| `C-h v` | Describe a variable |
| `C-h m` | Help for the current modes |
| `C-h o` | Describe any symbol |

This config adds **which-key**: pause after a prefix like `C-x` and a popup lists
what can follow. You can explore instead of memorising.

## 4. How this config changes the first-run experience

- **Completion everywhere.** When you type in the minibuffer (commands,
  files, search), a vertical list of candidates appears (vertico) with fuzzy
  matching (orderless). Just type fragments in any order; `RET` selects.
- **Menus, not memory.** Big features are behind *hydras* — a prefix pops up a
  labelled menu. `C-c S` (seforim), `C-c D` (text direction), `C-c T` (tabs).
- **It's literate.** The config is written as Org documents that generate the
  Emacs Lisp. To change something, you edit prose-and-code `.org` files, not raw
  `.el`. See README.md §1.

## 5. Four habits worth forming

1. **`C-g` reflexively** whenever anything feels stuck.
2. **`M-x` + a guess** — command names are discoverable and descriptive
   (`describe-…`, `seforim-…`, `org-…`).
3. **Let completion work** — type fragments, don't spell things out.
4. **Ask Emacs** — `C-h k <key>` and `C-h f <fn>` answer most "what does this
   do?" questions without leaving the editor.

## 6. Where to go next

- Built-in tutorial: `C-h t` (a hands-on tour of the basics above).
- This config's features and keys: **[README.md](README.md)**.
- The Jewish-texts system: **[README-SEFORIM.md](README-SEFORIM.md)**.
