# packages/ob1.nix
#
# Ob1 — a free terminal coding agent ("persistent project memory, runs in any
# repo"). Installed imperatively until now:
#
#     npm install -g @overbrilliant/ob1      # into ~/.npm-global
#
# Same story as neon-cli.nix: one tarball with a dependency tree (ink, react,
# web-tree-sitter, sqlite-vec), so buildNpmPackage plus a committed lockfile is
# what makes the install reproducible instead of remembered.
#
# `sqlite-vec` is the one entry in that tree that is not pure JavaScript: it is
# a prebuilt native module, loaded at runtime from the store with dlopen. This
# machine has programs.nix-ld enabled (modules/system/development.nix), which is
# what makes that work without patching the store path.
#
# Bump: change `version` here and in ./ob1/package.json together, then
# `npm install --package-lock-only` in ./ob1 and
# `nix run nixpkgs#prefetch-npm-deps -- package-lock.json` for npmDepsHash.
{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage rec {
  pname = "ob1";
  version = "0.3.13";

  src = ./ob1;

  npmDepsHash = "sha256-YPLFBrfHVpQiVzDfSklZYg8wUJmWZRQQCjpZVSIrZ04=";

  # The tarball ships bin/ob1.mjs ready to run; nothing to compile.
  dontNpmBuild = true;

  # A private prefix per package instead of npm's `lib/node_modules`; see the
  # long note in neon-cli.nix — sharing that one directory made ob1 and
  # neon-cli collide on `strip-ansi` and took the whole home profile down.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}/node_modules $out/bin
    cp -r node_modules/. $out/lib/${pname}/node_modules/
    makeWrapper ${nodejs}/bin/node $out/bin/ob1 \
      --add-flags $out/lib/${pname}/node_modules/@overbrilliant/ob1/bin/ob1.mjs
    runHook postInstall
  '';

  meta = {
    description = "Ob1 — free open-source coding agent for the terminal";
    downloadPage = "https://www.npmjs.com/package/@overbrilliant/ob1";
    license = lib.licenses.asl20;
    mainProgram = "ob1";
    platforms = lib.platforms.unix;
  };
}
