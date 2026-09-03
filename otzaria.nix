# Otzaria — a modern, open-source Jewish library desktop app.
#
# This module:
#   * installs the Otzaria application package, and
#   * provisions the full book library (SeforimLibrary) declaratively on
#     first login, into the exact data directory the app looks in, so the
#     whole book archive is available offline with no manual download.
{ config, lib, pkgs, ... }:

let
  otzaria = pkgs.callPackage ./otzaria/package.nix { };

  # The library snapshot is published on a dedicated repository, in lockstep
  # with the version the app itself polls from GitHub as "latest". Bump all
  # three fields together when the SeforimLibrary release changes.
  library = {
    version = "v24-20260831120814";
    url = "https://github.com/Otzaria/SeforimLibrary/releases/download/v24-20260831120814/seforim.db.zst";
    sha256 = "7f18a7591d9ff0167c742adbf213ffe23a7c131a368098db8f0e62b4989bfe60";
  };

  # On a per-user Linux install the app's default library path is
  # $HOME/.local/share/otzaria/books/seforim.db (see lib/core/app_paths.dart).
  libraryDir = "/home/shaul/.local/share/otzaria/books";
in
{
  environment.systemPackages = [ otzaria ];

  # Provision the full library once, idempotently, in the user session.
  systemd.user.services.otzaria-library = {
    description = "Otzaria: download and install the full book library";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ coreutils curl zstd ];
    script = ''
      set -euo pipefail
      version="${library.version}"
      url="${library.url}"
      sha256="${library.sha256}"
      dest="${libraryDir}"
      marker="$dest/.library-version"

      # Idempotent: nothing to do if this exact library version is installed.
      if [ -f "$marker" ] && [ "$(cat "$marker")" = "$version" ]; then
        exit 0
      fi

      echo "Otzaria: downloading the full library ($version) ..."
      work="$(mktemp -d)"
      trap 'rm -rf "$work"' EXIT
      archive="$work/seforim.db.zst"

      curl -fL --retry 3 -o "$archive" "$url"
      echo "$sha256  $archive" | sha256sum -c -   # abort on checksum mismatch
      zstd -q -d -f "$archive" -o "$work/seforim.db"

      # Stage the library in a sibling dir, then swap it in atomically.
      mkdir -p "$work/books"
      mv "$work/seforim.db" "$work/books/seforim.db"
      mkdir -p "$(dirname "$dest")"
      rm -rf "$dest"
      mv "$work/books" "$dest"
      chmod -R u+rwX "$dest"
      printf '%s' "$version" > "$marker"

      echo "Otzaria: library installed at $dest/seforim.db"
    '';
  };
}