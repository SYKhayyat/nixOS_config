# modules/system/core.nix
#
# The machine: Nix itself, the boot loader, its name, time and language, the
# user account. Facts that would still be facts if this box never drew a pixel
# — and, since ./network.nix and the `focus` specialisation, facts that would
# still be facts if it never opened a socket either.
#
# It used to be the drawer. There was no rule about where a system-level setting
# goes, so the answer defaulted to "core.nix" the same way every package once
# defaulted to `environment.systemPackages` — and the same thing happened: the
# things that landed here stopped being findable, and then stopped agreeing with
# the modules that also declared them. Three examples, all now fixed by moving
# rather than by patching:
#
#   * the whole appearance stack — stylix, `qt`, five scaling variables and a
#     hand-written Qt theme fighting the target that computes it — is in
#     ./appearance.nix, which is a file you can read as an answer to one
#     question.
#   * `services.displayManager.sddm` was declared here *and* in ./desktop.nix.
#     Both said `enable = true`, so nothing ever complained; the greeter is part
#     of the graphical stack and now lives there once.
#   * `hardware.graphics.enable` is hardware, and ./hardware.nix is where the
#     rest of the hardware is.
{
  pkgs,
  lib,
  myConfig,
  ...
}:

{
  # ── Nix ──────────────────────────────────────────────────────────────────
  # `!include` is the non-failing form: the config evaluates and runs cleanly
  # with /etc/nix/tokens.conf absent, and picks the GitHub token up the moment
  # sops writes it. See ./secrets.nix.
  nix.extraOptions = "!include /etc/nix/tokens.conf";

  # Which netrc nix authenticates GitHub *tarball* downloads with. Left alone
  # this is nixpkgs' default, /etc/nix/netrc — a file this config neither writes
  # nor owns, so whatever is in it wins. It held an expired api.github.com
  # token, and `nixos-rebuild` failed with:
  #
  #   error: unable to download 'https://api.github.com/repos/.../tarball/...'
  #   HTTP error 401 (Bad credentials)
  #
  # even though `access-tokens` (via /etc/nix/tokens.conf, sops) was current and
  # ~/.netrc was current. access-tokens only covers the github.com host; the
  # tarball fetches go to api.github.com, which nix authenticates from the
  # netrc instead. One current file, pointed at explicitly, beats three
  # credentials where the one nix reads for tarballs is the forgotten one.
  nix.settings.netrc-file = "/home/${myConfig.username}/.netrc";

  # Both settings above are correct and were already deployed. They were still
  # being ignored, because nix merges config in this order, later winning:
  #
  #   NIX_CONFIG env  >  ~/.config/nix/nix.conf  >  /etc/nix/nix.conf
  #
  # `sudo nixos-rebuild` runs as root, so it reads root's user-level config —
  # and a hand-written /root/.config/nix/nix.conf was sitting there with an
  # `access-tokens = github.com=ghp_...` that had since been revoked. That
  # shadowed the current sops token in /etc/nix/tokens.conf for every root
  # invocation, which is every rebuild, and produced exactly the 401 quoted
  # above while a plain `nix ...` as the user worked fine — the tell that the
  # stale credential was root's, not the project's.
  #
  # So the fix is not another credential to keep current; it is to remove the
  # second, shadowing place for one. Nix reads a *user* config from
  # $XDG_CONFIG_HOME, and for root that is /root/.config — a path NixOS does not
  # manage and no NixOS option writes to, which is exactly why a file there
  # survived every rebuild and kept overriding the managed ones. `nix.settings`
  # only ever writes /etc/nix/nix.conf, so the file has to be removed from here.
  #
  # Backed up rather than deleted: it is the only record of the revoked token,
  # and if the 401 ever comes back, this is what explains it.
  #
  # Scoped to this one path on purpose. Pointing root's XDG_CONFIG_HOME at an
  # empty directory would also work and would survive recreation of the file,
  # but `environment.variables` is global — it would apply to every `sudo`
  # command and quietly relocate XDG config for every root-run tool, to fix a
  # single file. `system.activationScripts` touches only what is broken.
  system.activationScripts.nix-root-user-config = lib.stringAfter [ "etc" ] ''
    if [ -e /root/.config/nix/nix.conf ]; then
      mkdir -p /var/lib/nix/backups
      cp -a /root/.config/nix/nix.conf \
        "/var/lib/nix/backups/root-nix.conf.$(date +%Y%m%d%H%M%S)"
      rm -f /root/.config/nix/nix.conf
      echo "nix: removed shadowing /root/.config/nix/nix.conf (backed up)" >&2
    fi
  '';

  # Lix is a drop-in fork of Nix 2.18: same store, same store DB, same flake
  # semantics — so no /nix migration and no re-download. `stable` is what the
  # Lix project recommends for a release NixOS; nixpkgs 26.05 points it at
  # Lix 2.94 "Açaí na tigela" (`lixPackageSets.latest` is 2.95 if you'd rather).
  nix.package = pkgs.lixPackageSets.stable.lix;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      myConfig.username
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  # ── Boot ─────────────────────────────────────────────────────────────────
  # Ten generations in the menu. That is also the rollback story for a wedged
  # desktop — it is why there is no `minimal` specialisation any more, and if
  # you want a guaranteed TTY, press `e` here and append
  # `systemd.unit=multi-user.target`.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # The boot-menu label. `system.nixos.version = "current"` used to sit beside
  # it, which did nothing for the menu — `label` already replaces the whole
  # suffix — and made `nixos-version` and /etc/os-release report the string
  # "current" instead of the release you are on. Cosmetic right up until a
  # rebuild goes wrong and that is the command you reach for. (Lamdan 3.4.)
  system.nixos.label = "ShaulOS";

  # ── The machine's name ───────────────────────────────────────────────────
  # The rest of the network — NetworkManager, the firewall and sshd — moved to
  # ./network.nix. The hostname stayed because it is true in every closure,
  # including `focus`, which has no network stack at all. See that file for why
  # the split had to happen for a module list rather than a `mkForce` to be the
  # thing that takes the network away.
  networking.hostName = myConfig.hostname;

  # ── Time and language ────────────────────────────────────────────────────
  time.timeZone = myConfig.timezone;
  i18n.defaultLocale = myConfig.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = myConfig.locale;
    LC_IDENTIFICATION = myConfig.locale;
    LC_MEASUREMENT = myConfig.locale;
    LC_MONETARY = myConfig.locale;
    LC_NAME = myConfig.locale;
    LC_NUMERIC = myConfig.locale;
    LC_PAPER = myConfig.locale;
    LC_TELEPHONE = myConfig.locale;
    LC_TIME = myConfig.locale;
  };

  # ── Services and security that are not about the desktop ─────────────────
  programs.zsh.enable = true;

  security.rtkit.enable = true;
  security.polkit.enable = true;
  # An empty PAM stanza is the whole requirement: hyprlock needs a PAM service
  # of its own name to authenticate against, and the default rules are correct.
  security.pam.services.hyprlock = { };

  # `services.openssh.enable` was here and is in ./network.nix now, beside the
  # firewall port that exists for it. One feature, one file.
  services.dbus.enable = true;

  # ── The user ─────────────────────────────────────────────────────────────
  users.users.${myConfig.username} = {
    isNormalUser = true;
    description = myConfig.fullName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
  };

  # Not a version to keep current: it declares which release's *stateful*
  # defaults the data on this disk was created under. Leave it until you rebuild
  # the machine from scratch.
  system.stateVersion = "25.11";
}
