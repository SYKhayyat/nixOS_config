# packages/artcraft.nix
#
# The ArtCraft apps — one builder, four packages. Each is a prebuilt Linux .deb
# from the same author, same Rust/egui/wgpu stack, same release cadence:
#
#   photocraft    Image editing: layers, masks, type, PSD/PSB   (Photoshop)
#   printcraft    Reading, organising and protecting PDFs
#   designcraft   Page layout and publishing                   (InDesign)
#   lightcraft    Photo library and raw development            (Lightroom)
#
#   upstream: https://github.com/storytold/<app>   release 0.1.1
#
# Not in nixpkgs (checked 2026-10-04 via the GitHub code search), so these are
# local packages, the way clixad and omnirush are.
#
# ── Why one builder for four packages ─────────────────────────────────────
#
# The four .debs unpack to the same shape: <app> and <app>-cli in usr/bin,
# and applications/metainfo/icons/mime/doc in usr/share. Nothing here is
# app-specific except the name, the version, the hash, one line of `meta`, and
# whether the GPU path has to be off. Four near-identical files would be four
# places for the same bug to be fixed once and missed three times — which is
# exactly what happened with the GPU workaround below, initially written for
# LightCraft alone.
#
# Callers pass what differs; everything else is asserted below.
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

  # What differs between the apps.
  app,
  version,
  hash,
  description,
  # Set for lightcraft; see the LIGHTCRAFT_GPU note under postFixup.
  disableGpu ? false,
  # True where the app is documented as pulling in wgpu's Vulkan backend.
  usesVulkan ? false,
}:

assert lib.assertMsg (builtins.match "^[a-z][a-z0-9-]*$" app != null)
  "packages/artcraft.nix: app must be a bare lowercase name, got '${app}'";

