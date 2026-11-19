# modules/home/emacs.nix
#
# Emacs on this machine: one package, the profile launchers, the three menu
# entries, and the writable tree the pinned configuration runs from.
#
# The configuration is flake input `emacsConfigs` (github:SYKhayyat/emacs-configs),
# a store path. It cannot be the tree Emacs runs from: package.el writes `elpa/`,
# Emacs writes `state/`, and the store is
# read-only. So this module builds `myConfig.emacsConfigRoot` — a real directory
# under ~/.local/share — out of links to the read-only half and real directories
# for the writable half, and the launchers (flake.nix) point `EMACS_CONFIG_ROOT`
# at it. Emacs writes only under `state/` (history, and `state/eln-cache/`, the
# native code for all three profiles) and package.el only under `elpa/`.
#
# `shaulos.emacs.dev` points the read-only half at the checkout instead, so an
# edit in ~/emacs-configs reaches the next daemon start without a push, a pin
# bump and a switch.
{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  inherit (myConfig)
    emacs
    emacsConfigRoot
    emacsConfigSource
    emacsLauncher
    emacsLauncherBin
    ;

  # The profiles are the checkout's: one directory under `configs/` each, and
  # `launch.sh` rejects any name that is not one of them. Read rather than
  # listed here, so a profile added upstream needs no change in this repository.
  profiles = lib.attrNames (
    lib.filterAttrs (_: kind: kind == "directory") (builtins.readDir "${emacsConfigSource}/configs")
  );

  launcher = emacsLauncherBin;

  cfg = config.shaulos.emacs;
  checkout = "${config.home.homeDirectory}/emacs-configs";
  # Where a read-only file of the runtime tree points: the pinned store copy,
  # or in dev mode the same path in the checkout. Which files exist is still
  # read from the pin, so a file added in the checkout is linked only after the
  # pin moves (or `just switch` with `--override-input`).
  linkTo =
    rel:
    if cfg.dev then
      config.lib.file.mkOutOfStoreSymlink "${checkout}/${rel}"
    else
      "${emacsConfigSource}/${rel}";

  # `home.file` targets are relative to $HOME; this is the root's relative form.
  dataRel = lib.removePrefix "${config.home.homeDirectory}/" emacsConfigRoot;

  # The read-only half, one link per top-level directory: an input update moves
  # them all at once. Read from the source rather than listed, so a directory
  # added upstream is in the runtime tree without a change here. Not linked:
  # `configs/` (below, per file), the two writable directories, hidden
  # directories, and plain files — the docs are not read at run time, and
  # `packages.lock` is *written* by `bin/install` into the root, so it must not
  # be a link into the store.
  # The same two `createEmacsConfigRoot` creates below.
  writable = [
    "elpa"
    "state"
  ];
  topDirs = lib.attrNames (
    lib.filterAttrs (
      name: kind:
      kind == "directory" && name != "configs" && !(lib.elem name writable) && !(lib.hasPrefix "." name)
    ) (builtins.readDir emacsConfigSource)
  );
  links = lib.genAttrs' topDirs (name: {
    name = "${dataRel}/${name}";
    value.source = linkTo name;
  });
  profileLinks = lib.listToAttrs (
    lib.concatMap (
      profile:
      let
        dir = "${emacsConfigSource}/configs/${profile}";
      in
      map (name: {
        name = "${dataRel}/configs/${profile}/${name}";
        value.source = linkTo "configs/${profile}/${name}";
      }) (lib.attrNames (lib.filterAttrs (name: _: name != "eln-cache") (builtins.readDir dir)))
    ) profiles
  );

  # Fill `elpa/` from the list in `lisp/packages.el` (the pinned one, or the
  # checkout's in dev mode), and delete what the list dropped. Run by
  # activation on the first switch after the pin moves (see
  # `createEmacsConfigRoot` below), and by hand when that install failed or
  # after editing the list in dev mode.
  emacsInstall = pkgs.writeShellScriptBin "emacs-install" ''
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        emacs
      ]
    }''${PATH:+:$PATH}
    export PATH
    EMACS_CONFIG_ROOT=${emacsConfigRoot}
    export EMACS_CONFIG_ROOT
    exec ${emacsConfigSource}/bin/install "$@"
  '';

  # One menu entry per profile: the attribute name is the file's name, and
  # `Name=` in the file is the same string. `%F` is the file list from the file
  # manager, empty when nothing is selected.
  entry =
    profile:
    let
      name = "emacs-${profile}";
    in
    {
      inherit name;
      value = {
        inherit name;
        genericName = "Text Editor";
        comment = "Emacs (${profile} profile)";
        startupNotify = true;
        exec = "${launcher profile} %F";
        icon = "${emacs}/share/icons/hicolor/scalable/apps/emacs.svg";
        terminal = false;
        categories = [
          "Utility"
          "TextEditor"
        ];
        mimeType = lib.optionals (profile == "notes") [
          "text/plain"
          "text/org"
          "text/markdown"
        ];
      };
    };
