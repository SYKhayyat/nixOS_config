# modules/home/emacs.nix
#
# Emacs on this machine: one package, the three profile launchers, and the
# three menu entries. The configuration itself (profiles, package.el, elpa/) is
# ~/emacs-configs' business; what is built here is the names that reach it.
{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  inherit (myConfig) emacs emacsLauncher emacsLauncherBin;
  profiles = [
    "hebrew"
    "notes"
    "ide"
  ];
  launcher = emacsLauncherBin;

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
  # The three launchers are store paths that `sh` the checkout's launch.sh (see
  # `emacsLauncher` in flake.nix), which is also why there is no
  # `home.sessionPath` entry for `~/emacs-configs/bin` any more: the checkout's
  # own copies have the mode problem this change stops depending on, and that
  # directory first on $PATH would shadow the wrappers with exactly the files
  # they replaced. `bin/check` and `bin/install` stay there, called by path.
  home.packages = [
    emacs
  ]
  ++ (map emacsLauncher profiles)
  ++ (with pkgs; [
    # What the new config shells out to. Deleted with the old config: texlive,
    # tinymist, tree-sitter, nil, lua-language-server and graphviz.
    typst
    sqlite
    imagemagick
    pyright
    rust-analyzer
    jdt-language-server
  ]);

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
