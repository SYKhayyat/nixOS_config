# modules/home/keys.nix
#
# The keymap, and the session's startup list, defined once and rendered.
#
# ── What was wrong ────────────────────────────────────────────────────────
#
# This repo already learned this lesson twice. modules/system/wayland.nix says
# it: 22 lines were copy-pasted into two compositor modules, "that was invisible
# while the two were mutually exclusive boot closures — you could never see them
# side by side — and it is the reason the two sessions drifted apart in every
# direction nobody was looking." ./palette.nix says the other half: one theme
# spelled three ways by hand, and the third spelling was a parse error nobody
# could see.
#
# The keymap is both faults at once, and it was the largest instance of either.
# One set of keys had FIVE hand-written transcriptions — niri's KDL, hyprland's
# conf, and a guide.org cheat-sheet beside each — and four of the five were
# wrong:
#
#   * `power-search` was Mod+Space in niri and Mod+P in Hyprland. Same script,
#     two keys, and nobody chose that. The Hyprland cheat-sheet had a row whose
#     entire content was the drift: "Super+Space | (unbound - power-search is
#     Super+P)".
#   * Mod+E (file manager) and Mod+Shift+E (Emacs) existed only under Hyprland.
#     Mod+1..5 (workspaces) existed only under Hyprland. niri simply had no key
#     for any of them.
#   * hyprland/guide.org documented resize as Super+Ctrl+H/L/K/J; the config
#     binds Super+Alt. It documented a three-bind "Dwindle Layout" section that
#     does not exist in the config at all, including Super+V for split control
#     — a key the same document lists as the clipboard 34 lines later.
#   * niri/guide.org had three concatenated #+TITLE lines, told you to switch
#     sessions by rebuilding a specialisation (they have been greeter sessions
#     since hosts/desktop/configuration.nix stopped building four closures),
#     said Caps Lock toggles Hebrew (it is Escape; the toggle is both Shifts),
#     pointed at ~/nixos-config for the source, and hardcoded #7aa2f7 and
#     #414868 — the exact literals ./palette.nix exists to abolish.
#
# A wrong keybinding in a config file is a key that does nothing. A wrong
# keybinding in the cheat-sheet is worse: it is a key you believe in.
#
# ── The shape of the fix ──────────────────────────────────────────────────
#
# Same shape as ./palette.nix. One definition, handed out already in the target
# syntax, and no module downstream ever writes a chord again.
#
# A bind is data: { mods, key, desc, group } plus exactly one action.
#
#   spawn = [ argv ]  A program the session provides. This is the SHARED layer
#                     — the terminal, the launcher, the scripts from
#                     ./scripts.nix, the volume keys. Its target comes from
#                     ./wayland-common.nix, which both compositors import, so
#                     the key must not depend on which one is running. Rendered
#                     into both syntaxes from one list.
#
#   cmd = "..."       A compositor verb — close-window, consume-into-column,
#                     movetoworkspace. These genuinely differ: niri scrolls
#                     columns and Hyprland tiles. Declared inside the compositor
#                     module that owns them, already in its own dialect, and
#                     never shared. The split is the same one wayland-common.nix
#                     draws between session and compositor.
#
# The guide is generated from the same lists — that is the point, not a bonus.
# A cheat-sheet maintained by hand is a fifth transcription and it will be wrong
# again by the next commit. Facts this file does not derive are not documented:
# gaps, opacity and animation curves are still literals inside each compositor's
# config text, so the guide says nothing about them rather than restating them.
{
  config,
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  inherit (lib) concatStringsSep concatMapStringsSep;

  inherit (config.shaulos.palette) css;

  wallpaper = ../../assets/wallpaper.jpg;

  # ── Chords ───────────────────────────────────────────────────────────────
  # hyprland: $mainMod SHIFT, C   sway: Mod4+Shift+C   guide: Super+Shift+C
  hyprMod = m: if m == "Mod" then "$mainMod" else lib.toUpper m;
  guideMod = m: if m == "Mod" then "Super" else m;

  # Keysym names are shared — Hyprland and sway both take xkb names, and
  # Hyprland matches them case-insensitively. Only the *display* spelling needs
  # a table, and only where the keysym is not what you would call the key.
  keyLabels = {
    grave = "`";
    Space = "Space";
    Equal = "=";
    Minus = "-";
    Slash = "/";
    Comma = ",";
    Period = ".";
    Backslash = "\\";
    XF86AudioRaiseVolume = "Volume Up";
    XF86AudioLowerVolume = "Volume Down";
    XF86AudioMute = "Mute";
    XF86MonBrightnessUp = "Brightness Up";
    XF86MonBrightnessDown = "Brightness Down";
  };

  # Empty mods renders as ", Print", which is Hyprland's spelling for a bare key.
  hyprChord = b: "${concatMapStringsSep " " hyprMod b.mods}, ${b.key}";

  # ── The sway renderer ─────────────────────────────────────────────────
  # Sway speaks i3's config language: a chord on the left, a verb on the
  # right, one per `bindsym` line. Two differences from the Hyprland
  # renderer, both spelling-level: the mod is `Mod4` rather than `$mainMod`,
  # and a bare key has no comma in front of it — `bindsym Print exec …` is
  # sway's way to bind an unmodified key, where Hyprland's `, Print` is
  # its own.
  # `concatMapStringsSep` takes (sep, f, list) — the map already happened if
  # the list is spelled as one; pass the function and the list as they are.
  swayMod = m: if m == "Mod" then "Mod4" else m;
  # Strings join with `${}`, not `++` — Nix's `++` is list concat, and the
  # first draft of this renderer used it on the chord and got exactly the
  # error that announces: "expected a list but found a string".
  swayChord =
    b: if b.mods == [ ] then b.key else "${concatMapStringsSep "+" swayMod b.mods}+${b.key}";
  swayAction = b: if b ? spawn then "exec ${lib.escapeShellArgs b.spawn}" else b.cmd;
  renderSway = binds: concatMapStringsSep "\n" (b: "  bindsym ${swayChord b} ${swayAction b}") binds;
  renderSwayStartup =
    items: concatMapStringsSep "\n" (s: "  exec --no-startup-id ${lib.escapeShellArgs s.argv}") items;
  guideChord = b: concatStringsSep "+" ((map guideMod b.mods) ++ [ (keyLabels.${b.key} or b.key) ]);

  # ── Actions ──────────────────────────────────────────────────────────────
  # Hyprland's exec hands the rest of the line to /bin/sh, so the argv has to
  # be quoted for a shell — which is what escapeShellArgs is. Sway has the
  # same job with `exec` on a bindsym line. One argv list; neither spelled by
  # hand.
  hyprAction = b: if b ? spawn then "exec, ${lib.escapeShellArgs b.spawn}" else b.cmd;

  # Every renderer indents every line itself, including the first, so the call
  # site can sit at the enclosing indented-string's base indent and the output
  # lands flush at four columns either way.
  renderHypr =
    binds: concatMapStringsSep "\n" (b: "    bind = ${hyprChord b}, ${hyprAction b}") binds;

  renderHyprStartup =
    items: concatMapStringsSep "\n" (s: "    exec-once = ${lib.escapeShellArgs s.argv}") items;

  # ── Shared programs, named once ──────────────────────────────────────────
  cliphistPick = "${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel -d | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy";
  cliphistWatch = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";

  # Hyprland's spelling. niri had `swww-daemon & sleep 1 && swww img`, which is
  # a race it usually won; this waits for the daemon to answer instead. Strictly
  # better, so both sessions get it.
  #
  # The package is `awww` — nixpkgs 26.05 renamed swww to awww and left
  # `pkgs.swww` behind as a *throwing alias that still evaluates*, printing
  # "evaluation warning: 'swww' has been renamed to 'awww'" and handing back the
  # awww derivation. The alias fixes the attribute; it does not rename the
  # binaries, and awww ships `bin/awww` and `bin/awww-daemon` only. So
  # `${pkgs.swww}/bin/swww-daemon` interpolated to a store path that does not
  # exist, in a string Nix never checks — the daemon failed to start, and then
  # `until <missing binary> query` could never succeed, so every niri and
  # Hyprland session spun this loop at half-second intervals for the life of the
  # session while the wallpaper stayed unset.
  #
  # This is the ./palette.nix lesson in the one place the palette cannot reach:
  # a value that is only wrong at runtime. `nix eval` cannot catch it — the
  # string interpolates fine — which is exactly why the package is named here
  # once and the binaries come off the same attribute.
  awwwStart = "${pkgs.awww}/bin/awww-daemon & until ${pkgs.awww}/bin/awww query 2>/dev/null; do sleep 0.5; done && ${pkgs.awww}/bin/awww img ${wallpaper}";

  guidePath = "${config.xdg.configHome}/shaulos/keys.org";

  # ── The shared session keymap ────────────────────────────────────────────
  # Every target here is installed by ./wayland-common.nix, ./scripts.nix or
  # ./lock.nix — modules both compositors import. That is the test for
  # belonging in this list, and it is why the key must be the same in both.
  session = [
    {
      mods = [ "Mod" ];
      key = "Return";
      spawn = [ "foot" ];
      desc = "Terminal (foot)";
      group = "Launch";
    }
    {
      mods = [ "Mod" ];
      key = "D";
      spawn = [ "fuzzel" ];
      desc = "Application launcher (fuzzel)";
      group = "Launch";
    }
    {
      mods = [ "Mod" ];
      key = "E";
      spawn = [ "dolphin" ];
      desc = "File manager (dolphin)";
      group = "Launch";
    }
    {
      # The notes profile's launcher, from myConfig.emacsFrameArgv — the same
      # command as $EDITOR and as the menu entry. It starts that profile's
      # daemon if needed, so a cold session gets a working frame.
      mods = [
        "Mod"
        "Shift"
      ];
      key = "E";
      spawn = myConfig.emacsFrameArgv;
      desc = "Emacs frame";
      group = "Launch";
    }
    {
      mods = [ "Mod" ];
      key = "N";
      spawn = [ "nm-connection-editor" ];
      desc = "Network settings";
      group = "Launch";
    }
    {
      # fsearch was cut with the duplicate search tools (P2, 2026-11-18), so
      # this is `fd` under fuzzel: a live search over names, in the launcher
      # the session already has. Mod+Space is kept because that is the key.
      mods = [ "Mod" ];
      key = "Space";
      spawn = [
        "bash"
        "-c"
        "fd --hidden --exclude .git . \"$HOME\" | fuzzel -d -p 'Search: '"
      ];
      desc = "File search (fd)";
      group = "Launch";
    }

    {
      mods = [ "Mod" ];
      key = "T";
      spawn = [ "teleport" ];
      desc = "Jump to a window by name";
      group = "Session";
    }
    {
      mods = [
        "Mod"
        "Alt"
      ];
      key = "S";
      spawn = [ "spotlight" ];
      desc = "Spotlight - float and centre the focused window";
      group = "Session";
    }
    {
      mods = [ "Mod" ];
      key = "V";
      spawn = [
        "bash"
        "-c"
        cliphistPick
      ];
      desc = "Clipboard history";
      group = "Session";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Q";
      spawn = [ "wlogout" ];
      desc = "Session menu - lock, logout, suspend, reboot";
      group = "Session";
    }
    {
      # The generated guide is a file in ~/.config that you would otherwise have
      # no way to find. Same key in both sessions, and the guide covers both.
      mods = [
        "Mod"
        "Shift"
      ];
      key = "Slash";
      # Same launcher as Mod+Shift+E above, with the guide as its argument.
      spawn = myConfig.emacsFrameArgv ++ [ guidePath ];
      desc = "Open this guide";
      group = "Help";
    }
    {
      # The other half of the same file: `keys.org` is a document you read,
      # this is a filter you type into. Both are rendered from the lists in
      # this module — see the note on `keys-guide` at the bottom.
      #
      # F1 rather than a second spelling of the same chord: Super+Slash is
      # already the org guide, and F1 is the help key everywhere else.
      mods = [ "Mod" ];
      key = "F1";
      spawn = [ "keys-guide" ];
      desc = "All keybindings (searchable list)";
      group = "Help";
    }

    {
      mods = [ "Mod" ];
      key = "grave";
      spawn = [ "toggle-scratchpad-terminal" ];
      desc = "Scratchpad terminal";
      group = "Scratchpad";
    }
    {
      mods = [
        "Mod"
        "Shift"
      ];
      key = "grave";
      spawn = [ "toggle-scratchpad-emacs" ];
      desc = "Scratchpad Emacs frame";
      group = "Scratchpad";
    }

    {
      mods = [ ];
      key = "Print";
      spawn = [ "screenshot-edit" ];
      desc = "Screenshot a region, then annotate";
      group = "Hardware";
    }
    {
      mods = [ ];
      key = "XF86AudioRaiseVolume";
      spawn = [
        "volctl"
        "up"
      ];
      desc = "Volume up";
      group = "Hardware";
    }
    {
      mods = [ ];
      key = "XF86AudioLowerVolume";
      spawn = [
        "volctl"
        "down"
      ];
      desc = "Volume down";
      group = "Hardware";
    }
    {
      mods = [ ];
      key = "XF86AudioMute";
      spawn = [
        "volctl"
        "mute"
      ];
      desc = "Toggle mute";
      group = "Hardware";
    }
    {
      mods = [ ];
      key = "XF86MonBrightnessUp";
      spawn = [
        "volctl"
        "br-up"
      ];
      desc = "Brightness up";
      group = "Hardware";
    }
    {
      mods = [ ];
      key = "XF86MonBrightnessDown";
      spawn = [
        "volctl"
        "br-down"
      ];
      desc = "Brightness down";
      group = "Hardware";
    }
  ];

  # ── The shared startup list ──────────────────────────────────────────────
  # Every one of these is installed by ./wayland-common.nix or ./lock.nix, so
  # neither compositor can start something the other lacks. They were two lists
  # before, and they had already diverged on the swww race and on whether
  # nm-applet gets --indicator.
  startup = [
    {
      # The two-second waits came from the niri side. A tray icon that starts
      # before the tray exists does not appear, and waybar is the tray.
      name = "waybar";
      argv = [
        "bash"
        "-c"
        "sleep 2 && waybar"
      ];
      desc = "Status bar";
    }
    {
      name = "mako";
      argv = [ "mako" ];
      desc = "Notification daemon";
    }
    {
      name = "hypridle";
      argv = [ "hypridle" ];
      desc = "Idle daemon - dim at 5 min, lock at 7, panel off at 10";
    }
    {
      name = "awww";
      argv = [
        "bash"
        "-c"
        awwwStart
      ];
      desc = "Wallpaper daemon, then the wallpaper";
    }
    {
      name = "nm-applet";
      argv = [
        "bash"
        "-c"
        "sleep 2 && nm-applet --indicator"
      ];
      desc = "Network tray icon";
    }
    {
      name = "udiskie";
      argv = [
        "udiskie"
        "--tray"
      ];
      desc = "Removable-disk automount tray icon";
    }
    {
      name = "polkit-gnome";
      argv = [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ];
      desc = "Authentication agent for privileged prompts";
    }
    {
      name = "cliphist";
      argv = [
        "bash"
        "-c"
        cliphistWatch
      ];
      desc = "Clipboard history watcher";
    }
  ];

  # ── Keyboard input, stated once ──────────────────────────────────────────
  # Both cheat-sheets used to say Caps Lock switches to Hebrew. It never did in
  # any config this repo has shipped. The Hebrew toggle is both Shift keys —
  # hold either, tap the other — and Caps Lock is now simply Caps Lock.
  #
  # The layout and options come from myConfig because this module is not the
  # only consumer, and it turned out not to be the only *two*:
  #
  #   modules/system/desktop.nix  → services.xserver.xkb  (the X server)
  #   ../../home/shaul.nix        → programs.plasma.input.keyboard  (KWin)
  #   this file                   → hyprland.conf, the sway config, the guide
  #
  # A home-manager module and a NixOS module cannot read each other, so the
  # statement lives in myConfig. Before that it was written out separately in
  # this file and in desktop.nix — i.e. the module that exists *because* the
  # keymap had five hand-written copies was quietly carrying a sixth — and
  # Plasma, the default session, had no statement at all.
  #
  # The repeat rates stay here: they are the same three consumers, and this is
  # the module all three already read.
  keyboard = myConfig.keyboard // {
    repeatDelay = 250;
    repeatRate = 40;
  };

  # ── The guide ────────────────────────────────────────────────────────────
  # `lib.stringLength` counts BYTES, so a `desc` containing an em dash or an
  # arrow pads two columns short and the table comes out ragged. Keep table
  # cells — every `desc`, and both column headers — ASCII. Prose is free to use
  # whatever it likes; only the cells go through `pad`.
  pad = n: s: s + lib.concatStrings (lib.genList (_: " ") (n - lib.stringLength s));
  dashes = n: lib.concatStrings (lib.genList (_: "-") n);

  mkTable =
    header: rows:
    let
      all = [ header ] ++ rows;
      width =
        i:
        lib.foldl' (
          m: r:
          let
            l = lib.stringLength (lib.elemAt r i);
          in
          if l > m then l else m
        ) 0 all;
      w0 = width 0;
      w1 = width 1;
      line = r: "  | ${pad w0 (lib.elemAt r 0)} | ${pad w1 (lib.elemAt r 1)} |";
      rule = "  |-${dashes w0}-+-${dashes w1}-|";
    in
    concatStringsSep "\n" (
      [
        (line header)
        rule
      ]
      ++ map line rows
    );

  bindTables =
    binds:
    let
      groups = lib.unique (map (b: b.group) binds);
      table =
        g:
        mkTable [ "Key" "Action" ] (
          map (b: [
            (guideChord b)
            b.desc
          ]) (lib.filter (b: b.group == g) binds)
        );
    in
    concatMapStringsSep "\n\n" (g: "*** ${g}\n${table g}") groups;

  compositors = lib.sort (a: b: a.order < b.order) (lib.attrValues config.shaulos.compositors);

  # The guide's keyboard rows used to be two sentences somebody typed: "Ctrl+Alt
  # (NOT Caps Lock, whatever the old guide said)" and "Acts as Escape". Both
  # happened to be true, and both were exactly the thing this file exists to
  # stop — a restatement of `keyboard.options` sitting next to it, free to rot
  # the moment the option changes. It changed.
  #
  # So the rows are generated from the option string, and the only human writing
  # left is this table of glosses. An option with no entry prints its own name
  # rather than a neighbour's sentence: a guide that says "grp:foo_toggle" is
  # merely unhelpful, and a guide that confidently says "Ctrl+Alt" while the
  # config says both Shifts is the failure mode with a body count.
  # A dictionary, not a list of what is set — `caps:escape` is not currently in
  # `myConfig.keyboard.options` and its gloss stays anyway, so turning it back
  # on is one string in one list rather than one string in two places.
  xkbOptionLabels = {
    "grp:shifts_toggle" = "Hebrew/English - hold either Shift, tap the other";
    "caps:escape" = "Caps Lock acts as Escape";
  };
  xkbRows = map (o: [
    o
    (xkbOptionLabels.${o} or "see xkeyboard-config(7)")
  ]) keyboard.options;

  # ── Keys that are not in either list ─────────────────────────────────────
  #
  # The two lists above are the repo's own binds, and they are generated. These
  # are the rest of what you can press, and where each row comes from decides
  # how honest it can be:
  #
  #   system  the machine. Ctrl+Alt+F1 is the kernel's VT switch and
  #           ctrl-alt-del.target is systemd's, both true of any NixOS box with
  #           a getty. Listed because they are true of this one, not derived
  #           from anything — nothing in the tree could tell this file what
  #           they are.
  #   apps    the applications' own defaults. These are NOT generated: Emacs,
  #           yazi and fuzzel own their keymaps, and any of them can change
  #           upstream. They are written down once, behind a header that says
  #           so, which is the most a cheat-sheet can honestly do about a key
  #           it does not own. The alternative — leaving them out — is what
  #           made the first version of this list incomplete.
  #
  # What is deliberately NOT here: the mouse. Neither config declares a mouse
  # chord (`bindm` in Hyprland, `floating_modifier` in sway), so there is no
  # "Mod+drag resizes" row to write — and inventing one is how a cheat-sheet
  # starts lying. The absence is stated below, from the same fact.
  systemKeys = [
    [
      "Ctrl+Alt+F1..F12"
      "Switch virtual terminal (F1 is the graphical session)"
    ]
    [
      "Ctrl+Alt+Delete"
      "Reboot (systemd's ctrl-alt-del.target)"
    ]
  ];

  appKeys = [
    [
      "Emacs C-x C-f"
      "Find file"
    ]
    [
      "Emacs C-x C-s"
      "Save buffer"
    ]
    [
      "Emacs C-x C-c"
      "Close this frame (the daemon keeps running)"
    ]
    [
      "Emacs M-x"
      "Run a command by name"
    ]
    [
      "Emacs C-g"
      "Cancel the minibuffer"
    ]
    [
      "foot Ctrl+Shift+C / V"
      "Copy / paste"
    ]
    [
      "foot Ctrl+plus / minus"
      "Zoom in / out"
    ]
    [
      "fuzzel"
      "Type to filter, Enter to pick, Esc to dismiss"
    ]
    [
      "yazi q / o / Space"
      "Quit / open / select"
    ]
    [
      "yazi / / . / O"
      "Search / toggle hidden / open-with"
    ]
  ];

  # `intro` is a list of lines rather than a blob so the generated org indents
  # the same way every time regardless of how the caller wrote it.
  introBlock = lines: concatMapStringsSep "\n" (l: if l == "" then "" else "   ${l}") lines;

  compositorSection = c: ''
    ** ${c.title}

    ${introBlock c.intro}

    ${bindTables c.binds}
  '';

  guide = ''
    #+TITLE: ShaulOS session keys
    #+OPTIONS: toc:2 num:nil
    #+STARTUP: showall

    * About this file

      Generated by =modules/home/keys.nix= from the same lists that write
      =hypr/hyprland.conf= and the sway config. Do not edit it — the next
      =just switch= overwrites it, and that is the feature. There used to be a
      hand-written cheat-sheet beside each compositor config, and by the time
      anyone read them again both were wrong about which keys existed.

      Open it from either session with =Super+Shift+/=, or press =Super+F1=
      for the same keys as a searchable list (type to filter, Esc to close).
      =Super+F1= also works under Plasma, which has no keymap file of its own.

      Facts that this file does not *derive* are not stated here. Gaps, opacity,
      animation curves and window rules are still literals inside each
      compositor's config text, so they are documented where they live and
      nowhere else. A second copy is how the last cheat-sheet started.

    * Keyboard

    ${mkTable [ "Setting" "Value" ] (
      [
        [
          "Layouts"
          "${keyboard.layout} - US English first, then Hebrew"
        ]
      ]
      ++ xkbRows
      ++ [
        [
          "Repeat delay"
          "${toString keyboard.repeatDelay} ms"
        ]
        [
          "Repeat rate"
          "${toString keyboard.repeatRate} per second"
        ]
      ]
    )}

      Every row above the repeat rates is generated from the xkb strings in
      =myConfig.keyboard= (=flake.nix=), which is also what
      =modules/system/desktop.nix= gives to the X server. The old guide said
      Caps Lock switched to Hebrew, which had never been true in any config
      this repo has shipped.

    * Colours

      Derived from =stylix.base16Scheme= in =modules/system/appearance.nix= by
      =modules/home/palette.nix=. Change the scheme there and this table, both
      compositors' borders, the bar and the lock screen all move together.

    ${mkTable
      [ "Role" "Value" ]
      [
        [
          "Background"
          css.bg
        ]
        [
          "Foreground"
          css.fg
        ]
        [
          "Accent (focused border)"
          css.accent
        ]
        [
          "Dim (unfocused border)"
          css.dim
        ]
      ]
    }

    * Autostart

      Started by both sessions, from one list.

    ${mkTable [ "Program" "Purpose" ] (
      map (s: [
        s.name
        s.desc
      ]) startup
    )}

    * Keys
    ** Shared — the same in every session

      These launch programs that =modules/home/wayland-common.nix= and
      =modules/home/scripts.nix= install for every session, so the key does not
      depend on which compositor started. Under Plasma the compositor-specific
      scripts say so and exit rather than doing nothing quietly.

    ${bindTables session}

    ${concatMapStringsSep "\n" compositorSection compositors}

    * Machine keys

      Not generated from anything in this repository. These are the kernel's
      and systemd's: =Ctrl+Alt+F1= is the VT switch a getty listens on, and
      =ctrl-alt-del.target= is what =Ctrl+Alt+Delete= starts. They are listed
      because they are true here, not because anything in the tree says so.

    ${mkTable [ "Key" "Action" ] systemKeys}

    * Application keys

      The applications' own defaults, written down in one place instead of
      none. Emacs, foot, fuzzel and yazi own these bindings; unlike the two
      sections above, no list in this repository generates them. A row here can
      therefore be wrong after an upstream release — and it is wrong in one
      visible place, which is the improvement over a per-config cheat-sheet.

    ${mkTable [ "Key" "Action" ] appKeys}

    * Mouse

      There is no mouse chord to document: neither compositor config declares
      =bindm= (Hyprland) or =floating_modifier= (sway), so dragging and
      resizing are keyboard verbs here. They are in the tables above.
  '';

  # ── The searchable list ──────────────────────────────────────────────────
  #
  # The org file above is a document. This is the same data as a filter:
  # `fuzzel -d` reads lines on stdin, so the list is flat, one bind per line,
  # and typing "workspace" narrows it. Both come off `session`,
  # `config.shaulos.compositors` and the two literal tables — one source, two
  # renderings, which is the whole property this module is built for.
  #
  # The compositor is chosen at runtime from the environment variable the
  # compositor itself exports, the same test modules/home/scripts.nix makes
  # and for the same reason: one closure serves three sessions, so the answer
  # does not exist at build time.
  bindsOf = name: (config.shaulos.compositors.${name} or { binds = [ ]; }).binds;

  pairLine = r: "${lib.elemAt r 0}  —  ${lib.elemAt r 1}";

  bindRows =
    binds:
    map (b: [
      (guideChord b)
      b.desc
    ]) binds;

  listText =
    title: binds: withShared:
    let
      head = [
        "ShaulOS keys — ${title}"
        ""
      ];
      # Plasma has no keymap file, so the shared list would be a list of keys
      # that do nothing there. The one chord it does have — the KDE global
      # shortcut in ../../home/shaul.nix — is named instead.
      shared =
        if withShared then
          [ "-- shared: both tiling sessions --" ] ++ map pairLine (bindRows session)
        else
          [
            "Super+F1  —  All keybindings (this list)"
            ""
            "-- every other Super+ chord is Hyprland/sway only --"
          ];
      comp =
        if binds == null then
          [ ]
        else
          [
            ""
            "-- ${title} only --"
          ]
          ++ map pairLine (bindRows binds);
    in
    concatStringsSep "\n" (
      head
      ++ shared
      ++ comp
      ++ [
        ""
        "-- machine --"
      ]
      ++ map pairLine systemKeys
      ++ [
        ""
        "-- applications: their defaults, not generated here --"
      ]
      ++ map pairLine appKeys
    )
    + "\n";

  hyprList = pkgs.writeText "keys-hyprland.txt" (listText "Hyprland" (bindsOf "hyprland") true);
  swayList = pkgs.writeText "keys-sway.txt" (listText "Sway" (bindsOf "sway") true);
  plasmaList = pkgs.writeText "keys-plasma.txt" (listText "Plasma" null false);

  keysGuide = pkgs.writeShellScriptBin "keys-guide" ''
    if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      list=${hyprList}
    elif [ -n "''${SWAYSOCK:-}" ]; then
      list=${swayList}
    else
      list=${plasmaList}
    fi
    exec ${pkgs.fuzzel}/bin/fuzzel -d --prompt "Keys: " < "$list"
  '';
