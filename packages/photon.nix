# packages/photon.nix
#
# Photon Studio — a free, offline desktop photo editor (layers, masks,
# Liquify, retouching, native PSD) from Tenzen Studio.
#   upstream: https://tenzen.studio/photon
#
# Not in nixpkgs: `pkgs/by-name/ph/photon` there is s0md3v's URL *crawler*,
# an unrelated program that happens to share the name. That is the whole
# reason this overlay's attribute is `photon-studio` — taking `photon` would
# shadow a real nixpkgs package to save five characters, and the day anything
# in this tree (or an upstream module) wants the crawler, the shadow is the
# bug.
#
# ── Why an AppImage, and what it costs ────────────────────────────────────
#
# Tenzen ships Linux as an AppImage and a Flatpak, nothing else. Declaring
# the Flatpak would mean giving this config a second package manager —
# services.flatpak plus something to express the app, neither of which exists
# here — for one application. So it is the AppImage, repackaged the way
# nixpkgs repackages every AppImage: `appimageTools` unpacks the squashfs
# into the store and runs the result inside a bubblewrap FHS env, which is
# how the bundled Electron finds its libraries on NixOS at all.
#
# The image is 756 MB and the extracted tree is another 1.2 GB, and both are
# in the closure: subject selection and background removal run on this
# machine rather than in a cloud, so the models live in resources/app.asar.
# That is the price of "your files stay on your computer", and it is why
# this is a single entry in the creative suite rather than something to add
# on a whim.
#
# `appimageTools.extract` is written out below and also runs inside
# `wrapType2`. It is one derivation — same pname, version and src both
# times — so the store holds one copy, not two.
#
# ── Bumping ───────────────────────────────────────────────────────────────
#
# `https://tenzen.studio/api/v1/photon/releases/latest` reports the current
# version; the URL below is the one `/api/v1/photon/download` redirects to
# with platform=linux&arch=x64&kind=appimage, so a bump is that version plus
# a new hash for the same path.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "photon-studio";
  version = "0.1.34";

  src = fetchurl {
    url = "https://downloads.tenzen.studio/photon/stable/linux/${version}/Photon-Studio-${version}-linux-x64.AppImage";
    hash = "sha256-mtxsmWNbZVg1pwp7pAuA9eBt2TOF61cCYmgFSGtgsrU=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The shipped entry runs `AppRun`, and its Icon= only resolves inside the
  # image; both are rewritten here. The MimeType= line that comes with it is
  # kept as-is — it is what makes double-clicking a .psd or a raw file open
  # this app, and it is the part a bare `bin/photon-studio` would not give
  # you.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/photon-studio.desktop \
      $out/share/applications/photon-studio.desktop
    substituteInPlace $out/share/applications/photon-studio.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=${pname} %U'
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/photon-studio.png \
      $out/share/icons/hicolor/512x512/apps/photon-studio.png
  '';

  meta = {
    description = "Free offline photo editor with layers, masks and native PSD support";
    homepage = "https://tenzen.studio/photon";
    changelog = "https://tenzen.studio/api/v1/photon/releases/latest";
    # Free to use, but under Tenzen's Terms of Service rather than an
    # open-source licence — the only LICENSE* files in the image are
    # Electron's and Chromium's. `allowUnfree` is on in
    # ../modules/system/core.nix, so this evaluates.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
