# modules/system/file-sync.nix
#
# Syncs folders from Google Drive and GitHub on first boot (if not present)
#
# ════════════════════════════════════════════════════════════════════════════
# SETUP INSTRUCTIONS FOR NEW MACHINES
# ════════════════════════════════════════════════════════════════════════════
#
# 1. RCLONE CONFIGURATION (required for Google Drive sync)
#
#    Run this command as your user (not root):
#
#        rclone config
#
#    Then follow these steps:
#        a) Choose "n" for new remote
#        b) Name it exactly: unified
#        c) Choose "drive" (Google Drive)
#        d) Leave client_id and client_secret blank (press Enter)
#        e) Choose "1" for full access
#        f) Leave root_folder_id blank
#        g) Leave service_account_file blank
#        h) Choose "n" for advanced config
#        i) Choose "y" for auto config (browser will open)
#        j) Sign in to your Google account
#        k) Choose "n" for shared drive
#        l) Confirm with "y"
#        m) Choose "q" to quit
#
#    The config is saved to: ~/.config/rclone/rclone.conf
#
#    To verify it works:
#        rclone lsd unified:
#
#    You should see your Google Drive folders listed.
#
# 2. TO COPY CONFIG TO ANOTHER MACHINE
#
#    Option A: Run "rclone config" again on the new machine
#
#    Option B: Copy the config file:
#        scp ~/.config/rclone/rclone.conf newmachine:~/.config/rclone/
#
# 3. MANUAL SYNC (if needed)
#
#    To manually trigger the sync service:
#        sudo systemctl start file-sync.service
#
#    To check status:
#        sudo systemctl status file-sync.service
#
#    To view logs:
#        journalctl -u file-sync.service
#
# ════════════════════════════════════════════════════════════════════════════
# WHAT THIS SYNCS
# ════════════════════════════════════════════════════════════════════════════
#
#   Source                              Destination
#   ─────────────────────────────────────────────────────────────────────────
#   Google Drive: unified:a_written  →  ~/Documents/siach_shai/a_written
#   Google Drive: unified:seforim    →  ~/Documents/seforim
#   GitHub: SYKhayyat/typed_notes    →  ~/Documents/siach_shai/b_typed
#
#   Each folder is only downloaded if it does NOT already exist.
#   If the folder exists, it is skipped entirely (no updates, no overwrites).
#
# ════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, myConfig, ... }:

let
  homeDir = myConfig.homeDir;
  username = myConfig.username;