stdenv.mkDerivation {
  pname = app;
  inherit version;

  src = fetchurl {
    url = "https://github.com/storytold/${app}/releases/download/v${version}/${app}-${version}-linux-x86_64.deb";
    inherit hash;
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  # dlopen targets, not link inputs — see the header note below.
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
  # Upstream ships these stripped and they are 30 MB apiece; there is nothing to
  # gain and a static wgpu build is easy to corrupt.
  dontStrip = true;
  # No ELF patching needed or wanted — see the header note below.
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" unpacked

    mkdir -p "$out/bin" "$out/share"
    cp unpacked/usr/bin/${app} unpacked/usr/bin/${app}-cli "$out/bin/"
    cp -r unpacked/usr/share/applications "$out/share/"
    cp -r unpacked/usr/share/metainfo "$out/share/"
    cp -r unpacked/usr/share/icons "$out/share/"
    cp -r unpacked/usr/share/mime "$out/share/"
    cp -r unpacked/usr/share/doc "$out/share/doc"

    runHook postInstall
  '';

  # ── The binaries dlopen their graphics stack; nothing here is linked ─────
  #
  # readelf on all four apps shows DT_NEEDED for libc, libm and libgcc_s and
  # nothing else: upstream links Rust std and the wgpu backends statically and
  # resolves windowing and graphics at run time with dlopen. Two consequences,
  # both of which the derivation is shaped around:
  #
  #   * autoPatchelfHook is deliberately absent and dontPatchELF is set. There
  #     is no DT_NEEDED to rewire; adding the hook would only rewrite what is
  #     already correct.
  #   * buildInputs are dlopen *targets*, not link inputs, and reach the
  #     process through LD_LIBRARY_PATH. dlopen consults LD_LIBRARY_PATH first
  #     regardless of the calling object's RUNPATH, which is what makes this
  #     work at all.
  #
  # The dlopen set, from `strings` on the binaries: libvulkan/libEGL (wgpu),
  # libX11/libX11-xcb/libxcb/libXcursor/libXi (X11 backend),
  # libwayland-client/libwayland-egl (Wayland backend), libxkbcommon{,,-x11}
  # (keys), libdbus-1 (portals). All are in nixpkgs, so this is a closure
  # rather than a bundle.
  #
  # `usesVulkan` records whether the app actually pulls in libvulkan.so.1:
  # designcraft does, photocraft and printcraft only reach for libEGL. It is
  # documentation, not behaviour — the loader is in buildInputs either way,
  # because wgpu may select a backend at run time from what it finds.
  #
  # ── LIGHTCRAFT_GPU=0, for lightcraft, and why ────────────────────────────
  #
  # A workaround, not a preference: with the GPU path active, every export from
  # lightcraft came out as 24,000,000 pixels of #000000. Previews were
  # unaffected, so the photo looked right on screen while the file was solid
  # black — the worst failure mode this app has.
  #
  # Bisected on a 6016x4016 16-bit NEF (identify mean, 0 = black):
  #
  #   the NEF itself                     0.378  fine
  #   lightcraft-cli render              0.388  fine — same file, same
  #                                             options, CPU path
  #   GUI export, Intel driver           0.000  BLACK (type Bilevel)
  #   GUI export, LIGHTCRAFT_GPU=0       0.378  fine
  #
  # So the raw decoder, the develop pipeline and the JPEG encoder are all
  # sound — the CPU path renders the identical image correctly — and the fault
  # is in wgpu/Vulkan on the Intel iGPU that ui.inspect names as
  # `Intel(R) UHD Graphics (ICL GT1) (Vulkan)`. Only the export path reads the
  # rendered texture back, which is why only exports were corrupted.
  #
  # The cost, stated plainly: this is the whole GPU pipeline off, not a faster
  # software rasterizer. It is close to free on this hardware — lastRenderMs
  # was ~14.8s on the Intel driver against ~2.1s with the GPU off, so the CPU
  # is the faster path regardless — and correct files beat fast black ones.
  #
  # A first attempt pinned VK_ICD_FILENAMES to mesa's lavapipe ICD, on the
  # theory that a software adapter would sidestep the driver bug. It did fix
  # the exports and it still looks like the narrower change. It is wrong:
  # lightcraft's docs/gpu-pipeline.md lists "software-only adapters" among the
  # conditions under which the GPU path returns None, so the app discarded
  # lavapipe and fell back to the CPU anyway. It disabled the GPU by the back
  # door while appearing to configure it, and perf.gpu read null either way, so
  # nothing in the UI would have shown the difference. The documented switch
  # says what it does.
  #
  # This is an upstream driver bug, not a packaging problem, and should be
  # reported. Delete `disableGpu` once lightcraft exports correctly on Intel.
  # wrapProgram is a shell function from make-wrapper.sh, sourced by every
  # phase of the stdenv, so this works in postFixup as long as nothing has
  # stripped the hook. Both binaries get the same environment: <app>-cli is a
  # headless converter that still wants the codec and graphics libraries even
  # though it never opens a window.
  postFixup = ''
    for bin in ${app} ${app}-cli; do
      wrapProgram "$out/bin/$bin" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
          libGL libxkbcommon vulkan-loader wayland libx11 libxcb
          libxcursor libxi dbus
        ]}" \
        ${lib.optionalString disableGpu ''--set LIGHTCRAFT_GPU 0''} \
        --prefix XDG_DATA_DIRS : "$out/share" \
        --prefix XDG_DATA_DIRS : "$XDG_DATA_DIRS"
    done
  '';

  meta = {
    inherit description;
    homepage = "https://getartcraft.com/apps/${app}";
    changelog = "https://github.com/storytold/${app}/releases";
    # Dual MIT OR Apache-2.0 (LICENSE-MIT and LICENSE-APACHE at each repo
    # root). nixpkgs has no mitOrApache20 attribute and a license must be one
    # SPDX id, so the disjunction gets its own short name rather than picking
    # a side and being wrong about the other.
    license = {
      shortName = "mit-asl20";
      fullName = "MIT OR Apache-2.0";
      url = "https://github.com/storytold/${app}/blob/main/LICENSE-MIT";
      free = true;
    };
    platforms = [ "x86_64-linux" ];
    mainProgram = app;
  };
}