;;; init.el --- Portable modular loader (NixOS / Linux / Windows / macOS) -*- lexical-binding: t; -*-
;;
;; ONE config, everywhere.  This file is the single entry point on every
;; machine.  It is deployed verbatim to `user-emacs-directory' (i.e.
;; ~/.config/emacs on Nix/Linux, ~/.emacs.d on Windows) next to a `modules/'
;; directory holding the numbered literate modules (NN-name.org -> NN-name.el).
;;
;; Package sourcing is auto-detected in 00-core:
;;   * Nix/distro  -> packages already on the load-path, used as-is.
;;   * Fresh box   -> use-package auto-installs from MELPA (portable mode).
;;
;; The .org files are the source of truth; stale/missing .el are re-tangled
;; on startup (only when needed, so steady-state startup pays nothing).

;; ---------------------------------------------------------------------------
;; Post-startup GC — early-init set it huge; drop to a sane value.  gcmh
;; (configured in 00-core) then manages GC adaptively for the session.
;; ---------------------------------------------------------------------------
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;; ---------------------------------------------------------------------------
;; Per-OS tweaks (guarded; no-ops on other systems).
;; ---------------------------------------------------------------------------
;; Portable optimization (helps every OS): only probe Git on file visit, not
;; SVN/CVS/Bzr/Hg/… — you only use Git.  If you ever need another VCS, add it.
(setq vc-handled-backends '(Git))

(when (eq system-type 'windows-nt)
  ;; Windows subprocess/pipe I/O is slow — hurts magit, LSP, ripgrep most.
  ;; These are all no-ops / undefined on other systems, hence the guard.
  (setq w32-pipe-read-delay 0)                  ; don't sleep between pipe reads
  (when (boundp 'w32-pipe-buffer-size)
    (setq w32-pipe-buffer-size (* 64 1024)))    ; bigger pipe buffer
  (setq w32-get-true-file-attributes nil))      ; skip expensive stat()

;; Make common tool dirs visible to Emacs subprocesses (rg/fd/git/node/cargo/
;; LSP servers) no matter how Emacs was launched.  Only existing dirs are added.
(let ((extra
       (pcase system-type
         ('windows-nt
          (list (expand-file-name "~/scoop/shims")
                (expand-file-name "~/scoop/apps/nodejs/current/bin")
                (expand-file-name "~/.cargo/bin")
                "C:/Program Files/Git/bin"
                "C:/Program Files/Git/usr/bin"
                "C:/msys64/mingw64/bin"))
         (_
          (list (expand-file-name "~/.local/bin")
                (expand-file-name "~/.cargo/bin")
                (expand-file-name "~/.nix-profile/bin")
                "/usr/local/bin"
                "/opt/homebrew/bin")))))
  (dolist (dir extra)
    (when (file-directory-p dir)
      (add-to-list 'exec-path dir)
      (setenv "PATH" (concat dir path-separator (getenv "PATH"))))))

;; Native compilation — enable once a libgccjit toolchain is on PATH; falls
;; back silently to byte-code otherwise.
(when (and (fboundp 'native-comp-available-p) (native-comp-available-p))
  (setq native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-jobs-number 4))

;; Keep Customize noise out of the tracked config.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil t))

;; ---------------------------------------------------------------------------
;; Locate the module directories (works deployed OR run in place from the repo).
;; ---------------------------------------------------------------------------
;; The modules are split in two, and the split is the whole architecture:
;;
;;   essentials/  a good general Emacs configuration.  Nothing in here knows
;;                anything about Hebrew, or about a seforim library.  Delete
;;                `extras/' entirely and this still stands on its own.
;;   extras/      the personal half: Hebrew, RTL, the seforim system, the rich
;;                footnote apparatus.  Layers ON TOP of essentials.
;;
;; Load order is essentials first, then extras, so the dependency can only ever
;; point one way.  That is enforced by construction here rather than by
;; everyone remembering it.
(defvar my/modules-root
  (let ((sub (expand-file-name "modules/" user-emacs-directory)))
    (if (file-directory-p sub)
        sub                                   ; deployed: <ued>/modules/<group>/
      user-emacs-directory))                  ; in place: init.el next to them
  "Directory holding the module group directories.")

(defvar my/module-groups '("essentials" "extras")
  "Module group directories under `my/modules-root', in load order.")

(defvar my/modules-dirs
  (let ((dirs (delq nil
                    (mapcar (lambda (g)
                              (let ((d (expand-file-name g my/modules-root)))
                                (and (file-directory-p d) (file-name-as-directory d))))
                            my/module-groups))))
    ;; Fall back to a flat layout so an older checkout, or a hand-made deploy
    ;; that never split, still boots instead of silently loading nothing.
    (or dirs (list (file-name-as-directory my/modules-root))))
  "Directories containing the numbered `NN-name.el' modules, in load order.")

;; Kept for anything that still refers to a single directory (e.g. the
;; auto-tangle-on-save hook and `M-x my/open-modules').
(defvar my/modules-dir (car my/modules-dirs)
  "First entry of `my/modules-dirs'.  See that variable.")

(dolist (dir my/modules-dirs) (add-to-list 'load-path dir))

;; ---------------------------------------------------------------------------
;; Auto-tangle: regenerate any .el whose .org source is newer (or missing).
;; Only touches org (a startup cost) when something is actually stale.
;; ---------------------------------------------------------------------------
(defun my/tangle-stale-modules ()
  "Tangle every `*.org' under `my/modules-dirs' whose `.el' is missing or older."
  (let (stale)
    (dolist (dir my/modules-dirs)
      (dolist (org (directory-files dir t "\\.org\\'"))
        (let ((el (concat (file-name-sans-extension org) ".el")))
          (when (or (not (file-exists-p el))
                    (file-newer-than-file-p org el))
            (push org stale)))))
    (when stale
      (require 'org)
      (require 'ob-tangle)
      (let ((coding-system-for-write 'utf-8-unix)
            (org-confirm-babel-evaluate nil))
        (dolist (org (nreverse stale))
          (condition-case err
              (progn (message "init: tangling %s" (file-name-nondirectory org))
                     (org-babel-tangle-file org))
            (error (message "init: tangle failed for %s: %s"
                            (file-name-nondirectory org)
                            (error-message-string err)))))))))
(condition-case err (my/tangle-stale-modules)
  (error (message "init: auto-tangle skipped: %s" (error-message-string err))))

;; ---------------------------------------------------------------------------
;; Which modules may load on this OS.  Default: yes.  A few are gated.
;; ---------------------------------------------------------------------------
;; Gate on CAPABILITY, not operating system.  "Is this Windows?" is the wrong
;; question -- a Fedora box with no C toolchain cannot build vterm either, and
;; a Debian box has no use for nixos-rebuild helpers.  Asking what the machine
;; can actually do makes the same file correct on every distro.
;;
;; This runs before 00-core, so `my/package-usable-p' does not exist yet and
;; the checks below are deliberately self-contained.
;; Gate on the module's NAME, not its number.  Renumbering a module — which the
;; essentials/extras split did to most of them — must not silently un-gate it,
;; and a `pcase' on "25-nix-system" fails silently the moment that file becomes
;; "22-nix-system": the gate stops matching, the module loads everywhere, and
;; nothing tells you.
(defun my/module-name (base)
  "Strip the ordering prefix from BASE: \"22-nix-system\" -> \"nix-system\"."
  (if (string-match "\\`[0-9]+[a-z]?-\\(.*\\)\\'" base)
      (match-string 1 base)
    base))

(defun my/module-enabled-p (base)
  "Return non-nil if module BASE (a filename sans extension) may load here."
  (pcase (my/module-name base)
    ;; Nix/NixOS system helpers: pointless without the Nix tooling present.
    ("nix-system"
     (and (eq system-type 'gnu/linux)
          (or (executable-find "nixos-rebuild")
              (executable-find "home-manager")
              (executable-find "nix"))))
    ;; vterm needs a compiled module: either one is already on the load-path
    ;; (Nix/distro built it) or we need cmake + a C compiler to build it on
    ;; first use.  Where it is unavailable, the `terminal' module (built-in
    ;; shells) is used instead -- that one always loads, so nothing is lost.
    ("vterm"
     (or (locate-file "vterm-module" load-path '(".so" ".dylib" ".dll"))
         (and (executable-find "cmake")
              (or (executable-find "cc")
                  (executable-find "gcc")
                  (executable-find "clang")))))
    (_ t)))

;; ---------------------------------------------------------------------------
;; Load every NN-*.el, group by group, filename order within a group.
;; Zero-padded numbering makes the lexical sort equal the intended load order,
;; so this stays correct as new modules are added — no hand-maintained list to
;; forget (which is how the mefarshim module used to get dropped).
;; ---------------------------------------------------------------------------
(defvar my/load-errors nil "Alist of (module . error-string) from this session.")
(dolist (dir my/modules-dirs)
  (dolist (file (directory-files dir t "\\`[0-9].*\\.el\\'"))
    (let ((base (file-name-base file)))
      (when (my/module-enabled-p base)
        (condition-case err
            (load (file-name-sans-extension file) nil t)
          (error
           (push (cons base (error-message-string err)) my/load-errors)
           (message "⚠ Error loading %s: %s" base (error-message-string err))))))))

(defun my/load-report ()
  "Show which modules failed to load this session, and why."
  (interactive)
  (if (null my/load-errors)
      (message "All modules loaded cleanly.")
    (with-current-buffer (get-buffer-create "*Module load errors*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%d module(s) failed to load.\n\n" (length my/load-errors)))
        (dolist (e (reverse my/load-errors))
          (insert (format "%-28s %s\n" (car e) (cdr e))))
        (insert "\n\"Cannot open load file\" naming a module means some `require'\n"
                "points at a module that no longer exists -- usually because it was\n"
                "renumbered.  Run `tools/check-modules.sh' in the config repo to find\n"
                "every such reference at once.\n"))
      (goto-char (point-min))
      (special-mode))
    (display-buffer "*Module load errors*")))

;; A failed module is deliberately non-fatal: `condition-case' above keeps one
;; broken file from taking the whole session down.  But the failure mode that
;; actually costs you is the quiet one -- a module stops loading and you find
;; out weeks later because a command you use rarely has ceased to exist.  That
;; is exactly how the post-split `require' breakage survived: it printed one
;; line into *Messages*, where it scrolled away unread.
;;
;; So: `display-warning' at :error level, which pops the *Warnings* buffer and
;; stays there.  Cheap, and it is the difference between a bug you notice on
;; the next restart and one you notice next quarter.
(when my/load-errors
  (add-hook 'emacs-startup-hook
            (lambda ()
              (display-warning
               'my/modules
               (format "%d module(s) failed to load: %s\n\nM-x my/load-report for details."
                       (length my/load-errors)
                       (mapconcat #'car (reverse my/load-errors) ", "))
               :error))))

;; Emacs server, so `emacsclient' works (EDITOR/VISUAL in the shell).
(require 'server)
(unless (server-running-p) (ignore-errors (server-start)))

;;; init.el ends here
