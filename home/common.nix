{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  # Resets Plasma's own state to the packaged defaults. Everything it deletes is
  # either written by Plasma at runtime or written by plasma-manager on the next
  # activation, so `just switch` puts the declared half back.
  #
  # Three things were wrong with it, and the first two meant it had never run to
  # completion:
  #
  #   * `killall` comes from psmisc, which nothing in this config installs. The
  #     line failed with "command not found", which `|| true` then swallowed —
  #     so the wipe ran against a live Plasma that rewrote its config on exit,
  #     which is the one thing the script exists to prevent. `pkill` is in
  #     procps, in NixOS's required-packages set, and is named by store path
  #     here like every other program this repo shells out to.
  #   * `killall -u shaul kwin_wayland plasmashell` is not the syntax either
  #     tool takes: `-u` *restricts* a name match to a user, it does not
  #     introduce a name list. As written it asked to kill processes named
  #     `kwin_wayland` and `plasmashell` owned by nobody in particular — and
  #     with psmisc absent it never got as far as being wrong.
  #   * matching those two by *name* does not work on NixOS at all, which is
  #     the same finding as the compositor detection in
  #     ../modules/home/scripts.nix. Both binaries are nixpkgs wrappers, so the
  #     kernel takes `comm` from the wrapped executable and truncates it to 15
  #     characters: on the Plasma session running right now they report
  #     `.plasmashell-wr` and `.kwin_wayland-w`, and `pkill -x plasmashell`
  #     matches nothing. `-f` matches the command line, where `exec -a` has put
  #     the name you were looking for.
  #   * `~/.p10k.zsh` is a home-manager symlink into the store (see
  #     ../modules/home/p10k.nix). Deleting it does not reset a prompt, it
  #     breaks `source ~/.p10k.zsh` in initContent until the next activation.
  #     Plasma has no opinion about zsh; a Plasma wipe should not touch it.
  plasmaWipe = pkgs.writeShellScriptBin "plasma-wipe" ''
    echo "══════════════════════════════════════════════════════════════"
    echo "          KDE PLASMA 6 NUCLEAR WIPE SCRIPT"
    echo "══════════════════════════════════════════════════════════════"
    echo "Deletes all Plasma/KDE state in ~/.config, ~/.local/share and"
    echo "~/.cache, then reboots. Declared settings come back on the next"
    echo "activation; anything you changed in System Settings does not."
    read -p "Proceed? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${pkgs.procps}/bin/pkill -u "$(id -u)" -f '/bin/plasmashell' || true
        ${pkgs.procps}/bin/pkill -u "$(id -u)" -f '/bin/kwin_wayland' || true
        rm -rf ~/.config/plasma* ~/.config/kde* ~/.config/kdeglobals ~/.config/kwin*
        rm -rf ~/.local/share/plasma* ~/.local/share/desktop-directories
        rm -rf ~/.cache/plasma* ~/.cache/kde* ~/.cache/kwin*
        echo "Wipe complete. Rebooting..."
        sudo reboot
    fi
  '';
in
{
  # `./../modules/home/scripts.nix` used to be imported here, and this file is
  # the wrong place for it — a fact that only became load-bearing with the
  # `focus` closure, which wants zsh and git and does not want a compositor.
  #
  # Every script in that module is a *compositor* script: `spotlight` and
  # `teleport` shell out to `niri msg` / `hyprctl`, the toggles bind foot and
  # fuzzel, `screenshot-edit` drives grim/slurp/swappy. Importing it from here
  # meant that the file describing "zsh, git, aliases" pulled foot, fuzzel,
  # grim, slurp, swappy and libnotify into any profile that wanted a shell.
  #
  # It is imported by ../modules/home/wayland-common.nix now, beside mako and
  # fuzzel — i.e. by the module that already owns the Wayland session stack and
  # is imported by exactly the profile that has a compositor to talk to.
  home.username = myConfig.username;
  home.homeDirectory = myConfig.homeDir;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # There was a `gtk.gtk4.theme = null;` here, commented "FIX: Silence GTK4
  # warning". The warning was real: home-manager 26.05 changed the default of
  # that option from `config.gtk.theme` to `null`, and on a profile with
  # `stateVersion = "25.11"` it warns until you say which one you want. Setting
  # it explicitly was the right answer to that.
  #
  # It stopped being the right answer when stylix started setting the same
  # option. Stylix's GTK target does `gtk.gtk4.theme = config.gtk.theme` at
  # ordinary priority, this said `null` at ordinary priority, and the option's
  # type is `nullOr` — whose merge function does not pick a winner, it throws:
  #
  #     The option `gtk.gtk4.theme' is defined both null and not null
  #
  # That is an evaluation error, not a warning: `nixos-rebuild` never gets as
  # far as building. It has been latent since the 26.05 bump, which was authored
  # off-machine like everything else here and has never been evaluated.
  #
  # Deleting the line rather than forcing it to `null`: with stylix defining the
  # option the deprecation default is never reached, so the warning stays gone,
  # and GTK 4 apps get the same adw-gtk3 that GTK 3 apps already had instead of
  # being the one toolkit left unthemed.

  # There was a `force-clean-git-files` activation block here, running
  # `entryBefore ["checkLinkTargets"]` and `rm -f`-ing ~/.gtkrc-2.0 and
  # ~/.bashrc if they were real files rather than symlinks, so that
  # home-manager could take them over.
  #
  # It is the hand-rolled version of `home-manager.backupFileExtension`, which
  # hosts/desktop/configuration.nix now sets — and it is the version that loses
  # the file. checkLinkTargets already knows how to handle a real file in the
  # way: with a backup extension configured it warns, and linkGeneration then
  # *moves* the original to `<file>.hm-bak`. Running `rm -f` in the entry
  # scheduled immediately before that meant the file was gone before the
  # mechanism that would have kept it ever ran, for the two paths named here.
  #
  # Same shape as the `backupCommand = "true"` it sat under, and the same
  # answer: the module system already computes this, so state it once, there.

  # A stale backup makes the *next* activation abort. With
  # backupFileExtension set (hosts/desktop/configuration.nix,
  # modules/system/focus.nix), linkGeneration moves a colliding file to
  # `<file>.hm-bak` — but if that path already exists from an earlier switch,
  # it refuses to clobber it and home-manager-shaul.service fails. This hits
  # on every rebuild for ~/.gtkrc-2.0, because GTK apps keep writing it back
  # as a real file between switches.
  #
  # Deleting only files ending in the configured extension is safe in a way
  # the force-clean block above was not: it runs before checkLinkTargets, and
  # the current content of every colliding file is still moved to a fresh
  # backup moments later. What is discarded is an older snapshot of a file
  # whose newer self sits right next to it.
  home.activation.clearStaleBackups =
    config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
      $DRY_RUN_CMD find "$HOME" -type f -name '*.hm-bak' -delete
    '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # ZDOTDIR. `mkForce` because nothing else in the tree sets it — left as it
    # was found; that is not this pass.
    dotDir = lib.mkForce "${config.home.homeDirectory}/.config/zsh";
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "systemd"
        "command-not-found"
        "sudo"
        "extract"
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh

      # `-not -path '*/.*'`, and the four characters matter. `find -path`
      # matches the WHOLE path, which always begins `/home/…`, so the glob
      # `.*` written without the `*/` prefix can never match anything and the
      # filter silently did nothing. Measured against a fixture:
      #
      #   as written  (-not -path '.*')    Scripts .hidden .git .git/hooks normal
      #   as intended (-not -path '*/.*')  Scripts normal
      #
      # So every hidden directory under ~/Scripts was on $PATH, and the one
      # that matters is `~/Scripts/.git/hooks` — a git checkout there puts
      # `update`, `pre-commit`, `post-checkout` and `prepare-commit-msg` on the
      # path of every shell, and `update` is a real command on several distros.
      #
      # Worth naming the shape, not just the bug: this is the same class as
      # modules/home/waybar.nix's integer division. `nix flake check` cannot
      # evaluate a glob's runtime behaviour, and neither statix nor deadnix
      # looks inside a shell string — so a value that is silently wrong here is
      # invisible to every gate this repo has.
      if [ -d "$HOME/Scripts" ]; then
        export PATH="$PATH$(find "$HOME/Scripts" -maxdepth 2 -type d -not -path '*/.*' -printf ":%p")"
      fi
    '';
  };

  # ── These carry `--no-update-lock-file` for the reason the justfile does ──
  #
  # The justfile states the rule in bold at the top — "Nothing in this file may
  # change flake.lock except `just lock`" — and every recipe in it honours it.
  # These two did not, and README.md presents them as the ergonomic equivalent
  # of `just switch` / `just test`, so the rule had a hole in exactly the path
  # you actually type.
  #
  # Proven by construction rather than argued: with `sops-nix` dropped from
  # flake.lock — the state this repo genuinely shipped in once, six inputs
  # declared and four pinned — `just switch` exits 1 with "requires lock file
  # changes but they're not allowed" and leaves the file alone, while `nrs`
  # exited 0, emitted a system drv, and silently rewrote flake.lock.
  #
  # `nfu` is deliberately without it: updating the lock is that alias's entire
  # job, which is the same reason `just lock` is the one recipe exempted.
  home.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake ${myConfig.flakePath}#${myConfig.hostname} --no-update-lock-file";
    nrt = "sudo nixos-rebuild test --flake ${myConfig.flakePath}#${myConfig.hostname} --no-update-lock-file";
    nfu = "nix flake update --flake ${myConfig.flakePath}";
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";
  };

  # Only the script this file defines. Everything else that used to be on this
  # line — pamixer, brightnessctl, playerctl, libsecret, jq, fd, fzf — was a
  # tool, and tools live in modules/home/toolkit.nix now, where the `study` flag
  # can reach them. Two of them (`fd`, `fzf`) were also already in
  # modules/system/cli-tools.nix, and `fzf` was a third time over: `programs.fzf`
  # below installs the package as part of configuring it, exactly as
  # `programs.bat` and `programs.git` do.
  home.packages = [ plasmaWipe ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = myConfig.fullName;
        inherit (myConfig) email;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.fzf.enable = true;
  programs.bat.enable = true;
  xdg.enable = true;
}
