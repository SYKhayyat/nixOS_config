{
  description = "Shaul's NixOS Configuration";

  inputs = {
    # ── NixOS 26.05 "Yarara" — current stable, supported through 2026-12-31.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # There was a second `nixpkgs-unstable` input here, imported into a full
    # second nixpkgs and threaded through `specialArgs` into the host config and
    # `extraSpecialArgs` into every home-manager module, so that any of them
    # could say `unstable.some-package`. A repo-wide grep for `unstable.` found
    # the input URL and the comment explaining how to use it, and nothing else
    # (Lamdan 3.1). That is a second fetch, a second lock entry and a second full
    # evaluation on every rebuild, bought for zero call sites — the same shape as
    # the `lxqt` branches in the old specialisation factory, which were also a
    # hedge nobody had ever needed. Re-adding it is four lines, on the day a
    # package actually needs to run ahead of stable.

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

  outputs = { self, nixpkgs, home-manager, stylix, plasma-manager, sops-nix, ... }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      myConfig = {
        username = "shaul";
        fullName = "Shaul";
        email = "shaul.khayyat@cloudresearch.com";
        hostname = "desktop";
        homeDir = "/home/shaul";
        # Where this flake is checked out on the target machine. Used by the
        # `nrs` rebuild alias so it works regardless of the folder name.
        flakePath = "/home/shaul/nixOS_config-specializations";
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

      # `nix fmt` — format every .nix file with the RFC-style formatter.
      formatter.${system} = pkgs.nixfmt-rfc-style;

      # `nix flake check` — lint the .nix files.
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
      };

      # `nix develop` — tools for hacking on this flake.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-rfc-style
          statix
          deadnix
          nil
          just
          nh
        ];
      };
    };
}
