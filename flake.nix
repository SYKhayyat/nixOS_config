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

    # ── Emacs ───────────────────────────────────────────────────────────────
    # The Emacs configuration is ~/emacs-configs: a writable git checkout with
    # three profiles (hebrew, notes, ide) whose packages are owned by
    # package.el in `elpa/`. It is deliberately NOT a flake input — CI has no
    # such directory to evaluate, and the checkout's own git pins it. See
    # modules/home/emacs.nix for what Nix provides around it.

    # ── Vocalinux: offline voice dictation ────────────────────────────────
    # Speak and the text lands in whatever window has focus. Local engines only
    # (whisper.cpp by default) — the remote mode is opt-in and points at a
    # server you run, so the default path is the study airgap's kind of
    # program, not the network-bound kind.
    #
    # Not in nixpkgs (checked against the pinned 26.05, 2026-11-14) and upstream
    # ships its own flake with a package and both modules, so this is an input
    # rather than a local package the way clixad and omnirush are.
    #
    # `follows nixpkgs` is the reason this costs no second evaluation: upstream
    # pins `nixos-unstable`, and following our branch means its
    # `python3Packages` are the same ones the rest of the machine uses. The
    # accepted risk is that a package upstream only ever tests on unstable can
    # meet an older Python package set here — `just eval` is what notices, and
    # the version is frozen in flake.lock either way.
    vocalinux = {
      url = "github:VocaHQ/vocalinux";
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
      # One list. It is used twice — by `pkgs` here (the formatter and the
      # dev shell) and by the NixOS module below — so a package cannot exist in
      # one and be missing from the other.
      overlays = [
        inputs.llm-agents.overlays.shared-nixpkgs
        darktableOverlay
        rapidrawOverlay
        clixadOverlay
        omnirushOverlay
        otzariaOverlay
        deepaiCodeOverlay
        quicklispOverlay
        npmCliOverlay
        vocalinuxOverlay
      ];
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        inherit overlays;
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
          # Read from the lock, not written here: the lock is what the build
          # actually installs, so a hand-typed string could only ever disagree
          # with it (and did).
          version =
            (lib.importJSON ./packages/clixad/package-lock.json).packages."node_modules/clixad".version;
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
      # Omnirush — a terminal coding agent with free daily tokens. Neither in
      # nixpkgs nor in numtide's llm-agents.nix, so it is a local package:
      # two npm tarballs unpacked into npm's own layout, wrapped with node.
      # The argument is the whole explanation of why it is not built the way
      # clixad above is. See packages/omnirush.nix.
      omnirushOverlay = final: _prev: {
        omnirush = final.callPackage ./packages/omnirush.nix { };
        # The Electron desktop app for the CLI above. Separate package because
        # the two version independently and ship differently: the CLI is on
        # npm as a bun/node bundle, the app is a 690 MB Electron tarball on
        # GitHub releases. See packages/omnirush-gui.nix.
        omnirush-gui = final.callPackage ./packages/omnirush-gui.nix { };
      };
      # Otzaria (אוצריא) — a Flutter app for the Jewish library, shipped as a
      # prebuilt Linux package. We fetch the app-only .deb and repackage it;
      # the seforim library downloads separately on first run. See
      # packages/otzaria.nix. Personal-Use license => local fetch, not upstream.
      otzariaOverlay = final: _prev: {
        otzaria = final.callPackage ./packages/otzaria.nix { };
      };
      # DeepAI Code — an AI coding agent desktop app from DeepAI. Not in
      # nixpkgs and not in numtide's llm-agents.nix, so it is a local
      # package. DeepAI ships a Linux AppImage but does not link it from
      # the website; the file is fetched from the bucket that the project's
      # own electron-builder manifest names. See packages/deepai-code.nix.
      deepaiCodeOverlay = final: _prev: {
        deepai-code = final.callPackage ./packages/deepai-code.nix { };
      };
      # Quicklisp — Common Lisp's library installer. `sbcl` is in nixpkgs and
      # goes in toolkit.nix; Quicklisp is not in nixpkgs (checked 2026-10-07),
      # so it is a local package. See packages/quicklisp.nix.
      quicklispOverlay = final: _prev: {
        quicklisp = final.callPackage ./packages/quicklisp.nix { };
      };
      # ── The three CLIs that used to be `npm install -g` ──────────────────
      #
      # neon, ob1 and free-pi-cli lived in ~/.npm-global: a prefix set by
      # ~/.npmrc, populated by hand, described by no lock, and rebuilt by no
      # generation. Each is now a derivation here. See packages/neon-cli.nix
      # for why `neon-cli` and not `neon` (nixpkgs already owns that name for
      # the C library), and that file plus packages/ob1.nix and
      # packages/free-pi-cli.nix for the lockfile-and-hash bump procedure.
      #
      # cline was installed the same way and is NOT here, deliberately:
      # numtide's llm-agents.nix — already an input for opencode and freebuff —
      # packages it, with a wrapper that sets the CA bundle. Rebuilding it
      # locally would be a second pin of the same npm tarballs.
      npmCliOverlay = final: _prev: {
        neon-cli = final.callPackage ./packages/neon-cli.nix { };
        ob1 = final.callPackage ./packages/ob1.nix { };
        free-pi-cli = final.callPackage ./packages/free-pi-cli.nix { };
      };
      # Vocalinux, from the input above. The overlay exists so the module tree
      # says `vocalinux` like every other program, instead of reaching for
      # `inputs` from a home module that is not given it.
      vocalinuxOverlay = _final: _prev: {
        inherit (inputs.vocalinux.packages.${system}) vocalinux;
      };
      # rapidraw 1.6.4 — nixos-26.05 ships 1.5.8, unstable has 1.6.4. The
      # toolkit.nix `offInStudy` list keeps its single `rapidraw` statement;
      # this overlay decides what that name means.
      rapidrawOverlay = _final: _prev: {
        inherit (unstablePkgs) rapidraw;
      };
      # `rec' so `emacsFrame' below can be written in terms of `emacsConfigDir'
      # rather than repeating its path. Everything else here is a leaf or,
      # where it needs to be, its own `rec'.
      myConfig = rec {
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
        # modules/home/keys.nix renders it into hyprland.conf, into the sway
        # config and into the generated guide; modules/system/desktop.nix hands
        # the same two strings to `services.xserver.xkb`,
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
        # Four consumers, two spellings. xkb's own config format,
        # hyprland.conf and sway's config take comma-joined strings;
        # plasma-manager's `input.keyboard` takes lists. Both are rendered
        # here, for the palette.nix reason: a consumer that has to reformat a
        # value is a
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

        # ── Emacs ──────────────────────────────────────────────────────────
        # 30.2 from stable, and it is the PGTK build: this machine runs
        # Wayland in every session, and `emacs-pgtk` is the Wayland build
        # (where plain `emacs` is X11). The old 31-from-unstable rename existed
        # only for the deleted config's package set; the new one compiles
        # nothing, so stable is enough.
        emacs = pkgs.emacs-pgtk;

        # The configuration is ~/emacs-configs: a writable git checkout with
        # three profiles (hebrew, notes, ide) and package.el-owned `elpa/`.
        # Deliberately not a flake input (CI could not evaluate it, and the
        # checkout pins itself) and deliberately not `home.file` (bin/install
        # writes elpa/ continuously; the store is read-only).
        emacsConfigDir = "/home/shaul/emacs-configs";

        # `launch.sh <profile>` starts that profile's daemon if it is not
        # running, then opens a frame. Everything that used to spell out
        # `emacsclient -c` names this instead.
        emacsFrame = "${emacsConfigDir}/bin/emacs-notes";
        emacsFrameArgv = [ emacsFrame ];

        # A form evaluated in the notes daemon, without making a frame for it.
        # `--no-wait` is deliberately absent: $EDITOR (above) must be able to
        # block, and this half only needs the value back.
        #
        # `${emacs}` rather than `pkgs.emacs-pgtk`: this is the second place a
        # package could be named, and naming it twice is how `emacsFrame' and
        # `emacsEval' would end up in two different Emacsen the day `emacs`
        # above changes. `emacsclient` must be the client of the daemon the
        # launcher started, which is the one this attribute installs.
        emacsEval = "env -u WAYLAND_DISPLAY ${emacs}/bin/emacsclient -s emacs-notes -e";
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
            # `pkgs` comes from the NixOS module system. The flake's own `pkgs`
            # import above is the same overlay list, so `nix fmt` and the
            # machine cannot disagree about what a package name means.
            nixpkgs.overlays = overlays;
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

        # Prose that names a file this repo does not have.
        #
        # The 2026-11-18 pass found README pointing at `cli-tools.nix` months
        # after it was renamed, and three documents describing a sops setup that
        # had gone live. Neither is catchable by `nix eval` — nothing reads
        # prose — and both cost a reader more than a red job would. This is the
        # checkable half only; see tools/check-docs.sh for exactly what it can
        # and cannot see, and why AUDIT.md and CHANGES.md are excluded.
        docs =
          pkgs.runCommand "docs-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.gnugrep
                pkgs.gnused
                pkgs.coreutils
              ];
            }
            ''
              cd ${self}
              bash tools/check-docs.sh
              touch $out
            '';

        # The whole machine, built.
        #
        # `nix flake check` already *evaluates* every nixosConfiguration, and
        # evaluation is the gate that catches most of what this repo has
        # actually shipped — `awww` where `swww` was meant, `gtk.gtk4.theme =
        # null`, a keymap option spelled for the wrong grammar. All three are
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
