# modules/system/focus.nix
#
# Emacs, and as close to nothing else as this machine can be talked into.
#
# ── Why this is a specialisation, when `minimal` was deleted for being one ──
#
# hosts/desktop/configuration.nix removed `minimal`, `niri` and `hyprland` and
# gave the reason: a boot closure is the wrong shape for a question a display
# manager already answers. That argument is still right, and it does not cover
# this file, because this file is not asking that question.
#
# ./study-offline.nix states the test in as many words: a specialisation is for
# the difference that "genuinely cannot coexist with the base system at
# runtime… the shape a specialisation is actually good at: turning off *state*.
# Every line is a service or a radio, not a package."
#
# Baloo is state. So is plasmashell, and kwin, and SDDM, and the recoll
# indexer, and ollama, and NetworkManager. On the running system, before this
# file existed:
#
#     kde-baloo                536 MB
#     plasma-plasmashell       294 MB
#     plasma-kwin_wayland      261 MB
#     plasma-kded6              20 MB
#     plasma-kactivitymanagerd  14 MB
#     fwupd                     27 MB
#     display-manager (SDDM)    15 MB
#     ollama                    12 MB
#     NetworkManager + wpa_supplicant + ModemManager
#                               16 MB
#     …plus kwalletd, powerdevil, ksmserver, xdg-desktop-portal-kde,
#     xembedsniproxy, speech-dispatcher, geoclue, the Discover notifier,
#     at-spi, accounts-daemon, cups, udisks2, upower
#
#     emacs.service             35 MB
#
# — roughly 1.3 GB resident to host a 35 MB editor, on a laptop with 11.6 GB
# of RAM whose swap was 11.6 GB of 12.8 used. None of that can be logged out
# of at the greeter, which is exactly the line the deleted specialisations
# failed and this one passes.
#
# ── inheritParentConfig = false, and why it is the whole design ─────────────
#
# The trap in writing this the obvious way is documented twice in this repo
# already. ./study-offline.nix: "A specialisation can only ever *add* —
# inheriting is the whole mechanism — so every subtraction it wants has to be
# spelled as a force, and a list of forces is a list you have to remember to
# extend." ../home/toolkit.nix says the same thing about packages and calls the
# result the drawer.
#
# Written as an inheriting specialisation, `focus` would be about fifteen
# `mkForce false` lines — sddm, plasma6, xserver, baloo, printing, flatpak,
# kdeconnect, ollama, locate, recoll, blueman, bluetooth, fwupd, udisks2,
# upower, networkmanager — and it would silently stop being true the first time
# ./desktop.nix gained a sixteenth service. That is precisely the failure that
# put `lynx` on $PATH inside the airgap.
#
# `specialisation.focus.inheritParentConfig = false` (set in
# hosts/desktop/configuration.nix) makes this a *different import list* rather
# than the same one with holes punched in it. Plasma is absent here because
# nothing imported ./desktop.nix — not because anything switched it off. There
# is no list to keep up to date, and a service added to ./desktop.nix tomorrow
# cannot leak in.
#
# It also dissolves the problem ./profile.nix is an essay about. That file
# exists because `home-manager.users.<name>` is a submodule, so a specialisation
# defining `users.shaul.imports` MERGES with the parent's rather than replacing
# it — which is how the old study mode ended up with the whole desktop profile
# bolted underneath it, and why `shaulos.study` is a boolean instead of a second
# import site. With `inheritParentConfig = false` there is no parent definition
# to merge with, so ../../home/focus.nix can be a genuinely different profile
# and needs no flag at all.
#
# The price, stated plainly because it is the same price
# hosts/desktop/configuration.nix charged the deleted specialisations with:
# this is a second full system closure. Every `just switch` evaluates and
# builds two systems and roots two generations. The difference is that those
# three were sessions pretending to be closures, and the state above is not.
#
# ── What has to be imported by hand ────────────────────────────────────────
#
# `inheritParentConfig = false` reaches for `noUserModules.extendModules`, and
# noUserModules is `baseModules ++ extraModules` — nixpkgs' own NixOS modules
# and nothing else. `specialArgs` survives (nixos/lib/eval-config.nix passes it
# to both), so `inputs` and `myConfig` are here; the flake's `modules` list
# does not, so home-manager and stylix are not modules yet. Hence the first two
# imports below, which in the parent closure come from flake.nix.
{
  inputs,
  myConfig,
  pkgs,
  ...
}:

