# modules/system/data.nix
#
# How this machine's *data* gets here. One module, because the question had
# been answered three times and none of the answers worked.
#
# What was here before:
#
#   * `services.onedrive.enable = true` in services.nix — abraunegg's sync
#     daemon. Nothing in this repo has ever given it credentials.
#   * the `onedriver` package in home/shaul.nix — a *different project* that
#     FUSE-mounts the same OneDrive account. No service, no config, no mention
#     in the README, untouched since the initial import. Zero call sites.
#   * `file-sync.nix` — 268 lines, of which ~180 were a hand-rolled shell
#     script and 68 were a setup manual living in comments.
#
# `onedriver` is gone: two clients for one remote is one client. The rest is
# below, and the interesting part is why the third one never worked.
#
# ── The bug ──────────────────────────────────────────────────────────────
#
# `file-sync` decided whether to fetch by asking `[ ! -d "$dst" ]`. But
# modules/home/emacs/default.nix runs
#
#     mkdir -p "${seforimPath}/Bavli"
#
# in its home-manager activation — i.e. on every `just switch`, including the
# one that installs the machine, which runs before this unit ever gets a boot.
# So the directory always existed by the time the question was asked, the
# seforim library never downloaded, and the log said
#
#     [GDrive 2/2] seforim already exists, skipping.
#
# for the rest of the machine's life. That is recoll's `topdirs` and the whole
# subject of the Emacs seforim system, silently absent, reported as success.
#
# "Does the directory exist" is not the same question as "is my data here",
# and in a closure where another module scaffolds directories it is not even
# close. The predicate below asks about *files*.
#
# ── The other bug: this was never a service ──────────────────────────────
#
# Its own header said "Each folder is only downloaded if it does NOT already
# exist. If the folder exists, it is skipped entirely (no updates, no
# overwrites)." That is a bootstrap, not a sync — and it was wired as
# `wantedBy = multi-user.target` with `after = network-online.target`. A
# `Type=oneshot` unit wanted by multi-user.target is one the target waits for,
# so *every* boot for the life of the machine waited on
# NetworkManager-wait-online in order to run three `[ -d ]` tests and exit.
# That is the ~90s stall study-offline.nix credits itself with fixing; it was
# never fixed, it was only absent from the airgap closure.
#
# A timer with `OnBootSec` costs the boot path nothing, and the service's own
# `After=network-online.target` still makes it wait for the network — it just
# waits somewhere nobody is standing behind it.
#
# ── And it failed on the one machine it exists for ───────────────────────
#
# A missing rclone.conf was counted as an error and exited 1, with
# `Restart=on-failure`. On a fresh install — the only time this unit has work
# to do — it retried three times over 90s and parked in `failed` forever.
# "You have not set rclone up yet" and "the transfer broke" are different
# events; they no longer share an exit code. There is no `Restart=` at all now:
# if a bootstrap fails, the answer is to run it again when the reason is gone,
# and that is a command (`just bootstrap-data`), not a systemd policy.
{
  lib,
  pkgs,
  myConfig,
  ...
}:

let
  inherit (myConfig) homeDir username seforimPath;

  # seforimPath comes from myConfig because modules/home/emacs/default.nix
  # reads it too — it is recoll's `topdirs`, and the two disagreeing silently
  # is precisely the class of failure this module was built out of. The
  # siach_shai paths stay local: one consumer, one definition.
  notesDir = "${homeDir}/Documents/siach_shai";

  bootstrap = pkgs.writeShellScript "shaulos-data-bootstrap" ''
    set -uo pipefail

    RCLONE_CONFIG="${homeDir}/.config/rclone/rclone.conf"
    RCLONE_REMOTE="unified"
    NOTES="${notesDir}"
    SEFORIM="${seforimPath}"

    errors=0

    # The predicate this module exists for. Asked about files, because an empty
    # directory is what other modules leave lying around (see the header).
    provisioned() {
      [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ]
    }

    want_gdrive=""
    provisioned "$NOTES/a_written" || want_gdrive="$want_gdrive a_written"
    provisioned "$SEFORIM"         || want_gdrive="$want_gdrive seforim"

    want_github=false
    provisioned "$NOTES/b_typed" || want_github=true

    if [ -z "$want_gdrive" ] && [ "$want_github" = false ]; then
      echo "data-bootstrap: everything is provisioned, nothing to do."
      exit 0
    fi

    mkdir -p "$NOTES"

    # ── Google Drive, via rclone ────────────────────────────────────────
    if [ -n "$want_gdrive" ]; then
      if [ ! -f "$RCLONE_CONFIG" ]; then
        # Not an error. This is the state a fresh machine is in, and treating
        # it as a failure is what used to leave the unit permanently red.
        echo "data-bootstrap: rclone is not configured ($RCLONE_CONFIG missing)."
        echo "data-bootstrap: skipping Google Drive — see 'First-boot setup' in README.md."
      elif ! rclone lsd "$RCLONE_REMOTE:" --config "$RCLONE_CONFIG" >/dev/null 2>&1; then
        echo "data-bootstrap: ERROR: remote '$RCLONE_REMOTE:' is configured but unreachable."
        errors=$((errors + 1))
      else
        for item in $want_gdrive; do
          case "$item" in
            a_written) dst="$NOTES/a_written" ;;
            seforim)   dst="$SEFORIM" ;;
            *)         continue ;;
          esac
          echo "data-bootstrap: copying $RCLONE_REMOTE:$item -> $dst"
          # `rclone copy` merges into an existing directory and never deletes,
          # so it needs no dance around the empty-dir case.
          if rclone copy "$RCLONE_REMOTE:$item" "$dst" \
               --config "$RCLONE_CONFIG" \
               --transfers 4 \
               --stats 30s --stats-one-line; then
            echo "data-bootstrap: $item done."
          else
            echo "data-bootstrap: ERROR: $item failed."
            errors=$((errors + 1))
          fi
        done
      fi
    fi

    # ── GitHub, via git ─────────────────────────────────────────────────
    if [ "$want_github" = true ]; then
      dst="$NOTES/b_typed"
      tmp="$dst.incoming"
      # `git clone` refuses a destination that exists and is not empty, and it
      # leaves a partial tree behind when it dies mid-transfer — which the
      # predicate above would then read as provisioned. Clone beside the
      # destination and swap, so the real path is either absent or complete.
      rm -rf "$tmp"
      echo "data-bootstrap: cloning typed_notes -> $dst"
      # The old version probed github.com with curl first. A failed clone is
      # the same information one step later, without the second failure mode.
      if git clone --recursive "https://github.com/SYKhayyat/typed_notes.git" "$tmp"; then
        rm -rf "$dst"
        mv "$tmp" "$dst"
        echo "data-bootstrap: typed_notes done."
      else
        rm -rf "$tmp"
        echo "data-bootstrap: ERROR: typed_notes clone failed."
        errors=$((errors + 1))
      fi
    fi

    if [ "$errors" -gt 0 ]; then
      echo "data-bootstrap: $errors item(s) failed. Re-run with: just bootstrap-data"
      exit 1
    fi

    echo "data-bootstrap: complete."
  '';
in
{
  # rclone only. `git` is already in cli-tools.nix's systemPackages, and this
  # module listing it again was how it looked like a dependency of the sync
  # rather than of the machine.
  environment.systemPackages = [ pkgs.rclone ];

  # ── OneDrive ────────────────────────────────────────────────────────────
  # The surviving client of the two. Note what `enable` does and does not do:
  # it installs the client and defines the per-user unit, but the sync only
  # runs for a user who has authenticated interactively (`onedrive` once, to
  # get a refresh token) and started their instance. Nothing in this repo does
  # either, so on a fresh machine this is a package until you set it up.
  #
  # It lives here rather than in services.nix because "how does my data get
  # here" is one question and this file is where it is answered.
  services.onedrive.enable = true;

  # ── First-boot provisioning ─────────────────────────────────────────────
  # NOT wanted by multi-user.target. See the header: a one-time job on the boot
  # path is a permanent tax for a job that is done. The timer below starts it
  # two minutes in, and `After=network-online.target` makes the *job* wait for
  # the network rather than making the boot wait for the job.
  systemd.services.shaulos-data-bootstrap = {
    description = "Provision ~/Documents from Google Drive and GitHub (one-time)";
    after = [
      "network-online.target"
      "nss-lookup.target"
    ];
    wants = [
      "network-online.target"
      "nss-lookup.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";

      Environment = [
        "HOME=${homeDir}"
        "PATH=${
          lib.makeBinPath [
            pkgs.rclone
            pkgs.git
            pkgs.coreutils
            pkgs.findutils
          ]
        }"
        # git needs a CA bundle and a unit with an explicit Environment= is not
        # a login shell. security.pki puts this here (installCACerts, default on).
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      ];

      # Deliberately no Restart=. See the header.
      ExecStart = "${bootstrap}";
    };
  };

  systemd.timers.shaulos-data-bootstrap = {
    description = "Run the data bootstrap shortly after boot, off the boot path";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      Unit = "shaulos-data-bootstrap.service";
    };
  };
}
