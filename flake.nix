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

      # `nix flake check` — lint the Nix, and verify the elisp.
      #
      # Until now this checked .nix files only. Nothing in this repo had ever
      # looked at the Emacs modules, which is why the essentials/extras split
      # could renumber every module, leave five of them requiring the old
      # feature names, and silently stop loading 1,569 of the seforim system's
      # 1,775 lines. The build stayed green the entire time; the only symptom
      # was `M-x seforim-mefarshim` not existing.
      #
      # By line count the Emacs config is ~3x the Nix configuration. Checking
      # only the smaller half was never defensible.
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

        # Static consistency over the literate module tree: every `provide`
        # matches its filename, every local `require` resolves to a module that
        # exists, dependencies point essentials -> extras and never back, no
        # orphaned .el, no capability gate naming a module that isn't there.
        #
        # Needs no Emacs and no packages, so it is fast and cannot be flaky.
        # This is the check that would have caught the breakage above.
        emacs-modules =
          pkgs.runCommand "emacs-modules-check" { nativeBuildInputs = [ pkgs.bash ]; }
            ''
              bash ${self}/modules/home/emacs/tools/check-modules.sh \
                   ${self}/modules/home/emacs/modules
              touch $out
            '';

        # The heavier half: tangle every .org and byte-compile the result
        # against the *same* Emacs the system installs. Catches what static
        # analysis can't — syntax errors, a `require` of a package that isn't
        # in the package set, macros used before they're defined.
        #
        # Warnings are informational (`byte-compile-error-on-warn` is nil in
        # verify.sh); only genuine compile errors fail this.
        emacs-bytecompile =
          let
            emacsWithPackages = import ./modules/home/emacs/emacs-package.nix { inherit pkgs; };
          in
          pkgs.runCommand "emacs-bytecompile-check"
            {
              nativeBuildInputs = [
                emacsWithPackages
                pkgs.bash
              ];
            }
            ''
              # The tools write .el next to the .org, so work on a copy: the
              # store path this check reads from is read-only.
              cp -r ${self}/modules/home/emacs ./emacs
              chmod -R u+w ./emacs
              export HOME="$PWD/home" && mkdir -p "$HOME"
              bash ./emacs/tools/tangle.sh
              bash ./emacs/tools/verify.sh
              touch $out
            '';
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
