# packages/deepai-code.nix
#
# DeepAI Code — an AI coding agent desktop app (Electron 44) from DeepAI,
# advertised on ads across its own site. The agent runs against DeepAI's own
# models or against whatever provider you already have connected.
#   upstream: https://deepai.org/chat/ai-code
#
# Not in nixpkgs, and not in the numtide `llm-agents` overlay either.
#
# ── Where the file comes from ───────────────────────────────────────────────
#
# DeepAI ships Linux builds but does not link them. The website's download
# buttons only offer macOS and Windows; the Linux artefacts exist anyway,
# announced in an electron-builder manifest that nobody linked from the site:
#
#   https://downloads.deepai.org/deepai-code/releases/latest-linux.yml
#
# That manifest points at a Vercel blob bucket and names two artefacts:
# DeepAI-Code-0.3.20-x86_64.AppImage and DeepAI-Code-0.3.20-amd64.deb. The
# AppImage is what is packaged here. The .deb is the same app for Debian
# derivatives and is not worth a second derivation.
#
# ── Why this is not appimageTools.wrapType2 ─────────────────────────────────
#
# The obvious packaging is the one nixpkgs uses for every AppImage: unpack the
# squashfs into the store and run it inside a bubblewrap FHS whose libraries
# come from the closure. That builds and launches. It is wrong here for one
# reason, and the reason is in the app's own code.
#
# The app writes launch paths for itself at runtime, and it writes them with
# `process.execPath` — the path of the running binary, not of any wrapper
# around it. Three places do this:
#
#   * the URL-handler desktop entry (main.cjs, DesktopLinuxUrlHandler):
#       `const execTarget = getOrElse(environment.appImagePath, () => process.execPath)`
#     It writes `~/.local/share/applications/org.deepai.code.desktop` with
#     `Exec="<execTarget>" %U`. That file is how a deepai-code:// callback
#     finds the app after the sign-in round-trip through the browser.
#
#   * the CLI shim (main.cjs, DesktopCliShim): it writes `~/.deepai-code/bin/deepai`,
#     a shell script that runs `<execTarget> <app.asar>/apps/server/dist/bin.mjs`.
#
#   * the auto-relaunch after an update (main.cjs): `app.relaunch({execPath: process.execPath, ...})`.
#
# Under bubblewrap, `process.execPath` is a path that only means something
# inside the sandbox. The three launch paths above are then written pointing
# at nothing. The desktop entry and the CLI shim are the two the user
# actually touches, and both are broken in a way that only shows up later:
# the app starts fine, and the URL handler does not.
#
# So: no FHS, no bubblewrap. The binary is unpacked into the store and given
# an RPATH that names the nix store paths of every library it needs. After
# that the binary runs from any directory, with any environment, and the
# paths the app writes for itself are correct. The agent's own terminals
# also inherit the user's real PATH instead of a sandboxed one, which is
# what an agent that runs commands in your projects needs.
#
# ── The node-pty trap ───────────────────────────────────────────────────────
#
# The backend is a separate Node process (the Electron binary re-executed
# with ELECTRON_RUN_AS_NODE=1) that loads node-pty to give the agent a
# terminal. node-pty ships a prebuilt native addon under
# node_modules/node-pty/prebuilds/linux-x64/pty.node, and electron-builder
# marks it `unpacked: true` in the asar header so that it lands in
# app.asar.unpacked instead of being packed into the archive — a native addon
# cannot be dlopen'd out of an asar.
#
# That redirect works: Electron resolves the asar path to the unpacked file
# and dlopen's it. What it needs is libstdc++.so.6, which a NixOS system
# does not have. Without it the backend dies on every start with
#
#   NodePtyModuleLoadError: Failed to load node-pty for linux-x64.
#     Error: Cannot find module './prebuilds/linux-x64/pty.node'
#
# and the desktop shell restarts the backend in a loop until it times out.
# The symptom points at the addon and the cause is four libraries away:
# libstdc++.so.6 lives in gcc's lib output, which is not a dependency of the
# AppImage's own ELF headers — nothing references it, so nothing drags it in.
# `gcc.cc.lib` is in runtimeDeps below for that reason, and only that reason:
# `gcc` and `gcc.libcxx` are the wrong packages and do not contain it.
#
# ── The GPU crash ──────────────────────────────────────────────────────────
#
# Starting the app while another copy of it is already running kills the
# second copy's GPU process with SIGTRAP (exit 133). The app itself survives,
# so what the user sees is one core dump and one KDE crash notification per
# launch, forever, and a crash handler that offers to report a bug in a
# working application.
#
# The mechanism is Chromium's on-disk shader cache. It lives in the user
# profile, and the profile is shared, because the app resolves it from
# setPath("userData", ...) and ignores --user-data-dir. Two instances of the
# app therefore share one shader cache, and the second GPU process to touch
# it dies. The second instance of the app is supposed to be harmless: its
# single instance lock fails and it quits within milliseconds of starting.
# But its GPU process has already been spawned by then, and has already
# opened the cache, and that is where it dies.
#
# The switch that avoids it is --disable-gpu-shader-disk-cache. It cannot
# come from the command line of a single launch, because the app writes its
# own launch paths with process.execPath (the bare binary): the URL handler
# entry, the CLI shim and the auto-relaunch all start the binary directly,
# with no wrapper and no flags. A flag handed to one launch is not seen by
# the next, and the launch that crashes is usually not the one that was
# started by hand.
#
# So the switch is injected into the app's entry module instead, which every
# launch path goes through. The asar is rewritten: one file is patched, every
# other file is copied byte for byte, and the header offsets and sizes are
# recomputed. Electron's asar integrity validation is switched off in this
# binary (the EnableEmbeddedAsarIntegrityValidation fuse reads 0), so
# nothing rejects the rewritten archive.
#
# The script below fails the build if the code it patches is not found. That
# is deliberate: a version bump that changes the entry module should fail
# loudly here rather than silently bring the crash back.
#
# ── Bumping ────────────────────────────────────────────────────────────────
#
# `latest-linux.yml` names the current version; the URL below is the one
# that manifest points at, and the hash is of the AppImage itself. A bump is
# that version plus a new hash for the same path.
{
  lib,
  pkgs,
  fetchurl,
  patchelf,
  stdenvNoCC,
}:

