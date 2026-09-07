# packages/otzaria.nix
#
# Otzaria (אוצריא) — a Flutter desktop app for the Jewish library.
#   upstream: https://github.com/Otzaria/otzaria
#
# It ships as a prebuilt Linux package, so we fetch the app-only `.deb` and
# repackage it for NixOS rather than building Flutter from source (no Flutter
# toolchain, and the build is heavy). The seforim library itself is NOT
# bundled: the app downloads it on first run (or you point it at an extracted
# corpus) — that is the `~/Documents/otzarias/אוצריא/` directory.
#
# The .deb is a (large) Flutter runtime: everything except the GTK/GLib/zlib
# system libs is shipped under `opt/otzaria/lib` (libflutter_linux_gtk, the
# plugin .so files, GStreamer, avif, …). `autoPatchelfHook` rewrites the ELF
# rpaths, and the only `buildInputs` it needs are the ones debian's deps list.
#
# License: the project is under a "Personal Use License" (personal use only,
# no redistribution). Shipping the prebuilt binary for this machine's personal
# use is fine; it is why this stays a local build-time fetch and is not offered
# as a public nixpkgs package.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  gtk3,
  glib,
  zlib,
  mesa,
  libdrm,
  curl,
  libsecret,
  harfbuzz,
  libXmu,
}:
let
  # The release uploader uses `+` in the version string, which must be URL-encoded.
  version = "0.9.96";
  buildNo = "90960";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "otzaria";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Otzaria/otzaria/releases/download/${version}%2B736/otzaria-${version}%2B${buildNo}-linux.deb";
    sha256 = "7b5e2297127e00513743bd9132c79a72e4ab164540891aa785ec332d18096622";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];
  # What the .deb's control dependencies boil down to once its bundled libs
  # (blkid, lzma, …) are accounted for: GTK3 + GLib + zlib, plus the few
  # things the bundled WPE webview and plugins still want from the host
  # (libgbm/libdrm for GL, curl, libsecret, harfbuzz-icu, libXmu).
  buildInputs = [
    gtk3
    glib
    zlib
    mesa # libgbm.so.1
    libdrm # libdrm.so.2
    curl # libcurl.so.4
    libsecret # libsecret-1.so.0
    (harfbuzz.override { withIcu = true; }) # libharfbuzz-icu.so.0
    libXmu # for the bundled xclip helper
  ];
  # The bundled libdartjni.so wants libjvm.so (a Java JNI bridge) that no
  # plugin here actually needs at runtime; nothing to satisfy it with.
  autoPatchelfIgnoreMissingDeps = [ "libjvm.so" ];

  unpackPhase = "true";
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    # Unpack the .deb's data archive into the store.
    dpkg-deb -x "$src" "$out"
    rm -rf "$out/DEBIAN"
    # Main binary ships at opt/otzaria/otzaria; expose it on PATH and make a
    # stable $out/bin entry for the desktop file and launchers.
    mkdir -p "$out/bin"
    ln -sfn "$out/opt/otzaria/otzaria" "$out/bin/otzaria"
    # Application menu entry (the app-only deb does ship otzaria.desktop).
    install -Dm644 "$out/usr/share/applications/otzaria.desktop" \
      "$out/share/applications/otzaria.desktop"
    sed -i -e "s#^Exec=.*#Exec=$out/bin/otzaria#" \
           -e "s#^TryExec=.*#TryExec=$out/bin/otzaria#" \
      "$out/share/applications/otzaria.desktop"
    rm -rf "$out/usr"
    runHook postInstall
  '';

  meta = {
    description = "Otzaria — a modern app for the Jewish library (Flutter)";
    homepage = "https://www.otzaria.org/";
    # Personal Use License 1.0: personal use only, no redistribution.
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "otzaria";
    platforms = [ "x86_64-linux" ];
  };
})
