# packages/free-pi-cli.nix
#
# free-pi-cli — a free terminal coding agent that signs in with GitHub and is
# paid for by ads plus a daily allowance. Installed imperatively until now:
#
#     npm install -g free-pi-cli       # into ~/.npm-global
#
# Like neon-cli.nix and ob1.nix, the published tarball carries a dependency
# tree (the @earendil-works/pi-* packages), so it is buildNpmPackage with a
# committed lockfile rather than a bare fetchurl.
#
# Its dependency tree also installs `pi` and `pi-ai` binaries (from
# @earendil-works/pi-coding-agent). Only `free-pi-cli` is wrapped here: the
# other two are that package's own entry points, not something this machine
# asked for, and putting them on $PATH would be a second, undocumented agent.
#
# Bump: change the dependency range in ./free-pi-cli/package.json, run
# `npm install --package-lock-only` there, then
# `nix run nixpkgs#prefetch-npm-deps -- package-lock.json` for npmDepsHash.
# `version` comes from the lock.
{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage rec {
  pname = "free-pi-cli";
  version =
    (lib.importJSON ./free-pi-cli/package-lock.json).packages."node_modules/free-pi-cli".version;

  src = ./free-pi-cli;

  npmDepsHash = "sha256-CtZEWnxcYuKIYO2rTquFZ31zda50bMBGujJTY/WFThQ=";

  dontNpmBuild = true;

  # A private prefix per package instead of npm's `lib/node_modules`; see the
  # long note in neon-cli.nix — sharing that one directory made the CLIs
  # collide on `strip-ansi` and took the whole home profile down.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}/node_modules $out/bin
    cp -r node_modules/. $out/lib/${pname}/node_modules/
    makeWrapper ${nodejs}/bin/node $out/bin/free-pi-cli \
      --add-flags $out/lib/${pname}/node_modules/free-pi-cli/dist/index.js
    runHook postInstall
  '';

  meta = {
    description = "free-pi — free AI coding agent for the terminal";
    homepage = "https://freepi.ai";
    downloadPage = "https://www.npmjs.com/package/free-pi-cli";
    license = lib.licenses.mit;
    mainProgram = "free-pi-cli";
    platforms = lib.platforms.unix;
  };
}