let
  pname = "deepai-code";
  version = "0.3.20";

  src = fetchurl {
    url = "https://dlwozzovpwsltriq.public.blob.vercel-storage.com/deepai-code/releases/delivery-${version}/DeepAI-Code-${version}-x86_64.AppImage";
    hash = "sha256-8GEcTttQ0DvZx3hCKyZ6yHmqiSESXi8SPZsf8FPhuos=";
  };

  # Libraries the Electron binary, its helper executables and its native
  # addons need at runtime. This is the union of what `patchelf --print-needed`
  # reports for every ELF in the AppImage, minus what the AppImage ships
  # itself (libffmpeg.so and the handful of libraries in usr/lib, which stay
  # reachable through $ORIGIN). The AppImage's own Vulkan stack is not one of
  # them — see the Vulkan note below.
  runtimeDeps = with pkgs; [
    nss
    nspr
    cups
    dbus
    expat
    alsa-lib
    at-spi2-core
    atk
    gtk3
    glib
    cairo
    pango
    udev
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxcursor
    libxi
    libxkbcommon
    libxtst
    libnotify
    libGL
    libgbm
    libdrm
    vulkan-loader
    # libsecret-1.so.0, for resources/browser-secret/t3-browser-secret, the
    # helper that talks to the KDE Wallet / libsecret password store.
    libsecret
    # libffi, for the ffi-rs addon.
    libffi
    # libstdc++.so.6, for node-pty's prebuilt addon. See the header.
    gcc.cc.lib
  ];

  libPath = lib.makeLibraryPath runtimeDeps;

  # The nix glibc loader, so that the binaries do not look for
  # /lib64/ld-linux-x86-64.so.2, which does not exist on NixOS.
  interp = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";

  # The RPATH of the executables, in the order the dynamic linker searches
  # it:
  #
  #   $ORIGIN          the AppImage ships libffmpeg.so next to the binary
  #   the nix glibc    libc.so.6 and friends, which the nix loader does not
  #                    look for on its own
  #   the store        every other library, by absolute path
  #   $ORIGIN/usr/lib  the AppImage's own copies of libXss and friends, as a
  #                    last resort
  exeRpath = "$ORIGIN:${pkgs.glibc}/lib:${libPath}:$ORIGIN/usr/lib";

  # The native addons are dlopen'd out of app.asar.unpacked by a process
  # that is not the executable, so they cannot rely on the executable's
  # RPATH being inherited. Each one gets its own: node-pty wants
  # libstdc++.so.6, xa11y wants libxkbcommon, pi-tui's X11 helper wants
  # libxcb, and all of them want the C library.
  addonRpath = "${pkgs.glibc}/lib:${libPath}";

  # The script that patches the app's entry module inside app.asar.
  # See the header for what the patch is for and why it has to live there.
  patchAsarScript = pkgs.writeText "patch-asar.py" ''
    import base64
    import hashlib
    import json
    import os
    import struct
    import sys

    TARGET = "apps/desktop/dist-electron/main.cjs"

    NEEDLE = (
        "electron = __toESM(electron, 1);\n"
        "let node_path"
    )
    REPLACEMENT = (
        "electron = __toESM(electron, 1);\n"
        "try { (electron.app || require(\"electron\").app).commandLine"
        ".appendSwitch(\"disable-gpu-shader-disk-cache\"); } catch (e) {}\n"
        "let node_path"
    )


    def align4(n):
        return (n + 3) // 4 * 4


    def read_asar(path):
        with open(path, "rb") as f:
            head = f.read(16)
            _a, _b, _c, json_len = struct.unpack("<IIII", head)
            header = json.loads(f.read(json_len).decode("utf-8"))
            data_start = 16 + align4(json_len)
            f.seek(data_start)
            data = f.read()
        return header, data


    def collect(node, path=""):
        """Every file in the archive, in header order, as (path, entry) pairs."""
        out = []
        for name, entry in node.get("files", {}).items():
            p = path + "/" + name if path else name
            if "files" in entry:
                out.extend(collect(entry, p))
            else:
                out.append((p, entry))
        return out


    def rebuild_header_bytes(header):
        json_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
        padded = align4(len(json_bytes))
        c = 4 + padded
        b = 4 + c
        return (
            struct.pack("<IIII", 4, b, c, len(json_bytes))
            + json_bytes
            + b"\0" * (padded - len(json_bytes))
        )


    def main():
        if len(sys.argv) != 2:
            sys.exit("usage: patch-asar.py <app.asar>")
        asar = sys.argv[1]

        header, data = read_asar(asar)

        entries = collect(header)
        match = [e for p, e in entries if p == TARGET]
        if not match:
            sys.exit("patch-asar.py: no such entry: " + TARGET)
        entry = match[0]
        if entry.get("unpacked") or "link" in entry:
            sys.exit("patch-asar.py: entry is not packed: " + TARGET)

        needle = NEEDLE.encode("utf-8")
        replacement = REPLACEMENT.encode("utf-8")

        new_data = bytearray()
        patched = False
        for path, item in entries:
            if item.get("unpacked") or "link" in item:
                continue
            size = item["size"]
            offset = int(item["offset"])
            content = data[offset:offset + size]
            if path == TARGET:
                index = content.find(needle)
                if index < 0:
                    sys.exit(
                        "patch-asar.py: the code to patch is not in " + TARGET + "."
                        " The upstream app changed and this patch needs updating."
                    )
                if content.find(needle, index + 1) >= 0:
                    sys.exit("patch-asar.py: the code to patch is not unique in " + TARGET + ".")
                content = content[:index] + replacement + content[index + len(needle):]
                patched = True
                integrity = item.get("integrity")
                if integrity and "sha256" in integrity:
                    digest = hashlib.sha256(content).digest()
                    integrity["sha256"] = base64.b64encode(digest).decode("ascii")
            item["size"] = len(content)
            item["offset"] = str(len(new_data))
            new_data.extend(content)

        if not patched:
            sys.exit("patch-asar.py: nothing patched in " + TARGET)

        out = rebuild_header_bytes(header) + bytes(new_data)
        tmp = asar + ".new"
        with open(tmp, "wb") as f:
            f.write(out)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, 0o444)
        # The archive comes out of a squashfs image, so the directory holding
        # it is read-only. Replacing the file in place needs a writable
        # directory, so widen it for the moment it takes.
        directory = os.path.dirname(asar) or "."
        previous_mode = os.stat(directory).st_mode
        os.chmod(directory, previous_mode | 0o200)
        try:
            os.replace(tmp, asar)
        finally:
            os.chmod(directory, previous_mode)
        print("patch-asar.py: patched " + TARGET)


    if __name__ == "__main__":
        main()
  '';
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    patchelf
    pkgs.python3
  ];

  dontUnpack = true;

  # The fixup phase would run `patchelf --shrink-rpath` over every ELF in
  # $out and delete the RPATH entries whose libraries it cannot see a use
  # for. It cannot see the dlopen'd ones — libnotify, libsecret, the
  # addons' own dependencies — so it strips exactly the entries that are
  # load-bearing here. The RPATH is set explicitly below instead.
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/deepai-code"
    cd "$out/libexec/deepai-code"

    # Unpack the AppImage's squashfs payload. --appimage-extract needs no
    # FUSE and no mount: the runtime unpacks into ./squashfs-root.
    cp ${src} ./deepai-code.appimage
    chmod +x ./deepai-code.appimage
    ./deepai-code.appimage --appimage-extract > /dev/null
    rm ./deepai-code.appimage
    mv squashfs-root/* .
    mv squashfs-root/.[!.]* . 2> /dev/null || true
    rmdir squashfs-root

    # The AppImage's own Vulkan stack is removed.
    #
    # It is libvulkan.so.1 + libvk_swiftshader.so + vk_swiftshader_icd.json,
    # a loader and a software ICD shipped side by side. With --force-rpath
    # and $ORIGIN first in the RPATH, the bundled loader is the one the GPU
    # process dlopen's, and it finds the bundled software ICD next to it.
    #
    # Deleting the bundled loader lets the nix vulkan-loader (already in
    # runtimeDeps) take its place. The nix loader finds the ICDs the way
    # the system does, through XDG_DATA_DIRS, which is where a NixOS
    # session's Mesa ICDs live. The bundled software ICD is not needed:
    # Chromium only reaches for it when there is no hardware driver, and
    # there is one here.
    #
    # This is not what fixes the GPU crash — see the header. The crash is
    # the shared shader cache, and it happens with the bundled stack just
    # as it happens with the nix one. Removing the bundled stack is done
    # because shipping a private Vulkan loader and a software rasterizer
    # that shadows the system's is a packaging mistake, not because of the
    # crash.
    rm -f libvulkan.so.1 libvk_swiftshader.so vk_swiftshader_icd.json

    # The nix glibc loader, and an RPATH that names the store. This is what
    # makes process.execPath — the path the app writes into its own URL
    # handler entry, its CLI shim and its auto-relaunch — a path that works
    # outside any wrapper. See the header for why that matters.
    #
    # Every ELF in the payload is patched, not a hand-picked list: the
    # addons under app.asar.unpacked and the vendored binaries under
    # resources/ are as load-bearing as the main executable, and the list
    # changes between releases.
    while IFS= read -r -d "" elf; do
      if patchelf --print-needed "$elf" > /dev/null 2>&1; then
        # An executable gets the loader and the full RPATH; a shared object
        # or a dlopen'd addon gets the RPATH only, and it needs the C
        # library under its own name.
        if patchelf --print-interpreter "$elf" 2> /dev/null | grep -q .; then
          patchelf --set-interpreter "${interp}" "$elf"
        fi
        patchelf --force-rpath --set-rpath "${addonRpath}" "$elf"
      fi
    done < <(find . -type f -print0)

    # The main executable and the helpers additionally need the AppImage's
    # own libraries, which sit next to them.
    for exe in \
      deepai-code \
      chrome_crashpad_handler \
      chrome-sandbox \
      resources/resource-monitor/t3-resource-monitor \
      resources/kde-capture/t3-kde-snap-shot \
      resources/hyprland-capture/t3-hyprland-snap-shot \
      resources/browser-secret/t3-browser-secret
    do
      if [ -f "$exe" ]; then
        # Single quotes: $ORIGIN has to reach patchelf literally, not be
        # expanded by the shell into the empty string.
        patchelf --force-rpath --set-rpath '${exeRpath}' "$exe"
      fi
    done

    # The GPU crash fix: append --disable-gpu-shader-disk-cache before the
    # app does anything else. See the header for why the switch has to be
    # injected here rather than passed on the command line.
    python3 ${patchAsarScript} resources/app.asar

    mkdir -p "$out/bin"

    # The launcher. It is a thin script rather than a symlink to the binary
    # because the app has to find itself: Electron resolves its resources
    # (app.asar, locales, the .pak files) relative to the directory the
    # binary lives in, and the binary has to live next to them.
    #
    # No APPIMAGE is exported. The app reads APPIMAGE to decide that it is
    # running from an AppImage, and then writes a CLI shim that expects to
    # be able to `--appimage-mount` itself — which this is not.
    cat > "$out/bin/deepai-code" <<EOF
    #!/bin/sh
    # Chrome's setuid sandbox cannot be setuid here, and the store is
    # read-only. User namespaces are the fallback; AppRun probes for them
    # the same way.
    if ! unshare -Ur true 2> /dev/null; then
      exec "$out/libexec/deepai-code/deepai-code" --no-sandbox "\$@"
    fi
    exec "$out/libexec/deepai-code/deepai-code" "\$@"
    EOF
    chmod +x "$out/bin/deepai-code"

    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/deepai-code.desktop" <<EOF
    [Desktop Entry]
    Name=DeepAI Code
    Exec=$out/bin/deepai-code %U
    Terminal=false
    Type=Application
    Icon=deepai-code
    StartupWMClass=deepai-code
    Comment=DeepAI Code is a desktop app for coding agents.
    MimeType=x-scheme-handler/deepai-code;x-scheme-handler/deepai-code-dev;
    Categories=Development;
    EOF

    mkdir -p "$out/share/icons/hicolor/512x512/apps"
    cp usr/share/icons/hicolor/512x512/apps/deepai-code.png \
      "$out/share/icons/hicolor/512x512/apps/deepai-code.png"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent desktop app: run DeepAI or your own provider against a codebase";
    homepage = "https://deepai.org/chat/ai-code";
    # Free to use, but no published source licence for the application
    # itself — the repository only carries Electron's and Chromium's. The
    # `allowUnfree` in ../modules/system/core.nix is what lets this evaluate.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
