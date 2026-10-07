# packages/omnirush-gui.nix
#
# OmniRush desktop app — the Electron shell around the CLI in
# packages/omnirush.nix.  upstream: https://omnirush.ai
#   releases: https://github.com/omnirush-ai/omnirush-gui/releases
#
# Not in nixpkgs, so this is a local package like omnirush.nix itself. The two
# are deliberately separate: the CLI is a bun/node CLI published to npm, the
# desktop app is a 690 MB Electron bundle published to GitHub releases, and
# they version independently (CLI 2.2.1, app 3.2.1 at the time of writing).
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
# Unlike the ArtCraft apps (packages/artcraft.nix) which link nothing but libc
# and dlopen their stack, this one has ~30 real DT_NEEDED entries against
# GTK/NSS/cups/atk. autoPatchelfHook is therefore load-bearing here, and the
# wrapper has to do what Electron expects of one:
#
#   --prefix LD_LIBRARY_PATH  the patched libs
#   --set ELECTRON_DISABLE_SANDBOX / --no-sandbox
#     NixOS has no unprivileged user namespaces by default in the sandbox this
#     runs in, and chrome-sandbox needs either that or setuid. Shipping a
#     setuid-root binary out of the Nix store would be worse than turning the
#     sandbox off, so it is turned off.
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
  version = "3.2.1";

  src = fetchurl {
    url = "https://github.com/omnirush-ai/omnirush-gui/releases/download/v3.2.1/omnirush-linux-amd64-3.2.1.deb";
    # From the release's own SHA256SUMS.txt:
    #   572729d8de68f05eea377f7e1287edc07400d532bc6f770740ced05495d4f10e
    hash = "sha256-Vycp2N5o8F7qN39+EoftwHQA1TK8b3cHQM7QVJXU8Q4=";
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
  env.autoPatchelfIgnoreMissingDeps = lib.concatStringsSep " "
    (lib.toList "libc.musl-x86_64.so.1 libm.so.10.1 libpthread.so.26.1 libc++.so.9.0 libc++abi.so.6.0");
  # Electron's own binary and its bundled .so files are already stripped, and
  # stripping them again is at best wasted work and at worst corrupts them.
  dontStrip = true;

  unpackPhase = ''
    ar x "$src"
    tar xf data.tar.*
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/omnirush-gui" "$out/bin" "$out/share"
    # ./. rather than ./* : the bundle carries hidden files that Electron reads
    # (the crashpad handler's manifests), and a missing one fails at start-up
    # rather than at build time.
    cp -a ./opt/OmniRush.ai/. "$out/lib/omnirush-gui/"
    cp -r ./usr/share/applications "$out/share/"
    cp -r ./usr/share/icons "$out/share/"

    # chrome-sandbox is only consulted when the Chromium sandbox is enabled;
    # the wrapper passes --no-sandbox, so it is dead weight in the store. Not
    # removing it would also leave a 4755-mode binary that nobody wants in a
    # read-only store path.
    rm -f "$out/lib/omnirush-gui/chrome-sandbox"

    makeWrapper "$out/lib/omnirush-gui/omnirush" "$out/bin/omnirush-gui" \
      --add-flags "--no-sandbox" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        alsa-lib at-spi2-atk at-spi2-core cairo cups dbus glib gtk3 libdrm
        libGL libsecret libxkbcommon nspr nss pango
        libXcomposite libXdamage libXext libxfixes libXrandr libxcb
        libxcb-util xorgproto udev
      ]}" \
      --set ELECTRON_DISABLE_SANDBOX 1 \
      --set ELECTRON_NO_ATTACH_CONSOLE 1 \
      --prefix XDG_DATA_DIRS : "$out/share"

    runHook postInstall
  '';

  # The .desktop file points at the absolute /opt path the .deb would have
  # installed to, which does not exist here.
  postFixup = ''
    substituteInPlace "$out/share/applications/"*.desktop \
      --replace-fail "/opt/OmniRush.ai/omnirush" "$out/bin/omnirush-gui"
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