in
{
  # ══════════════════════════════════════════════════════════════════════════
  # PACKAGES
  # ══════════════════════════════════════════════════════════════════════════

  environment.systemPackages = with pkgs; [
    rclone
    git
  ];

  # ══════════════════════════════════════════════════════════════════════════
  # FILE SYNC SERVICE
  # ══════════════════════════════════════════════════════════════════════════

  systemd.services.file-sync = {
    description = "Sync files from Google Drive and GitHub if not present";
    after = [ "network-online.target" "nss-lookup.target" ];
    wants = [ "network-online.target" "nss-lookup.target" ];
    wantedBy = [ "multi-user.target" ];

    # Retry if network isn't ready
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "users";
      RemainAfterExit = true;

      # Explicit home directory
      Environment = [
        "HOME=${homeDir}"
        "PATH=${lib.makeBinPath [ pkgs.rclone pkgs.git pkgs.coreutils ]}"
      ];

      # Retry up to 3 times with 30 second delay
      Restart = "on-failure";
      RestartSec = "30";
      StartLimitBurst = 3;

      ExecStart = let
        syncScript = pkgs.writeShellScript "file-sync" ''
          set -uo pipefail

          # ────────────────────────────────────────────────────────────────
          # Configuration
          # ────────────────────────────────────────────────────────────────

          HOME_DIR="${homeDir}"
          RCLONE_CONFIG="$HOME_DIR/.config/rclone/rclone.conf"
          RCLONE_REMOTE="unified"

          GDRIVE_SYNC_NEEDED=false
          GITHUB_SYNC_NEEDED=false
          ERRORS=0

          # ────────────────────────────────────────────────────────────────
          # Determine what needs syncing
          # ────────────────────────────────────────────────────────────────

          if [ ! -d "$HOME_DIR/Documents/siach_shai/a_written" ] || \
             [ ! -d "$HOME_DIR/Documents/seforim" ]; then
            GDRIVE_SYNC_NEEDED=true
          fi

          if [ ! -d "$HOME_DIR/Documents/siach_shai/b_typed" ]; then
            GITHUB_SYNC_NEEDED=true
          fi

          # Exit early if nothing to do
          if [ "$GDRIVE_SYNC_NEEDED" = false ] && [ "$GITHUB_SYNC_NEEDED" = false ]; then
            echo "All folders already exist. Nothing to sync."
            exit 0
          fi

          echo "=== Starting file sync ==="
          echo ""

          # ────────────────────────────────────────────────────────────────
          # Create parent directories
          # ────────────────────────────────────────────────────────────────

          mkdir -p "$HOME_DIR/Documents/siach_shai"
          mkdir -p "$HOME_DIR/Documents"

          # ────────────────────────────────────────────────────────────────
          # Google Drive syncs
          # ────────────────────────────────────────────────────────────────

          if [ "$GDRIVE_SYNC_NEEDED" = true ]; then
            # Check rclone config
            if [ ! -f "$RCLONE_CONFIG" ]; then
              echo "WARNING: rclone config not found at $RCLONE_CONFIG"
              echo "Google Drive sync skipped. Run 'rclone config' to set up."
              echo "See comments in file-sync.nix for instructions."
              ERRORS=$((ERRORS + 1))
            else
              # Test rclone connectivity
              if ! ${pkgs.rclone}/bin/rclone lsd "$RCLONE_REMOTE:" --config "$RCLONE_CONFIG" > /dev/null 2>&1; then
                echo "WARNING: Cannot connect to Google Drive remote '$RCLONE_REMOTE'"
                echo "Google Drive sync skipped. Check your rclone configuration."
                ERRORS=$((ERRORS + 1))
              else
                # Sync 1: a_written
                if [ ! -d "$HOME_DIR/Documents/siach_shai/a_written" ]; then
                  echo "[GDrive 1/2] Downloading a_written..."
                  if ${pkgs.rclone}/bin/rclone copy \
                    "$RCLONE_REMOTE:a_written" \
                    "$HOME_DIR/Documents/siach_shai/a_written" \
                    --config "$RCLONE_CONFIG" \
                    --verbose \
                    --transfers 4; then
                    echo "[GDrive 1/2] a_written download complete."
                  else
                    echo "[GDrive 1/2] ERROR: a_written download failed."
                    ERRORS=$((ERRORS + 1))
                  fi
                else
                  echo "[GDrive 1/2] a_written already exists, skipping."
                fi

                echo ""

                # Sync 2: seforim
                if [ ! -d "$HOME_DIR/Documents/seforim" ]; then
                  echo "[GDrive 2/2] Downloading seforim..."
                  if ${pkgs.rclone}/bin/rclone copy \
                    "$RCLONE_REMOTE:seforim" \
                    "$HOME_DIR/Documents/seforim" \
                    --config "$RCLONE_CONFIG" \
                    --verbose \
                    --transfers 4; then
                    echo "[GDrive 2/2] seforim download complete."
                  else
                    echo "[GDrive 2/2] ERROR: seforim download failed."
                    ERRORS=$((ERRORS + 1))
                  fi
                else
                  echo "[GDrive 2/2] seforim already exists, skipping."
                fi
              fi
            fi
          else
            echo "[GDrive] All Google Drive folders exist, skipping."
          fi

          echo ""

          # ────────────────────────────────────────────────────────────────
          # GitHub sync
          # ────────────────────────────────────────────────────────────────

          if [ "$GITHUB_SYNC_NEEDED" = true ]; then
            if [ ! -d "$HOME_DIR/Documents/siach_shai/b_typed" ]; then
              echo "[GitHub] Cloning typed_notes..."
              
              # Test network connectivity to GitHub
              if ! ${pkgs.curl}/bin/curl -s --max-time 10 https://github.com > /dev/null 2>&1; then
                echo "[GitHub] ERROR: Cannot reach github.com"
                ERRORS=$((ERRORS + 1))
              else
                if ${pkgs.git}/bin/git clone \
                  --recursive \
                  "https://github.com/SYKhayyat/typed_notes.git" \
                  "$HOME_DIR/Documents/siach_shai/b_typed"; then
                  echo "[GitHub] typed_notes clone complete."
                else
                  echo "[GitHub] ERROR: Clone failed."
                  ERRORS=$((ERRORS + 1))
                fi
              fi
            else
              echo "[GitHub] b_typed already exists, skipping."
            fi
          else
            echo "[GitHub] GitHub folder exists, skipping."
          fi

          echo ""
          echo "=== File sync complete ==="

          if [ $ERRORS -gt 0 ]; then
            echo "WARNING: $ERRORS error(s) occurred. Check messages above."
            exit 1
          fi

          exit 0
        '';
      in "${syncScript}";
    };
  };
}
