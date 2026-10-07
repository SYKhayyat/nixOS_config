# packages/quicklisp.nix
#
# Quicklisp — the Common Lisp library installer.   upstream:
# https://www.quicklisp.org/   (bootstrap: beta.quicklisp.org/quicklisp.lisp)
#
# Not in nixpkgs, so this is a local package the way clixad, omnirush and otzaria
# are. It is here because `sbcl` alone is not a usable Lisp environment: it has
# no package manager, so there is nothing to install a library *with*. Every
# other entry in toolkit.nix's Development block is a self-contained tool; this
# is the one piece of a Lisp setup that is mutable state, and leaving it to a
# `git clone` into $HOME is exactly the failure mode rule 1 at the top of
# toolkit.nix exists to prevent — a directory Nix does not own, which cannot be
# rolled back and disappears on rebuild with nothing recording that it existed.
#
# ── Why this is a fixed-output derivation ────────────────────────────────
#
# Quicklisp has no build system and no release tarball. `quicklisp.lisp` is a
# bootstrap that, when loaded into an *already running* SBCL, downloads a
# client, an ASDF, a distribution index and the per-system release data, then
# writes the whole thing to a directory it chooses. The install is therefore a
# network fetch, and the Nix sandbox has no network — the first version of this
# file died with "Name service error in getaddrinfo: Temporary failure".
#
# Two ways out, and this takes the first:
#
#   1. Fixed-output derivation. Nix exempts a derivation with an `outputHash`
#      from the sandbox and verifies the result against it instead. This is what
#      FODs exist for — an install that has to fetch. The cost is that the hash
#      has to be discovered once by hand, because the first build cannot know it
#      in advance, and a change upstream re-opens that. `outputHashMode =
#      "recursive"` hashes $out's contents rather than a flat file.
#
#   2. Pin every download. The four metadata files (client-info.sexp, asdf.lisp,
#      distinfo.txt, systems.txt) are individually fetchable, but the tarball
#      that --dist-url would take is 403 for this machine — only the metadata is
#      public — and the release data is ~900 index files plus an archive per
#      system. Pinning that is not a package, it is a mirror.
#
# So: FOD. The `version` below is the Quicklisp *distribution* the bootstrap
# resolves to, which is the only meaningful version this thing has — the
# bootstrap file itself has carried a 2015-01-28 date since long before that.
{
  lib,
  stdenv,
  fetchurl,
  sbcl,
}:

stdenv.mkDerivation {
  pname = "quicklisp";
  version = "2026-01-01";

  src = fetchurl {
    url = "https://beta.quicklisp.org/quicklisp.lisp";
    hash = "sha256-SnpcKuvgcWQXBHhUJnOX4kpE0MzglhJ0EenOnM/rLBc=";
  };

  nativeBuildInputs = [ sbcl ];

  # Fixed-output. See the file header — this is the only reason the build can
  # reach the network at all. `outputHash` is filled in below by the first build,
  # which fails and reports the hash it wanted.
  outputHashMode = "recursive";
  outputHash = "sha256-UAqcWbDBD4Sx8Uj5Lk/RL55F2dnAdvsrV/pJjZoIWaE=";

  # The source is a bare .lisp file, so the default unpackPhase has nothing to
  # unpack: it tries, fails with "do not know how to unpack source archive", and
  # the build dies there. Nix guesses unpackers from the extension; .lisp is not
  # one of them.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Everything Quicklisp writes lives under one root: the distribution itself,
    # plus the per-system release data it fetches when you first quickload
    # something. modules/home/lisp.nix points ~/.sbclrc at the setup.lisp below.
    export QUICKLISP_ROOT="$out/share/quicklisp"
    mkdir -p "$QUICKLISP_ROOT"

    # SBCL compiles every file it loads to a .fasl cache under XDG_CACHE_HOME,
    # and the bootstrap's own package.fasl is loaded *while installing* — before
    # the fetch below, so it cannot be pre-warmed. In the sandbox there is no
    # $HOME (it is /homeless-shelter), so that write fails with SIMPLE-FILE-ERROR
    # "Can't create directory". Point the cache at a real directory in the build.
    export XDG_CACHE_HOME="$TMPDIR/xdg-cache"
    mkdir -p "$XDG_CACHE_HOME"

    # Two things about this invocation, each of which costs an afternoon the
    # first time:
    #
    #   stdin is /dev/null because the bootstrap *prompts* —
    #   `ql-util:press-enter-to-continue` between phases, and its init-file step
    #   asks a yes/no question. With no terminal the prompt reads EOF and
    #   signals UNHANDLED-END-OF-FILE. There is no flag to pass instead.
    #
    #   :client-version nil and :dist-version nil leave the resolution to the
    #   bootstrap's own defaults, which is what makes this resolve to a current
    #   distribution rather than the 2015 client the file's date implies.
    ${sbcl}/bin/sbcl \
      --non-interactive \
      --load "$src" \
      --eval "(quicklisp-quickstart:install :path \"$QUICKLISP_ROOT/\")" \
      < /dev/null

    runHook postInstall
  '';

  meta = with lib; {
    description = "Common Lisp library installer";
    homepage = "https://www.quicklisp.org/";
    license = licenses.bsl11;
    platforms = [ "x86_64-linux" ];
  };
}
