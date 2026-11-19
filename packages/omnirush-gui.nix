# packages/omnirush-gui.nix
#
# OmniRush desktop app — the Electron shell around the CLI in
# packages/omnirush.nix.  upstream: https://omnirush.ai
#   releases: https://github.com/omnirush-ai/omnirush-gui/releases
#
# Not in nixpkgs, so this is a local package like omnirush.nix itself. The two
# are deliberately separate: the CLI is a bun/node CLI published to npm, the
# desktop app is a 690 MB Electron bundle published to GitHub releases, and
# they version independently, on different cadences and from different places —
# the app released seven times in two days once, so neither number is quoted
# here on purpose. `just update-omnirush` moves both; `nrs` and `just switch`
# move both too, before they rebuild. See tools/bump-omnirush.py.
# One account signs in to both.
#
# ── Why the .deb ───────────────────────────────────────────────────────────
#
# The .deb, .rpm, .pacman, AppImage and tar.gz all unpack to the same Electron
# directory. The .deb is preferred for the same reason packages/otzaria.nix
# takes one: it carries the .desktop file and icons alongside, so there is one
# upstream layout instead of four, and `ar x` + `tar xf` is a plain unpack with
# no FUSE and no $APPDIR at run time.
#
# ── Electron on NixOS ──────────────────────────────────────────────────────
#
# Unlike the bundled apps, which link little and dlopen their stack, this one
# has ~30 real DT_NEEDED entries against GTK/NSS/cups/atk. autoPatchelfHook is
# therefore load-bearing here, and the wrapper has to do what Electron expects
# of one:
#
#   --prefix LD_LIBRARY_PATH  the patched libs
#   --no-sandbox / ELECTRON_DISABLE_SANDBOX, only when needed
#     Chromium's sandbox needs either unprivileged user namespaces or a
#     setuid-root chrome-sandbox. Shipping a setuid binary out of the store
#     would be worse than no sandbox, so chrome-sandbox is removed and the
#     wrapper probes for user namespaces (`unshare -Ur true`), the way
#     packages/deepai-code.nix does: the sandbox stays on where they exist —
#     this machine has them — and is turned off only where they do not.
#   --prefix XDG_CACHE_DIR etc.
#     Electron writes to ~/.config and ~/.cache, which is where a native
#     install would put them; left alone it also tries to autostart entries.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  autoPatchelfHook,
  util-linux,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  glib,
  gtk3,
  libdrm,
  libGL,
  libsecret,
  libxkbcommon,
  nspr,
  nss,
  pango,
  libXcomposite,
  libXdamage,
  libXext,
  libxfixes,
  libXrandr,
  libxcb,
  libxcb-util,
  xorgproto,
  udev,
  libgbm,
}:

