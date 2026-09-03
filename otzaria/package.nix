# Otzaria — a Flutter "Jewish library" desktop app.
#
# The official release only ships the app as a Debian package (.deb), which
# bundles all of its shared libraries under opt/otzaria/lib. We unpack it
# into the Nix store and let autoPatchelfHook fix up the rpaths against the
# single system dependency the app actually needs at runtime: GTK3.
{ lib, stdenv, fetchurl, dpkg, autoPatchelfHook, makeWrapper
, gtk3, gdk-pixbuf, pango, cairo, glib, atk, harfbuzzFull
# Runtime system deps pulled in by the bundled WPE/gstreamer/sentry helpers.
, curl, mesa, libdrm, libsecret, xorg
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "otzaria";
  version = "0.9.96";

  src = fetchurl {
    url = "https://github.com/Otzaria/otzaria/releases/download/0.9.96%2B736/otzaria-0.9.96%2B90960-linux.deb";
    hash = "sha256-e14ilxJ+AFE3Q72RMseacuSrFkVAiRqnhewzLRgJZiI=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

  # Required directly by the Flutter launcher's DT_NEEDED entries, plus the
  # system libs the bundled WPE webview / gstreamer / sentry helpers also need.
  buildInputs = [
    gtk3 gdk-pixbuf pango cairo glib atk harfbuzzFull
    curl mesa libdrm libsecret xorg.libXmu
  ];

  # libdartjni.so is a leftover Java/JNI helper that the desktop build never
  # loads; nothing provides libjvm.so in the store, so ignore it rather than
  # graft a whole JDK on for an unused shim.
  env.autoPatchelfIgnoreMissingDeps = "libjvm.so";

  unpackPhase = ''
    dpkg-deb -x "$src" unpacked
  '';

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -r unpacked/opt/otzaria "$out/lib/otzaria"
    cp -r unpacked/usr/share/applications "$out/share/"
    cp -r unpacked/usr/share/metainfo "$out/share/"
    cp -r unpacked/usr/share/icons "$out/share/"
    # The vended WPE webview (flutter_inappwebview) hard-codes its helper
    # process path as /opt/wpe-sdk/...; point it at the bundled binaries.
    # Exec-ing the real ELF keeps $ORIGIN (= <out>/lib/otzaria) intact, so the
    # bundled libs and flutter_assets resolve exactly as upstream ships them.
    makeWrapper "$out/lib/otzaria/otzaria" "$out/bin/otzaria" \
      --set WEBKIT_EXEC_PATH "$out/lib/otzaria/lib"
    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace "$out/share/applications/otzaria.desktop" \
      --replace "Exec=otzaria" "Exec=$out/bin/otzaria"
  '';

  meta = with lib; {
    description = "Otzaria — brings the Jewish library to every device";
    homepage = "https://www.otzaria.org/";
    changelog = "https://github.com/Otzaria/otzaria/releases";
    license = {
      shortName = "otzaria-personal";
      fullName = "Otzaria Personal Use License 1.0";
      url = "https://github.com/Otzaria/otzaria/blob/dev/LICENSE";
      free = false;
    };
    platforms = [ "x86_64-linux" ];
    mainProgram = "otzaria";
  };
})