{
  description = "Shaul's NixOS Configuration";

  inputs = {
    # ── NixOS 26.05 "Yarara" — current stable, supported through 2026-12-31.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # ── Unstable for packages that need to run ahead of 26.05 ───────────────
    # Re-added 2026-09-22 for darktable >=5.6: stable is 5.4.1, unstable is
    # 5.6.0 (5.6.1 not yet in nixpkgs). Cost is one extra fetch/lock/eval,
    # used only via the overlays below so no module needs `unstable.` plumbing.
    # 2026-09-24: also the source of rapidraw 1.6.4 (26.05 ships 1.5.8).
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix now lives under nix-community (danth/stylix is the old home).
    # The release branch MUST match nixpkgs + home-manager or its target modules
    # go out of sync. Following nixpkgs is what upstream's own example does, and
    # it drops the second full nixpkgs eval the old (unfollowed) setup pulled in.
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma-manager has no release branches — only `trunk`, which targets
    # home-manager master. It follows our pinned home-manager, so this is the
    # one input likely to need a manual rev pin if trunk starts using an API
    # that isn't in release-26.05.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # sops-nix ships master only; it tracks nixpkgs and works fine on stable.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Freebuff: the free coding agent CLI ────────────────────────────────
    # numtide's package wraps the prebuilt Bun binary with ripgrep on PATH.
    # No FHS needed — the binary is self-contained.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── The Emacs configuration ──────────────────────────────────────────
    # It used to live at modules/home/emacs/modules/ in this repo. By line
    # count it was never a NixOS config that includes Emacs — it is an Emacs
    # distribution that Nix happens to ship (~6,900 lines against ~2,300 of
    # Nix), and it runs on Windows and macOS too, which is why its own
    # deploy.sh has to warn you away from the machine this repo is named after.
    #
    # As an input rather than a subdirectory it is *pinned*: the exact revision
    # you are running is in flake.lock, so an older lock rebuilds the exact
    # Emacs you had. As a subdirectory it only looked pinned — the modules were
    # mtime-copied into a writable $HOME dir that Nix could not roll back.
    #
    # `packages.default` is that repo with every module already tangled, so
    # nothing is written at runtime. Bump it with:
    #     nix flake update emacs-config
    emacs-config = {
      url = "github:SYKhayyat/emacs-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      stylix,
      plasma-manager,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.llm-agents.overlays.shared-nixpkgs
          darktableOverlay
          rapidrawOverlay
          calibrawOverlay
          filmulatorOverlay
          lighttableOverlay
          clixadOverlay
          otzariaOverlay
        ];
      };
      # darktable 5.6.1 with AI — unstable is 5.6.0 and `withAi=false` by default.
      # AI gates onnxruntime + libarchive behind USE_AI (package.nix:6 `withAi ? false`).
      # You built 5.6.1 but saw no AI tab because the standard nixpkgs package
      # is built without it to avoid inflating closure for non-AI users.
      # When unstable bumps to 5.6.1, keep `override { withAi=true; }`.
      # Verified: tar e8b84ac… sha256-6LhKyYsLaJokTkA2xLVjlMHVjOLZq8BeCgYO+fdW3DY=
      # One unstable import, N overlays. darktable and rapidraw both want to
      # run ahead of 26.05; a second `import inputs.nixpkgs-unstable` in each
      # overlay would mean a second full nixpkgs evaluation to bump one attr.
      unstablePkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      darktableOverlay = final: _prev: {
        darktable = (unstablePkgs.darktable.override { withAi = true; }).overrideAttrs {
          version = "5.6.1";
          src = final.fetchurl {
            url = "https://github.com/darktable-org/darktable/releases/download/release-5.6.1/darktable-5.6.1.tar.xz";
            hash = "sha256-6LhKyYsLaJokTkA2xLVjlMHVjOLZq8BeCgYO+fdW3DY=";
          };
        };
      };
      # clixad — a free AI coding agent, distributed as a bundled npm CLI. Not in
      # nixpkgs, so this overlay wraps the pinned npm build with node. The
      # package.json/package-lock.json pair lives in ./packages/clixad; bump the
      # npmDepsHash if either changes.
      clixadOverlay = final: _prev: {
        clixad = final.buildNpmPackage rec {
          pname = "clixad";
          version = "0.0.1-beta.13";
          src = ./packages/clixad;
          npmDepsHash = "sha256-f3LP7hV0NkognqHa1djqz4tS9HQFqBG1ZHwt2sL3hKA=";
          dontNpmBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib/node_modules $out/bin
            cp -r node_modules/. $out/lib/node_modules/
            makeWrapper ${final.nodejs}/bin/node $out/bin/clixad --add-flags $out/lib/node_modules/clixad/dist/clixad.mjs
            runHook postInstall
          '';
          meta.mainProgram = "clixad";
        };
      };
      # Otzaria (אוצריא) — a Flutter app for the Jewish library, shipped as a
      # prebuilt Linux package. We fetch the app-only .deb and repackage it;
      # the seforim library downloads separately on first run. See
      # packages/otzaria.nix. Personal-Use license => local fetch, not upstream.
      otzariaOverlay = final: _prev: {
        otzaria = final.callPackage ./packages/otzaria.nix { };
      };
      # rapidraw 1.6.4 — nixos-26.05 ships 1.5.8, unstable has 1.6.4. The
      # toolkit.nix `offInStudy` list keeps its single `rapidraw` statement;
      # this overlay decides what that name means.
      rapidrawOverlay = _final: _prev: {
        inherit (unstablePkgs) rapidraw;
      };
      # The three niche raw editors. None are in nixpkgs (checked 2026-09-24,
      # both branches), and each upstream ships a built Linux bundle, so these
      # overlays repackage the bundle instead of hand-rolling three GUI stacks:
      #   calibraw    Duecki1/CalibRaw              1.0.0   AppImage
      #   filmulator  CarVac/filmulator-gui        v0.12.0 AppImage
      #   lighttable  reville/lighttable-digital-darkroom 0.7.10  raw tarball
      # Each pin was verified by unpacking the payload (bin/desktop names,
      # shebangs) as well as by hash; see the per-overlay comments.
      #
      # `wrapType2` only produces the FHS wrapper: its output is just
      # `bin/<pname>`. The AppImage's own `.desktop` entry and hicolor icon
      # (both apps keep them in `usr/share/`, Exec and pname match) are merged
      # in here so the apps reach the session's launchers.
      wrapAppImage =
        final:
        {
          pname,
          version,
          url,
          hash,
        }:
        let
          src = final.fetchurl { inherit url hash; };
          payload = final.appimageTools.extractType2 { inherit pname version src; };
        in
        final.symlinkJoin {
          name = "${pname}-${version}";
          paths = [ (final.appimageTools.wrapType2 { inherit pname version src; }) ];
          postBuild = ''
            rm -rf "$out/share"
            mkdir -p "$out/share/applications"
            for desktop in ${payload}/usr/share/applications/*.desktop; do
              install -m444 "$desktop" "$out/share/applications/"
            done
            cp -r ${payload}/usr/share/icons "$out/share/icons"
          '';
        };
      calibrawOverlay = final: _prev: {
        calibraw = wrapAppImage final {
          pname = "calibraw";
          version = "1.0.0";
          url = "https://github.com/Duecki1/CalibRaw/releases/download/1.0.0/CalibRaw-x86_64.AppImage";
          hash = "sha256-PGSXcQ9wJKZgG5f6AUYcDi6jF+E2h0mp06chCYm3ZPI=";
        };
      };
      filmulatorOverlay = final: _prev: {
        filmulator = wrapAppImage final {
          pname = "filmulator";
          version = "0.12.0";
          url = "https://github.com/CarVac/filmulator-gui/releases/download/v0.12.0/Filmulator-x86_64.AppImage";
          hash = "sha256-6FMq2Cjsz5rdCficPfkm3g0tkDpNEevI0EODTzFk4pI=";
        };
      };
      # LightTable's Linux bundle is self-contained (app + bundled Python +
      # ONNX runtime, hence 458 MB) and its two launchers are `#!/bin/sh`
      # scripts that locate their siblings relative to `$0`. NixOS has no
      # /bin/sh, so we patch the shebangs and symlink them from $out/bin; the
      # symlinks keep the scripts' "dirname of $0" = the bundle dir.
      lighttableOverlay = final: _prev: {
        lighttable = final.stdenv.mkDerivation {
          pname = "lighttable";
          version = "0.7.10";
          src = final.fetchurl {
            url = "https://github.com/reville/lighttable-digital-darkroom/releases/download/v0.7.10/LightTable-0.7.10-linux-x86_64.tar.gz";
            hash = "sha256-9ZE9R2U67d5OZOfrBJTh7EV0n3wdzzWBs7i4JBVjdls=";
          };
          # Repackaging a prebuilt bundle: leave its ELFs and RPATHs alone.
          dontStrip = true;
          dontPatchELF = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib
            cp -r . $out/lib/lighttable
            patchShebangs $out/lib/lighttable/bin/lighttable
            patchShebangs $out/lib/lighttable/bin/lighttable-desktop
            mkdir -p $out/bin
            ln -s $out/lib/lighttable/bin/lighttable         $out/bin/lighttable
            ln -s $out/lib/lighttable/bin/lighttable-desktop $out/bin/lighttable-desktop
            mkdir -p $out/share/applications $out/share/icons/hicolor/1024x1024/apps
            cp $out/lib/lighttable/share/icons/lighttable.png \
              $out/share/icons/hicolor/1024x1024/apps/lighttable.png
            cat > $out/share/applications/lighttable.desktop <<EOF
            [Desktop Entry]
            Type=Application
            Name=LightTable
            GenericName=RAW Photo Editor
            Comment=Digital darkroom for RAW photography
            Exec=lighttable-desktop %u
            Icon=lighttable
            Categories=Graphics;Photography;
            MimeType=image/raw;image/x-nikon-nef;image/x-adobe-dng;
            EOF
            runHook postInstall
          '';
          meta.mainProgram = "lighttable";
        };
      };
      myConfig = {
        username = "shaul";
        fullName = "Shaul";
        email = "shaul.khayyat@cloudresearch.com";
        hostname = "desktop";
        homeDir = "/home/shaul";
        # Where this flake is checked out on the target machine. Used by the
        # `nrs` rebuild alias so it works regardless of the current directory.
        #
        # This has been wrong twice, in exactly the same way, which is the part
        # worth keeping. It said `/home/shaul/nixOS_config-specializations` — the
        # name of the *branch*, not of any directory that has ever existed on
        # this machine — and was then corrected to `/home/shaul/nixos-config`,
        # which nobody checked either, and which does not exist. The clone is
        # `/home/shaul/config`. So all three aliases that exist to work
        # "regardless of the current directory" resolved to a path with no flake
        # in it and failed from everywhere, including the one directory where
        # plain `nixos-rebuild --flake .` would have worked. The justfile never
        # noticed because it uses `.#{{host}}` and is therefore only ever run
        # from the checkout.
        #
        # What did notice, eventually, was the home directory: a
        # `~/.config/zsh/.zshrc` left behind by the specializations branch still
        # carried the old value, and zsh sources it *after* `/etc/zshrc` — so
        # `nrs` was broken twice over, in two different ways at the same time,
        # and the second failure is the one you could see.
        flakePath = "/home/shaul/config";
        timezone = "America/New_York";
        locale = "en_US.UTF-8";
        seforimPath = "/home/shaul/Documents/seforim";

        # The keyboard, stated once, and it has to be stated *here*.
        #
        # modules/home/keys.nix renders it into niri's KDL, into
        # hyprland.conf and into the generated guide; modules/system/
        # desktop.nix hands the same two strings to `services.xserver.xkb`,
        # which is what XWayland, SDDM and the X-only apps read. Those are two
        # different module systems and neither can see the other's config, so
        # `myConfig` is the only place both of them can read from — the same
        # reason `seforimPath` is up here rather than in the two modules that
        # need it.
        #
        # It was in fact declared twice, once in each, and had already been
        # given a sixth transcription of the keymap that keys.nix exists to
        # abolish. Nothing would have said a word when they drifted; you would
        # simply have had one layout toggle in the tiling sessions and a
        # different one at the greeter.
        #
        # `grp:shifts_toggle` is the Hebrew/English toggle: hold either Shift,
        # tap the other. It replaced `grp:lctrl_lalt_toggle`, which sat on the
        # Ctrl+Alt that the VT switch (Ctrl+Alt+F1..F12) is built out of.
        # Both Shifts is the one chord with genuinely nothing else on it, and
        # — the part that matters — xkeyboard-config defines it as
        # `[Shift_L, ISO_Prev_Group]` / `[Shift_R, ISO_Next_Group]`, so both
        # keys keep working as Shift. The single-key options (`grp:rctrl_toggle`
        # and friends) *replace* their key's symbols, which spends a modifier
        # to save a keystroke.
        #
        # `caps:escape` used to be here as well and is deliberately gone: Caps
        # Lock is Caps Lock and Escape is Escape. It had never been reliable,
        # but not for the reason it looked like — see the Plasma note below.
        # Restoring it is one string in the list.
        #
        # Four consumers, two spellings. xkb's own config format, niri's KDL
        # and hyprland.conf take comma-joined strings; plasma-manager's
        # `input.keyboard` takes lists. Both are rendered here, for the
        # palette.nix reason: a consumer that has to reformat a value is a
        # consumer that can reformat it wrong, and this repo has already paid
        # for that once with `rgb(#7aa2f7)`.
        keyboard = rec {
          layouts = [
            "us"
            "il"
          ];
          options = [ "grp:shifts_toggle" ];

          layout = lib.concatStringsSep "," layouts;
          optionString = lib.concatStringsSep "," options;
        };

        # From the emacs-config input. Threaded through `myConfig` rather than
        # `extraSpecialArgs` on purpose: only one module needs them, and
        # `myConfig` already reaches every home module.
        emacsConfig = inputs.emacs-config.packages.${system}.default; # pre-tangled
        emacsPackage = inputs.emacs-config.packages.${system}.emacs; # emacs + packages
      };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs myConfig; };
        modules = [
          {
            # Expose the numtide `llm-agents` package scope (`pkgs.llm-agents.freebuff`
            # and the rest of the tree) to the system and to home-manager, whose
            # `pkgs` comes from the NixOS module system — the flake's own `pkgs`
            # import above is used for the `formatter` output only and does not
            # flow into nixosSystem.
            nixpkgs.overlays = [
              inputs.llm-agents.overlays.shared-nixpkgs
              darktableOverlay
              rapidrawOverlay
              calibrawOverlay
              filmulatorOverlay
              lighttableOverlay
              clixadOverlay
              otzariaOverlay
            ];
          }
          ./hosts/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
          sops-nix.nixosModules.sops
          {
            home-manager.sharedModules = [
              plasma-manager.homeModules.plasma-manager
            ];
          }
        ];
      };

      # `nix fmt` — format every .nix file in the tree, RFC 166 style.
      #
      # This was `pkgs.nixfmt-rfc-style`, and there are two separate things
      # wrong with that, one cosmetic and one that meant `just fmt` did nothing.
      #
      # The cosmetic half: RFC 166 won and became the only style nixfmt
      # implements, so nixpkgs collapsed the two attributes. `nixfmt-rfc-style`
      # is now an alias that prints "nixfmt-rfc-style is now the same as
      # pkgs.nixfmt which should be used instead" on every evaluation touching
      # it — including `nix fmt` and `nix develop`.
      #
      # The half that mattered: a bare formatter binary is no longer a working
      # `formatter` output. `nix fmt` runs it with the paths you passed and you
      # normally pass none, and nixfmt 1.4 with no file arguments reads *stdin*:
      #
      #     $ just fmt
      #     Warning: Bare invocation of nixfmt is deprecated. Use 'nixfmt -'…
      #     <stdin>:1:1: unexpected end of input
      #
      # — exit 0, nothing formatted, and a warning that reads like a style note
      # rather than "this command did not run". Spelling it `nix fmt .` gets a
      # different deprecation ("Passing directories … is deprecated and will be
      # unsupported soon. Please use the `pkgs.nixfmt-tree` wrapper instead").
      #
      # `nixfmt-tree` is that wrapper: nixfmt behind treefmt, which walks the
      # tree, respects .gitignore, and does the right thing when invoked with no
      # arguments — i.e. it is a `formatter` output, where nixfmt alone is a
      # formatter *program*. Same style, same result, and `just fmt` formats the
      # repo again.
      formatter.${system} = pkgs.nixfmt-tree;

      # `nix flake check` — everything that can be verified without a machine
      # to switch, and every one of these is now run by .github/workflows/
      # check.yml on every push.
      #
      # That last clause is the point. These checks existed before CI did and
      # nothing ran them, which is the same shape as the finding that caused the
      # Emacs split: `tools/verify.sh` byte-compiled every module and was wired
      # to nothing, so 1,569 lines stopped loading and no build went red. The
      # Emacs half got its CI job. This half did not, and it is the half that
      # has been authored on a Windows box with no Nix on it — including a
      # flake.lock that pinned four of the six inputs, so the repo as committed
      # did not evaluate and nothing anywhere said so.
      #
      # The Emacs checks that briefly lived here (module consistency, tangle +
      # byte-compile) moved with the config into the emacs-config repo, where
      # they run in its own CI on every push. That is the right home for them:
      # they verify the config, not the machine, and they need to run on
      # non-Nix machines too. `nix flake check` there covers both.
      checks.${system} = {
        statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
          cd ${self}
          statix check .
          touch $out
        '';
        deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          # --no-lambda-pattern-names: don't flag the { config, lib, pkgs, ... }
          # module boilerplate, only genuinely dead let-bindings / args.
          deadnix --fail --no-lambda-pattern-names ${self}
          touch $out
        '';

        # The Emacs config builds as part of the system closure, but building
        # it here too makes `nix flake check` fail fast and loudly when a bump
        # of the emacs-config input does not tangle — rather than discovering
        # it halfway through a switch.
        emacs-config = inputs.emacs-config.packages.${system}.default;

        # The whole machine, built.
        #
        # `nix flake check` already *evaluates* every nixosConfiguration, and
        # evaluation is the gate that catches most of what this repo has
        # actually shipped — `awww` where `swww` was meant, `gtk.gtk4.theme =
        # null`, `kb_options` where niri's KDL wants `options`. All three are
        # eval errors and none of them needed a byte downloaded to find.
        #
        # Evaluating is not building, though, and the difference is every
        # derivation that fails while running rather than while being described.
        # Naming the toplevel here is what turns `nix flake check` from "this
        # config parses" into "this config is a system", and it is the attribute
        # the `build` job in .github/workflows/check.yml builds — one spelling,
        # so a green check and a green CI cannot come to mean different things.
        #
        # Building it also builds the `study` specialisation: the toplevel
        # derivation links its children into $out/specialisation/<name>, which
        # is exactly what tools/check-closure.sh then reads.
        inherit (self.nixosConfigurations.desktop.config.system.build) toplevel;
      };

      # `nix develop` — tools for hacking on this flake.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt # see `formatter` above: nixfmt-rfc-style is now an alias
          statix
          deadnix
          nil
          just
          nh

          # README.md has claimed these three were in here for as long as there
          # has been a README, and secrets/README.md's walkthrough is written in
          # terms of them. They were never listed. A documented command that
          # `command not found`s is the same defect as a documented airgap with
          # a browser in it, one order of magnitude down.
          sops
          age
          ssh-to-age
        ];
      };
    };
}
