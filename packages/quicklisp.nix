# packages/quicklisp.nix
#
# Quicklisp's bootstrap, `quicklisp.lisp`, and nothing else.   upstream:
# https://www.quicklisp.org/   (bootstrap: beta.quicklisp.org/quicklisp.lisp)
#
# Not in nixpkgs. `sbcl` alone has no package manager; Quicklisp is the one
# piece of a Lisp setup that is mutable state, so modules/home/lisp.nix runs
# this bootstrap once into ~/.local/share/quicklisp, the way `emacs-install`
# fills elpa/ for Emacs.
#
# ── Why this is no longer a fixed-output derivation ──────────────────────
#
# It used to run the bootstrap *inside* the build, as an FOD, so the store held
# a whole installed Quicklisp. That output was never stable: the bootstrap
# installs "whatever dist is current" (`:dist-version nil`), and pinning a dist
# instead is not possible from here (the dist tarball `--dist-url` would take
# is 403 for this machine; only the metadata is public). When Quicklisp moved,
# the recorded `outputHash` stopped matching, every closure build failed with
# `hash mismatch in fixed-output derivation`, and CI was red for two weeks
# while this machine kept switching only because an old output was still live.
#
# The bootstrap file itself is plain data with a stable hash, so that is all
# the store holds now. The install is a network step at activation, outside
# any derivation — see modules/home/lisp.nix.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "quicklisp-bootstrap";
  # The date the bootstrap file itself carries.
  version = "2015-01-28";

  src = fetchurl {
    url = "https://beta.quicklisp.org/quicklisp.lisp";
    hash = "sha256-SnpcKuvgcWQXBHhUJnOX4kpE0MzglhJ0EenOnM/rLBc=";
  };

  # A bare .lisp file: nothing to unpack, configure or build.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/share/quicklisp/quicklisp.lisp"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Bootstrap file for Quicklisp, the Common Lisp library installer";
    homepage = "https://www.quicklisp.org/";
    license = licenses.bsl11;
    platforms = platforms.all;
  };
}
