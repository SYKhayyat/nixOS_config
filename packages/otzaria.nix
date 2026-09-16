# packages/otzaria.nix
#
# Otzaria (אוצריא) — a Flutter desktop app for the Jewish library.
#   upstream: https://github.com/Otzaria/otzaria
#
# It ships as a prebuilt Linux package, so we fetch the `.deb` and repackage
# it for NixOS rather than building Flutter from source (no Flutter toolchain,
# and the build is heavy). The seforim library itself is NOT bundled: the app
# downloads it on first run (or you point it at an extracted corpus).
#
# The .deb bundles all of its shared libraries under opt/otzaria/lib. We
# unpack it into the Nix store and let autoPatchelfHook fix up the rpaths.
# Three bundled libs must NOT shadow nixpkgs: libmount/libblkid (the old
# libmount lacks MOUNT_2_40 and aborts glib on launch) and libxkbcommon (the
# bundled one crashes; use nixpkgs plus XKB_CONFIG_ROOT below). Likewise the
# Flutter engine dlopens plugin libs (libsearch_engine.so, …) by bare name,
# which misses the bundle dir, so the wrapper puts it on LD_LIBRARY_PATH.
#
# License: the project is under a "Personal Use License" (personal use only,
# no redistribution). Shipping the prebuilt binary for this machine's personal
# use is fine; it is why this stays a local build-time fetch and is not offered
# as a public nixpkgs package.
{ lib, stdenv, fetchurl, dpkg, autoPatchelfHook, makeWrapper
, gtk3, gdk-pixbuf, pango, cairo, glib, atk, harfbuzzFull
# Runtime system deps pulled in by the bundled WPE/gstreamer/sentry helpers.
, curl, mesa, libdrm, libsecret, xorg, util-linux, libxkbcommon, xkeyboard-config
, adwaita-icon-theme
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
    curl mesa libdrm libsecret xorg.libXmu util-linux libxkbcommon xkeyboard-config
    adwaita-icon-theme
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
    # Drop bundled system libs that shadow newer nixpkgs versions via
    # LD_LIBRARY_PATH (e.g. old libmount lacks MOUNT_2_40 needed by glib).
    # autoPatchelf then rewires those DT_NEEDED to nixpkgs (util-linux).
    rm -f "$out/lib/otzaria/lib/libmount.so.1" "$out/lib/otzaria/lib/libblkid.so.1"
    rm -f "$out/lib/otzaria/lib/libxkbcommon.so.0"
    cp -r unpacked/usr/share/applications "$out/share/"
    cp -r unpacked/usr/share/metainfo "$out/share/"
    cp -r unpacked/usr/share/icons "$out/share/"
    # The vended WPE webview (flutter_inappwebview) hard-codes its helper
    # process path as /opt/wpe-sdk/...; point it at the bundled binaries.
    # Exec-ing the real ELF keeps $ORIGIN (= <out>/lib/otzaria) intact, so the
    # bundled libs and flutter_assets resolve exactly as upstream ships them.
    #
    # Flutter loads its native plugin libs (libsearch_engine.so, …) via dlopen
    # *from the engine* (libflutter_linux_gtk.so), whose RUNPATH only lists the
    # system deps, not our bundle dir — RUNPATH is non-transitive for a dlopen'd
    # dependency, so a bare-name dlopen misses the bundled .so and the app dies
    # with "Failed to load dynamic library". LD_LIBRARY_PATH is consulted first
    # by dlopen regardless of the caller's RUNPATH, so point it at the bundle.
    makeWrapper "$out/lib/otzaria/otzaria" "$out/bin/otzaria" \
      --set WEBKIT_EXEC_PATH "$out/lib/otzaria/lib" \
      --set XKB_CONFIG_ROOT "${xkeyboard-config}/share/X11/xkb" \
      --set XCURSOR_THEME "Adwaita" \
      --prefix XCURSOR_PATH ":" "${adwaita-icon-theme}/share/icons" \
      --prefix LD_LIBRARY_PATH ":" "$out/lib/otzaria/lib"
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