in
{
  options.shaulos.emacs.dev = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Run Emacs from the checkout at ~/emacs-configs instead of the pinned
      flake input: the runtime tree's `lisp/`, `vendor/`, `bin/`, `test/` and
      `configs/*/*` link there, so an edit takes effect at the next daemon
      start. Off by default, so the machine runs what is pinned and committed.

      Still from the pin even when on: the set of files linked (a new file
      needs a switch), and the launchers, which run the pinned `bin/launch.sh`.
    '';
  };

  config = {
    # 30.2, PGTK — the Wayland build. `emacs` rather than `emacs-pgtk` would be
    # the X11 build, which every session here would run through XWayland.
    #
    # The three launchers are store paths that `sh` the pinned launch.sh (see
    # `emacsLauncher` in flake.nix), which is also why there is no
    # `home.sessionPath` entry for a `bin/` directory any more: one on $PATH would
    # shadow the wrappers with files that still depend on their own mode bit.
    home.packages = [
      emacs
      emacsInstall
    ]
    ++ (map emacsLauncher profiles)
    ++ (with pkgs; [
      # What the config shells out to. Deleted with the old config: texlive,
      # tinymist, tree-sitter, nil, lua-language-server and graphviz.
      typst
      sqlite
      imagemagick
      pyright
      rust-analyzer
      jdt-language-server
    ]);

    # The runtime tree: links for what is read, real directories (below) for what
    # is written.
    home.file = links // profileLinks;

    # `elpa/` and `state/` are the two directories nothing in the store can own.
    #
    # The install re-runs whenever the pin moves: `state/installed-from` records
    # the source it last succeeded for, so `just update-emacs && just switch`
    # brings in a package added to `lisp/packages.el` upstream. It is written only
    # on success, so an install that fails partway (no network at boot, a MELPA
    # outage) is retried on the next switch rather than never. `bin/install`
    # fetches the archive lists only when a package is missing, so a re-run with
    # nothing new is offline and takes a second.
    #
    # `timeout` so a dead network cannot hold up a switch or a boot; `run` so
    # `--dry-run` creates and fetches nothing.
    home.activation.createEmacsConfigRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${emacsConfigRoot}/elpa" "${emacsConfigRoot}/state"
      stamp="${emacsConfigRoot}/state/installed-from"
      want="${emacsConfigSource}"
      if [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
        if run ${pkgs.coreutils}/bin/timeout 600 ${emacsInstall}/bin/emacs-install; then
          run ${pkgs.bash}/bin/sh -c 'printf "%s\n" "$1" > "$2"' _ "$want" "$stamp"
        else
          echo "emacs: package install failed; run 'emacs-install' when the network is back" >&2
        fi
      fi
    '';

    # $EDITOR is the notes profile's launcher. It is deliberately not an
    # emacsclient invocation: `launch.sh` is what starts the daemon when there is
    # none, and adding flags here would re-implement it in a second place.
    home.sessionVariables = {
      EDITOR = launcher "notes";
      VISUAL = launcher "notes";
    };

    # Three entries, one per profile.
    xdg.desktopEntries = lib.listToAttrs (map entry profiles);

    # The directories the config expects. elpa/ is created by its own installer;
    # these are the state directories under $HOME that nothing else owns.
    home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${config.home.homeDirectory}/Documents/org"
      run mkdir -p "${config.home.homeDirectory}/Documents/roam/daily"
    '';

    # ── What is deliberately not here ────────────────────────────────────────
    # `emacsDotDBridge` in the deleted modules/home/emacs/default.nix symlinked
    # ~/.emacs.d/init.el and early-init.el to store files that set
    # `user-emacs-directory` to ~/.config/emacs and load an init.el from there.
    # Deleting that module does not delete what its activation wrote, so both
    # links outlived it, pointing at a directory the same module had emptied:
    # plain `emacs` opened by reporting a missing init, then activating packages
    # whose store dependencies had gone with the config.
    #
    # They were removed once, by hand, along with ~/.emacs.d and ~/.config/emacs
    # — the old config's runtime state, and the second of those is what Emacs
    # adopts as its config directory on any machine where the first is absent.
    # No activation replaced them. A module that no longer writes a file has no
    # business carrying permanent code to delete it, and the condition cannot
    # recur: nothing but the deleted module could create those links.
  };
}