in
{
  imports = [ ./palette.nix ];

  options.shaulos.keys = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = ''
      The session keymap and startup list, plus the renderers that spell them
      for each compositor.

      `session`  — the shared binds. Both compositor modules render this list;
                   neither may add to it or restate a chord from it.
      `startup`  — the shared autostart list, same rule.
      `keyboard` — xkb layout, options and repeat, for both configs.
      `hypr` / `sway` — `{ binds, startup }` renderers taking a bind list and
                   returning config text already indented for the call site.
      `guidePackage` — the `keys-guide` command: this keymap rendered as a
                   searchable fuzzel list. Bound to Super+F1 in both
                   compositors, and registered as a KDE shortcut in
                   ../../home/shaul.nix.

      Read these; never hand-write a chord in a consuming module, and never
      write a cheat-sheet by hand. Both halves of that rule have been broken
      before, and the cheat-sheet half is the one that broke without a trace.
    '';
  };

  options.shaulos.compositors = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = ''
      Each compositor module registers itself here with
      `{ title, order, intro, binds }`, where `binds` is its own window-
      management verbs — the ones that genuinely differ between a scrolling
      column layout and a tiling one. The generated guide is built from this
      plus the shared list, which is the only reason it cannot go stale.
    '';
  };

  config = {
    shaulos.keys = {
      inherit session startup keyboard;
      guidePackage = keysGuide;
      hypr = {
        binds = renderHypr;
        startup = renderHyprStartup;
      };
      sway = {
        binds = renderSway;
        startup = renderSwayStartup;
      };
    };

    xdg.configFile."shaulos/keys.org".text = guide;

    # On $PATH because `spawn = [ "keys-guide" ]` above names it, and because
    # the Plasma shortcut in ../../home/shaul.nix interpolates the same store
    # path rather than reaching into this module's internals.
    home.packages = [ keysGuide ];
  };
}
