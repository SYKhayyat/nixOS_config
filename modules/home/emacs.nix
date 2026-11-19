# modules/home/emacs.nix
#
# Emacs on this machine: one package, the profile launchers, the three menu
# entries, and the writable tree the pinned configuration runs from.
#
# The configuration is flake input `emacsConfigs` (github:SYKhayyat/emacs-configs),
# a store path. It cannot be the tree Emacs runs from: package.el writes `elpa/`,
# Emacs writes `state/` and each profile's `eln-cache/`, and the store is
# read-only. So this module builds `myConfig.emacsConfigRoot` — a real directory
# under ~/.local/share — out of links to the read-only half and real directories
# for the writable half, and the launchers (flake.nix) point `EMACS_CONFIG_ROOT`
# at it.
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

  # `home.file` targets are relative to $HOME; this is the root's relative form.
  dataRel = lib.removePrefix "${config.home.homeDirectory}/" emacsConfigRoot;

  # The read-only half, one link per path: an input update moves them all at
  # once. The per-profile directory itself stays a real directory, because
  # Emacs writes `eln-cache/` inside the `--init-directory` it is given.
  links = {
    "${dataRel}/lisp".source = "${emacsConfigSource}/lisp";
    "${dataRel}/vendor".source = "${emacsConfigSource}/vendor";
    "${dataRel}/bin".source = "${emacsConfigSource}/bin";
    "${dataRel}/test".source = "${emacsConfigSource}/test";
  };
  profileLinks = lib.listToAttrs (
    lib.concatMap (
      profile:
      let
        dir = "${emacsConfigSource}/configs/${profile}";
      in
      map (name: {
        name = "${dataRel}/configs/${profile}/${name}";
        value.source = "${dir}/${name}";
      }) (lib.attrNames (lib.filterAttrs (name: _: name != "eln-cache") (builtins.readDir dir)))
    ) profiles
  );

  # Refill `elpa/` from the pinned list. Run by activation when the directory is
  # empty (a new machine, or the first switch after the input changed), and by
  # hand after `lisp/packages.el` changes upstream — `package-refresh-contents'
  # is a network round trip, so it is not on every switch.
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
  # The install is guarded on elpa/ being empty rather than merely absent: a
  # failed install leaves the directory behind, and a switch that only checked
  # for absence would never retry.
  home.activation.createEmacsConfigRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${emacsConfigRoot}/elpa" "${emacsConfigRoot}/state"
    if [ -z "$(ls -A "${emacsConfigRoot}/elpa")" ]; then
      ${emacsInstall}/bin/emacs-install \
        || echo "emacs: package install failed; run 'emacs-install' when the network is back" >&2
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
    mkdir -p "${config.home.homeDirectory}/Documents/org"
    mkdir -p "${config.home.homeDirectory}/Documents/roam/daily"
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
}
