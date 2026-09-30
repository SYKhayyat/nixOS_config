# packages/omnirush.nix
#
# Omnirush — a coding-agent CLI for the terminal (free daily tokens, sign-in
# with GitHub).   upstream: https://omnirush.ai
#
# Not in nixpkgs (checked against `pkgs/by-name/om`, 2026-09-29) and not in
# numtide's llm-agents.nix either, which is where opencode and freebuff come
# from — so this is a local package, the way clixad is.
#
# ── Why two fetchurl and not buildNpmPackage ──────────────────────────────
#
# clixad is built with buildNpmPackage because it has a dependency tree to
# install. omnirush has none: `dependencies` is empty and everything else is
# `optionalDependencies`, one prebuilt runtime per os/cpu/libc that npm picks
# by platform. There is nothing for npm to resolve, so a lockfile would be a
# second copy of two URLs and a hash that we would regenerate on every bump —
# the exact thing buildNpmPackage exists to avoid maintaining by hand, bought
# with an npmDepsHash that would have to be re-prefetched each time anyway.
# Two fixed-output fetches state the same facts directly.
#
# The upstream tarball also carries no package-lock.json (its `files` list is
# src, assets, core), so the lockfile would have to be synthesized here and
# would drift from what npm actually resolves on a real install.
#
# ── How the pieces find each other ────────────────────────────────────────
#
# The install layout is npm's own, because the launcher assumes npm's:
#
#   $out/lib/node_modules/omnirush/                      the launcher + core
#   $out/lib/node_modules/omnirush/node_modules/
#       @omnirush-ai/cli-linux-x64/                      bun, fd, rg
#
# `src/runtime.js` resolves the runtime with
# `createRequire(import.meta.url).resolve("@omnirush-ai/cli-linux-x64/package.json")`,
# which walks up from <omnirush>/src looking for a node_modules — so nesting
# the platform package one level down is what makes it found, and a flat
# sibling layout would not be. The agent core needs no resolution at all: it
# ships branded inside the tarball as `core/`.
#
# The prebuilt `bun`/`fd`/`rg` are ordinary glibc ELF binaries, not patchelf'd.
# They run here because modules/system/development.nix turns nix-ld on, which
# is what /lib64/ld-linux-x86-64.so.2 points at; that is the same reason the
# numtide freebuff wrapper needs no FHS user env (see the note beside the
# `llm-agents` input in flake.nix). If the platform package were ever missing
# the launcher falls back to Node — 24.19 from nixpkgs satisfies its
# ">= 22.19" — and to fd/rg on PATH, so a broken runtime degrades rather than
# refusing to start.
#
# OMNIRUSH_AUTO_UPDATE=0 is not cosmetic: upstream's default is to download a
# new release in the background and swap it in behind the launcher's back,
# which for a store path means a write that cannot happen and a version that
# silently disagrees with the one this file pins. Bump the version below
# instead.
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs,
}:

let
  version = "1.0.2";
in
stdenv.mkDerivation {
  pname = "omnirush";
  inherit version;

  # The launcher, the agent core and the omnirush extensions.
  src = fetchurl {
    url = "https://registry.npmjs.org/omnirush/-/omnirush-${version}.tgz";
    hash = "sha256-KOsR3VAHPmMIujRSKBUUsKW5uk43k2j/z1TfVS97oPk=";
  };

  # The glibc/x86_64 runtime that npm would have selected from
  # optionalDependencies: bin/bun, bin/fd, bin/rg and voice mode's recorder.
  # A second attribute rather than a second src so the unpack phase only ever
  # has to understand one tarball.
  runtime = fetchurl {
    url = "https://registry.npmjs.org/@omnirush-ai/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha256-jBs1YTc2QIpI4kq4ilXMrkETCnfsBwyLsJGR7LTaO2A=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  # The bundled bun/fd/rg are already stripped upstream; stripping a 79 MB
  # bun that nothing here links against buys nothing and risks corrupting it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/omnirush"
    # ./. rather than ./* : the tarball carries core/.omnirush-branded and
    # nothing may be silently dropped, since findCore reads core/package.json
    # and reports "not found (broken install)" if the brand file is gone.
    cp -a ./. "$out/lib/node_modules/omnirush/"

    mkdir -p "$out/lib/node_modules/omnirush/node_modules/@omnirush-ai/cli-linux-x64"
    tar -xf "$runtime" -C "$out/lib/node_modules/omnirush/node_modules/@omnirush-ai/cli-linux-x64" \
      --strip-components=1

    makeWrapper ${nodejs}/bin/node "$out/bin/omnirush" \
      --add-flags "$out/lib/node_modules/omnirush/src/bin.js" \
      --set OMNIRUSH_AUTO_UPDATE 0 \
      --set SSL_CERT_DIR /etc/ssl/certs

    runHook postInstall
  '';

  meta = {
    description = "Coding-agent CLI with free daily tokens for frontier models";
    homepage = "https://omnirush.ai";
    changelog = "https://www.npmjs.com/package/omnirush";
    license = lib.licenses.asl20;
    # The launcher and the core are Apache-2.0; the bundled fd/rg are MIT and
    # carry their own LICENSE-* files in the platform package (see
    # THIRD_PARTY_NOTICES.md in both tarballs).
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    # Hard-coded to the one platform package fetched above: adding aarch64
    # means a second `runtime` and a second hash, not just another platform
    # name in this list.
    platforms = [ "x86_64-linux" ];
    mainProgram = "omnirush";
  };
}
