{
  description = "Shaul's NixOS Configuration";

  inputs = {
    # ── NixOS 26.05 "Yarara" — current stable, supported through 2026-12-31.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # Bleeding edge, exposed to home modules as the `unstable` arg so a single
    # package can run ahead without dragging the whole system with it.
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

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, stylix, plasma-manager, sops-nix, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # Threaded through specialArgs as `unstable`. Use it for the handful of
      # packages worth chasing upstream on: `unstable.some-package`.
      unstable = import nixpkgs-unstable {
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

        # From the emacs-config input. Threaded through `myConfig` rather than
        # `extraSpecialArgs` on purpose: only one module needs them, and the
        # alternative is plumbing `inputs` through mk-specialization.nix and
        # all four specialisations to reach it.
        emacsConfig = inputs.emacs-config.packages.${system}.default; # pre-tangled
        emacsPackage = inputs.emacs-config.packages.${system}.emacs; # emacs + packages
      };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs myConfig unstable; };
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