{
  imports = [
    # Normally supplied by flake.nix's `modules` list. See the header.
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix

    ../../hosts/desktop/hardware-configuration.nix

    # ── What a smaller system still is ──────────────────────────────────
    ./core.nix # Nix, the boot loader, the hostname, locale, the user
    ./hardware.nix # graphics, zram, /tmp, TLP — this laptop, unchanged
    ./base-tools.nix # the repair set, and the spell-checking DICPATH
    ./appearance.nix # the ONE statement of how this looks — and `culmus`

    # ── Deliberately absent, each one a running process ─────────────────
    #
    # ./desktop.nix    X, SDDM, Plasma, PipeWire, CUPS, Bluetooth, KDE
    #                  Connect, Flatpak. This is the 1.1 GB.
    # ./niri.nix       both compositors, and ./wayland.nix with them —
    # ./hyprland.nix   uwsm, udisks2, upower, gnome-keyring, the portals.
    # ./network.nix    NetworkManager, wpa_supplicant, ModemManager, sshd.
    # ./services.nix   ollama, the plocate updatedb timer, the four-hourly
    #                  recollindex run. `recoll` the *program* is still in
    #                  ../../home/focus.nix, because Emacs's seforim search
    #                  shells out to it — what is gone is the indexer
    #                  waking up on a timer. Run `recollindex` by hand.
    # ./data.nix       the rclone bootstrap timer.
    # ./secrets.nix    sops needs a network to be worth having.
    # ./profile.nix    the `shaulos.study` flag, which nothing here reads.
  ];

  # ── The one thing not importing ./network.nix does not take away ────────
  #
  # Everything else in this file is a subtraction by construction, and this
  # line is the exception that proves the rule is worth stating: NixOS's
  # `networking.useDHCP` defaults to **true**, and it is not NetworkManager
  # that implements it. Drop NetworkManager and the base networking module
  # simply falls back to the other DHCP client — so the first build of this
  # closure had no NetworkManager, no wpa_supplicant and no ModemManager, and
  # a `dhcpcd.service` that nothing in this repo had ever mentioned, soliciting
  # a lease on every interface.
  #
  # That is worth writing down rather than just fixing, because it is the
  # failure mode of the whole design: "absent because nothing imported it" is
  # only true of options whose default is off. Nothing said a word — the
  # closure evaluated, built, and would have booted; the unit only showed up
  # in a diff of `etc/systemd/system` against the parent.
  networking.useDHCP = false;

  # ── The session ────────────────────────────────────────────────────────
  #
  # No display manager. `services.cage` replaces `getty@tty1` with a wlroots
  # kiosk compositor that runs exactly one program — no bar, no keybinds, no
  # config file, about 3 MB. Emacs is the window manager: the config already
  # ships `22-dirvish` and `23-vterm-pro`, so splits are windows, vterm is the
  # terminal, and yazi runs inside it.
  #
  # Not sway, niri or Hyprland, and the reason is this repo's own history
  # rather than a benchmark: ./wayland.nix exists because niri.nix and
  # hyprland.nix carried 22 byte-identical lines that drifted apart while
  # nobody could see them side by side. A third tiling config, for a session
  # with one window in it, buys a keymap to keep in sync and nothing else.
  #
  # The one thing worth knowing before choosing this: cage shows a single
  # toplevel. A second window stacks on top with no way to switch to it. That
  # is the trade — Emacs's own window management instead of a compositor's.
  services.cage = {
    enable = true;
    user = myConfig.username;

    # `emacsclient -c -a ''` is the same command ../home/emacs/default.nix
    # already sets as $EDITOR: attach to the daemon, and start one if there
    # isn't yet. That last part is what makes this safe against the race with
    # home-manager's `emacs.service`, which the user systemd manager starts
    # from its own default.target — whichever wins, there is one daemon and
    # this is a frame on it.
    program = pkgs.writeShellScript "focus-session" ''
      exec ${myConfig.emacsPackage}/bin/emacsclient -c -a ""
    '';
  };

  # cage exits when its program does, and its unit has no Restart=, so `C-x
  # C-c` would otherwise drop you on a dead tty1 with no way back but a
  # reboot. Closing the last frame gives you a new Emacs instead.
  #
  # `RestartSec` is here rather than left at the 100 ms default because
  # "always" plus a program that fails instantly is a tight respawn loop, and
  # the thing it would be spinning on is the editor failing to start — which
  # you want to be able to read in the journal, and to Ctrl-Alt-F2 away from.
  systemd.services.cage-tty1.serviceConfig = {
    Restart = "always";
    RestartSec = 2;
  };

  # ── The user environment ───────────────────────────────────────────────
  # ONE import site, exactly as hosts/desktop/configuration.nix has — but for
  # the opposite reason. There, a second definition would merge with the first
  # (see ./profile.nix). Here there is no first: this closure does not inherit,
  # so this is the only `home-manager.users.<name>` statement in it, and it can
  # therefore name a genuinely different profile.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit myConfig; };
    users.${myConfig.username}.imports = [ ../../home/focus.nix ];
  };
}
