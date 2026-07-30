;;; early-init.el --- Runs before the GUI/package system; sets up performance -*- lexical-binding: t; -*-
;;
;; This file loads before `init.el', before any frame is created, and before
;; package.el initializes.  It is the right place for raw performance knobs.
;;
;; PORTABLE: nothing here is OS- or Nix-specific.  The same file works on
;; NixOS, plain Linux, Windows and macOS.  OS-specific tweaks live in init.el.

;; ---------------------------------------------------------------------------
;; Startup GC + I/O — huge impact on startup time everywhere, most on Windows.
;; ---------------------------------------------------------------------------
;; Give startup a big GC budget; a saner value is restored in init.el, and
;; gcmh (00-core) takes over for the rest of the session.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Skip the file-name-handler machinery during startup (regexp scans on every
;; loaded file), then restore it so TRAMP/archives/etc. still work afterwards.
(defvar my--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda () (setq file-name-handler-alist my--file-name-handler-alist)))

;; Read more from subprocesses at once (LSP, git, ripgrep async).
(setq read-process-output-max (* 4 1024 1024)
      process-adaptive-read-buffering nil)

;; ---------------------------------------------------------------------------
;; Packages — we manage them ourselves in 00-core (portable vs. Nix aware).
;; ---------------------------------------------------------------------------
(setq package-enable-at-startup nil
      load-prefer-newer t)

;; ---------------------------------------------------------------------------
;; Native compilation — redirect the *write* side of the eln cache out of the
;; config directory, and silence the compile chatter.
;; ---------------------------------------------------------------------------
;; Use `startup-redirect-eln-cache', never `(setq native-comp-eln-load-path …)':
;; the latter REPLACES the load path and so discards the distro/Nix store's
;; prebuilt .eln directory, silently forcing Emacs to recompile every package
;; from scratch.  This function only redirects where *new* .eln files are
;; written and leaves the system entries intact.
;;
;; Cache goes to XDG cache (~/.cache/emacs) when that is meaningful, else
;; inside the emacs dir — caches do not belong in a config directory, and on
;; NixOS ~/.config/emacs is partly nix-managed.
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (if (memq system-type '(gnu gnu/linux gnu/kfreebsd berkeley-unix darwin))
       (expand-file-name "emacs/eln-cache/"
                         (or (getenv "XDG_CACHE_HOME")
                             (expand-file-name "~/.cache/")))
     (expand-file-name "eln-cache/" user-emacs-directory))))
(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t
      warning-suppress-types '((comp) (bytecomp))
      byte-compile-warnings '(not obsolete free-vars unresolved))

;; ---------------------------------------------------------------------------
;; Frame / UI — set before the first frame to avoid a flash + reflow.
;; ---------------------------------------------------------------------------
(setq frame-inhibit-implied-resize t
      inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      ;; Icon fonts thrash the font cache on Windows -> GC storms.
      inhibit-compacting-font-caches t)

;; Kill chrome early (cheaper than toggling the modes after the frame exists).
(dolist (m '(tool-bar-mode scroll-bar-mode menu-bar-mode))
  (when (fboundp m) (funcall m -1)))
;; menu-bar is useful on macOS (it lives in the global bar, costs nothing).
(when (eq system-type 'darwin)
  (when (fboundp 'menu-bar-mode) (menu-bar-mode 1)))

(provide 'early-init)
;;; early-init.el ends here
