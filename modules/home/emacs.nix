# modules/home/emacs/default.nix
#
# Emacs on this machine: one package, the profile launchers that already live
# in ~/emacs-configs/bin, and the three menu entries. The configuration itself
# (profiles, package.el, elpa/) is that checkout's business, not Nix's.
{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  inherit (myConfig) emacs emacsConfigDir;
  launcher = profile: "${emacsConfigDir}/bin/emacs-${profile}";
in
{
  # 30.2, PGTK — the Wayland build. `emacs` rather than `emacs-pgtk` would be
  # the X11 build, which every session here would run through XWayland.
  home.packages = [
    emacs
  ]
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

  # Provides emacs-hebrew, emacs-notes and emacs-ide.
  home.sessionPath = [ "${emacsConfigDir}/bin" ];

  # $EDITOR is the notes profile's launcher. It is deliberately not an
  # emacsclient invocation: `launch.sh` is what starts the daemon when there is
  # none, and adding flags here would re-implement it in a second place.
  home.sessionVariables = {
    EDITOR = launcher "notes";
    VISUAL = launcher "notes";
  };

  # Three entries, one per profile. `%F` is the file list from the file
  # manager, empty when nothing is selected.
  xdg.desktopEntries = lib.genAttrs [ "emacs-hebrew" "emacs-notes" "emacs-ide" ] (
    name:
    let
      profile = lib.removePrefix "emacs-" name;
    in
    {
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
      mimeType =
        if profile == "notes" then
          [
            "text/plain"
            "text/org"
            "text/markdown"
          ]
        else
          [ ];
    }
  );

  # The directories the config expects. elpa/ is created by its own installer;
  # these are the state directories under $HOME that nothing else owns.
  home.activation.createOrgSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/Documents/org"
    mkdir -p "${config.home.homeDirectory}/Documents/roam/daily"
  '';

  # The deleted module's bridge, deleted. `emacsDotDBridge` in the old
  # modules/home/emacs/default.nix symlinked ~/.emacs.d/init.el and
  # early-init.el to store files that set `user-emacs-directory` to
  # ~/.config/emacs and then load an init.el from there — a file the *same*
  # deleted module used to provide. Removing the module does not remove what
  # its activation wrote, so both links survived the switch pointing at a path
  # that is now empty: plain `emacs` (anything not started through the three
  # launchers, e.g. from a shell or a third-party program) loads the bridge,
  # fails to find ~/.config/emacs/init.el, and reports that on every start.
  # The store files also go away at the next GC, at which point the links read
  # as a missing init rather than a wrong one.
  #
  # Only the two symlinks, and only when they point into the store: a regular
  # file in ~/.emacs.d is somebody's, not this module's.
  home.activation.removeEmacsDotDBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    emacsDotD="${config.home.homeDirectory}/.emacs.d"
    for f in "$emacsDotD/init.el" "$emacsDotD/early-init.el"; do
      if [ -L "$f" ]; then
        case "$(readlink "$f")" in
          /nix/store/*) $DRY_RUN_CMD rm -f "$f" ;;
        esac
      fi
    done
  '';
}
