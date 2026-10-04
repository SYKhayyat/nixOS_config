# packages/lightcraft.nix
#
# LightCraft — a photo library and raw developer, a clean-room
# reimplementation of Lightroom in Rust (wgpu + egui).
#   upstream: https://github.com/storytold/lightcraft
#
# Not in nixpkgs (`gh api search/code q=lightcraft repo:NixOS/nixpkgs` → 0 hits
# on 2026-10-04), so this is a local package, the way clixad and omnirush are.
# It is young: 0.1.1, tagged "young & moving fast" upstream.
#
# ── Why the .deb and not the AppImage or the tarball ───────────────────────
#
# All three ship the same two static-ish ELF binaries. The .deb additionally
# carries the .desktop file, the hicolor icons, the MIME definition and the
# metainfo, so there is exactly one upstream layout to consume instead of
# three, and `dpkg-deb -x` is a plain unpack — no AppImage FUSE, no
# `--appimage-extract` and no $APPDIR juggling at run time. (That is the same
# argument packages/otzaria.nix makes for its .deb.)
#
# ── The binaries need almost nothing, which is the interesting part ────────
#
# readelf says both are linked against nothing but libc, libm and libgcc_s:
# upstream links the Rust std and wgpu's backends statically and resolves the
# windowing/graphics stack at run time with dlopen. So autoPatchelfHook has no
# work to do — there is no DT_NEEDED to rewire — and the libraries listed in
# `buildInputs` below are dlopen targets, not link inputs. That is also why
# LD_LIBRARY_PATH is set rather than anything patched: dlopen consults
# LD_LIBRARY_PATH first regardless of the calling object's RUNPATH.
#
# The dlopen set, from `strings`: libvulkan/libEGL (wgpu), libX11/libX11-xcb/
# libxcb/libXcursor/libXi (X11 backend), libwayland-client/libwayland-egl
# (Wayland backend), libxkbcommon{,,-x11} (keys), libdbus-1 (portals). All are
# in nixpkgs, so this is a closure, not a bundle.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  libGL,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  dbus,
}:

stdenv.mkDerivation {
  pname = "lightcraft";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/storytold/lightcraft/releases/download/v0.1.1/lightcraft-0.1.1-linux-x86_64.deb";
    # From the release's own SHA256SUMS.txt:
    #   51f2d185664723aa4b7ce5a5b573e410dd57431954a32d983b02f9c060a35a9a
    hash = "sha256-UfLRhWZHI6pLfOWltXPkEN1XQxlUoy2YOwL5wGCjWpo=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  # dlopen targets, not link inputs — see the header.
  buildInputs = [
    libGL
    libxkbcommon
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcursor
    libxi
    dbus
  ];

  dontConfigure = true;
  dontBuild = true;
  # Upstream ships these stripped, and the binaries are 30 MB apiece; there is
  # nothing to gain and a static wgpu build is easy to corrupt.
  dontStrip = true;
  # No ELF patching needed or wanted — see the header.
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" unpacked

    mkdir -p "$out/bin" "$out/share"
    cp unpacked/usr/bin/lightcraft unpacked/usr/bin/lightcraft-cli "$out/bin/"
    cp -r unpacked/usr/share/applications "$out/share/"
    cp -r unpacked/usr/share/metainfo "$out/share/"
    cp -r unpacked/usr/share/icons "$out/share/"
    cp -r unpacked/usr/share/mime "$out/share/"
    cp -r unpacked/usr/share/doc "$out/share/doc"

    runHook postInstall
  '';

  # One wrapper loop over the two binaries: they share every variable below,
  # and lightcraft-cli is a headless converter that wants the same libraries
  # for its codec work even though it never opens a window.
  #
  # ── LIGHTCRAFT_GPU=0: exports are black on this machine's Intel iGPU ─────
  #
  # A workaround, not a preference: with the GPU path active, every export
  # from this app comes out **pure black**. Previews are unaffected, which is
  # what makes it so easy to miss — the photo looks right on screen and the
  # file is 24,000,000 pixels of #000000.
  #
  # Bisected on DSC_5414.NEF (identify mean, 0 = black):
  #
  #   the NEF itself                     0.378  fine
  #   lightcraft-cli render              0.388  fine — same file, same
  #                                             options, CPU path
  #   GUI export, Intel driver           0.000  BLACK (type Bilevel)
  #   GUI export, LIGHTCRAFT_GPU=0       0.378  fine
  #
  # So the raw decoder, the develop pipeline and the JPEG encoder are all
  # sound — the CPU path renders the identical image correctly — and the
  # fault is in wgpu/Vulkan on the Intel iGPU that ui.inspect names as
  # `Intel(R) UHD Graphics (ICL GT1) (Vulkan)`. Only the export path reads the
  # rendered texture back, so only exports are corrupted.
  #
  # The cost, stated plainly: this is the whole GPU pipeline off, not a
  # faster software rasterizer. ui.inspect reported lastRenderMs ~14.8s with
  # the Intel driver and ~3.5s with LIGHTCRAFT_GPU=0, and perf.gpu becomes
  # null — so on this hardware the CPU is the *faster* path anyway, which is
  # the only reason this is not simply a loss. Correct files beat fast black
  # ones.
  #
  # A first attempt pinned VK_ICD_FILENAMES to mesa's lavapipe ICD, on the
  # theory that a software adapter would sidestep the driver bug. It did fix
  # the exports and it is still tempting because it looks narrower. It is
  # wrong: docs/gpu-pipeline.md lists "software-only adapters" among the
  # conditions under which the GPU path returns None, so the app discarded
  # lavapipe and fell back to the CPU anyway. It disabled the GPU by the back
  # door while appearing to configure it, and perf.gpu read null either way,
  # so nothing would have shown the difference. The documented switch says
  # what it does.
  #
  # Delete this once LightCraft exports correctly on Intel. It is an upstream
  # driver bug and worth reporting.
  postFixup = ''
    for bin in lightcraft lightcraft-cli; do
      wrapProgram "$out/bin/$bin" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          libGL libxkbcommon vulkan-loader wayland libx11 libxcb
          libxcursor libxi dbus
        ]}" \
        --set LIGHTCRAFT_GPU 0 \
        --prefix XDG_DATA_DIRS : "$out/share" \
        --prefix XDG_DATA_DIRS : "$XDG_DATA_DIRS"
    done
  '';

  meta = {
    description = "Photo library and raw developer, a Rust reimplementation of Lightroom";
    homepage = "https://getartcraft.com/apps/lightcraft";
    changelog = "https://github.com/storytold/lightcraft/releases";
    # Dual MIT OR Apache-2.0 (both files at the repo root; the README badge and
    # the LICENSE-APACHE/LICENSE-MIT pair agree). nixpkgs has no mitOrApache20
    # attribute, and a license must be one SPDX id, so this states the
    # disjunction as its own short name rather than picking a side and being
    # wrong about the other.
    license = {
      shortName = "mit-asl20";
      fullName = "MIT OR Apache-2.0";
      url = "https://github.com/storytold/lightcraft/blob/main/LICENSE-MIT";
      free = true;
    };
    platforms = [ "x86_64-linux" ];
    mainProgram = "lightcraft";
  };
}