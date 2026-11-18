# packages/neon-cli.nix
#
# The Neon CLI — create, branch and migrate Neon Postgres projects from the
# terminal. It used to be installed imperatively:
#
#     npm install -g neon        # into ~/.npm-global, per ~/.npmrc's prefix
#
# which is the install nothing rebuilds, nothing rolls back, and that no
# flake.lock describes. This is the same package, pinned.
#
# ── Why the attribute is `neon-cli` and the binary is `neon` ──────────────
#
# nixpkgs already has a `neon`: the C HTTP client library that GNOME apps link
# against. An overlay that defined `neon` would silently replace it for every
# consumer on the machine. The attribute is `neon-cli`; the binary keeps the
# name you actually type.
#
# ── Why buildNpmPackage, and not the omnirush two-fetchurl shape ──────────
#
# omnirush (see omnirush.nix) has an empty `dependencies` list, so there was no
# tree for npm to resolve and a lockfile would have been a second copy of two
# URLs. `neon` is the opposite: 35 runtime dependencies behind a lockfile. That
# is exactly the case buildNpmPackage exists for.
#
# Bump: change the dependency range in ./neon-cli/package.json, run
# `npm install --package-lock-only` in that directory, then
# `nix run nixpkgs#prefetch-npm-deps -- package-lock.json` for the new
# npmDepsHash. `version` is read from the lock — there is no second string to
# keep in step, and the old hand-typed one could only ever disagree with it.
{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage rec {
  pname = "neon-cli";
  version = (lib.importJSON ./neon-cli/package-lock.json).packages."node_modules/neon".version;

  src = ./neon-cli;

  npmDepsHash = "sha256-07BITgi6sMbkSvAnpCZwSo6gjYhf1hMay1UmbR2t3EQ=";

  # The published tarball ships dist/cli.js already built; there is no build
  # script to run and no TypeScript toolchain to pull in for one.
  dontNpmBuild = true;

  # Each CLI keeps its dependency tree under its own `lib/<pname>/`, NOT under
  # npm's `lib/node_modules`.
  #
  # npm's global layout is what clixad and omnirush use, and it is wrong for a
  # set of packages that share dependencies: home-manager's single buildEnv saw
  # neon-cli and ob1 both provide `lib/node_modules/strip-ansi/index.d.ts` and
  # failed the whole profile. Measured, not predicted — `pkgs.buildEnv` over
  # the new packages refused with "two given paths contain a conflicting
  # subpath" naming strip-ansi. A private prefix per package is the fix; the
  # entry point still sits inside a `node_modules/` directory, so Node's own
  # resolution (including ESM, which ignores NODE_PATH) finds the siblings.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}/node_modules $out/bin
    cp -r node_modules/. $out/lib/${pname}/node_modules/
    makeWrapper ${nodejs}/bin/node $out/bin/neon \
      --add-flags $out/lib/${pname}/node_modules/neon/dist/cli.js
    runHook postInstall
  '';

  meta = {
    description = "Neon CLI — manage Neon Postgres projects, branches and migrations";
    downloadPage = "https://www.npmjs.com/package/neon";
    license = lib.licenses.asl20;
    mainProgram = "neon";
    platforms = lib.platforms.unix;
  };
}