stdenv.mkDerivation {
  pname = "omnirush-gui";
  version = "3.8.9";

  src = fetchurl {
    url = "https://github.com/omnirush-ai/omnirush-gui/releases/download/v3.8.9/omnirush-linux-amd64-3.8.9.deb";
    # From the release's own SHA256SUMS.txt:
    #   43e21c87da78166e28a721aceeef6e938e32d55c2d452def6bb2781762fd7a47
    hash = "sha256-Q+Ich9p4Fm4opyGs7u9uk44y1VwtRS3va7J4F2L9ekc=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    glib
    gtk3
    libdrm
    libGL
    libsecret
    libxkbcommon
    nspr
    nss
    pango
    libXcomposite
    libXdamage
    libXext
    libxfixes
    libXrandr
    libxcb
    libxcb-util
    xorgproto
    udev
    # The Electron binary itself has libgbm.so.1 in DT_NEEDED (its GPU
    # process), so this is a real dependency rather than a bundled-lib shadow.
    libgbm
  ];

  dontConfigure = true;
  dontBuild = true;

  # autoPatchelfHook walks every ELF in $out, and this bundle ships native
  # modules prebuilt for platforms that are not this one — koffi alone carries
  # linux, musl, openbsd, darwin and win32 builds side by side. The foreign ones
  # name libraries that do not exist on NixOS and never will be loaded here:
  #
  #   libc.musl-x86_64.so.1  libm.so.10.1  libpthread.so.26.1
  #   libc++.so.9.0          libc++abi.so.6.0     (the openbsd koffi.node)
  #
  # Failing the build over them would be wrong, and ignoring them is not hiding
  # a problem: the loader picks the module by platform at run time, so the
  # linux_x64 one is the only one that can ever be opened on this machine.
  env.autoPatchelfIgnoreMissingDeps = lib.concatStringsSep " " (
    lib.toList "libc.musl-x86_64.so.1 libm.so.10.1 libpthread.so.26.1 libc++.so.9.0 libc++abi.so.6.0"
  );
  # Electron's own binary and its bundled .so files are already stripped, and
  # stripping them again is at best wasted work and at worst corrupts them.
  dontStrip = true;

  unpackPhase = ''
    ar x "$src"
    tar xf data.tar.*
  '';

  # The install prefix upstream renamed between 3.2.x and 3.3.x: the bundle used
  # to land in /opt/OmniRush.ai and is now /opt/omnirush, and the binary inside
  # it is lowercase `omnirush' rather than the old capitalised name. Both are
  # spelled out in exactly one place each — the unpack path below and the
  # Exec= rewrite in postFixup — because the two have to agree and a
  # disagreement shows up as a desktop entry that silently launches nothing.
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/omnirush-gui" "$out/bin" "$out/share"
    # ./. rather than ./* : a bundle that carries hidden files would drop them
    # here, and Electron reads the crashpad handler's manifests from among them.
    # 3.3.6 ships none, but the cost of ./. over ./* is nil.
    cp -a ./opt/omnirush/. "$out/lib/omnirush-gui/"
    cp -r ./usr/share/applications "$out/share/"
    cp -r ./usr/share/icons "$out/share/"

    # chrome-sandbox is the setuid fallback for hosts without user namespaces;
    # it cannot be setuid in the store, so it is dead weight there, and the
    # wrapper turns the sandbox off on such hosts instead. (Upstream ships it 0755 as of 3.3.6 — the setuid bit
    # these notes described was 3.2.x's doing — so this is hygiene either way.)
    rm -f "$out/lib/omnirush-gui/chrome-sandbox"

    makeWrapper "$out/lib/omnirush-gui/omnirush" "$out/bin/omnirush-gui" \
      --run 'if ! ${util-linux}/bin/unshare -Ur true 2> /dev/null; then set -- --no-sandbox "$@"; export ELECTRON_DISABLE_SANDBOX=1; fi' \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          cairo
          cups
          dbus
          glib
          gtk3
          libdrm
          libGL
          libsecret
          libxkbcommon
          nspr
          nss
          pango
          libXcomposite
          libXdamage
          libXext
          libxfixes
          libXrandr
          libxcb
          libxcb-util
          xorgproto
          udev
        ]
      }" \
      --set ELECTRON_NO_ATTACH_CONSOLE 1 \
      --prefix XDG_DATA_DIRS : "$out/share"

    runHook postInstall
  '';

  # The .desktop file points at the absolute /opt path the .deb would have
  # installed to, which does not exist here. 3.3.6 renamed the app: the entry is
  # now ai.omnirush.desktop running /opt/omnirush/omnirush, where 3.2.x had
  # /opt/OmniRush.ai. --replace-fail so a future rename that this forgets to
  # follow fails the build instead of shipping a launcher that runs nothing.
  postFixup = ''
    substituteInPlace "$out/share/applications/"*.desktop \
      --replace-fail "/opt/omnirush/omnirush" "$out/bin/omnirush-gui"
  '';

  meta = {
    description = "OmniRush desktop app — the Electron shell for the OmniRush CLI";
    homepage = "https://omnirush.ai";
    changelog = "https://github.com/omnirush-ai/omnirush-gui/releases";
    # The repository states the app is under MIT terms, with code under ee/
    # governed separately. The .deb itself declares "License: unknown", so this
    # follows the repository rather than the package metadata.
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "omnirush-gui";
  };
}
