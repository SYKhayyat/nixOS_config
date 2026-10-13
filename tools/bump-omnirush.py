#!/usr/bin/env python3
"""tools/bump-omnirush.py — move both OmniRush pins to a new upstream release.

OmniRush ships two products that version independently:

    packages/omnirush.nix       the CLI, npm `omnirush` + `@omnirush-ai/cli-linux-x64`
    packages/omnirush-gui.nix   the Electron app, GitHub releases, .deb

Both are local packages pinned by a version, a URL and an SRI hash, so both
need three edits per bump. That is the whole reason this file exists.

Neither hash has to be computed. npm's `dist.integrity` for a version IS the
sha512 Nix will verify against, and the GUI release publishes a SHA256SUMS.txt
for exactly this purpose. So a bump reads metadata and rewrites three lines —
it never downloads a 176 MB .deb or a 79 MB bun to learn a 32-byte digest.

Verified against the tree: for `omnirush@2.3.11` and
`@omnirush-ai/cli-linux-x64@2.3.11`, npm returns byte-identical strings to the
`hash =` lines already in omnirush.nix.

    python3 tools/bump-omnirush.py --check     # what would move, no writes
    python3 tools/bump-omnirush.py             # bump both to latest
    python3 tools/bump-omnirush.py --version 3.4.0
    python3 tools/bump-omnirush.py --only cli

This is also what `nrs`, `nrt`, `just switch`, `just test` and `just build` run
before they rebuild, which is how "always on the latest release" is expressed
without an impure flake: a pure flake cannot name a moving target at eval time,
so the rebuild command moves the pin instead. Nothing here is required for that
to work — the aliases call it directly — but it is why a bump that fails has to
warn rather than abort (see the justfile).

`--version` pins an explicit release for both, which is the escape hatch when
`latest` points at something broken or a release has been yanked. The GUI reads
its tag off the same number, so `--version 3.4.0` means app 3.4.0 and CLI 3.4.0
if that CLI exists — the two lines only coincide when you ask them to.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GUI_NIX = REPO / "packages" / "omnirush-gui.nix"
CLI_NIX = REPO / "packages" / "omnirush.nix"

GUI_RELEASES = "https://api.github.com/repos/omnirush-ai/omnirush-gui/releases"
NPM = "https://registry.npmjs.org"
TIMEOUT = 30


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return json.load(response)


def fetch_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=TIMEOUT) as response:
        return response.read().decode("utf-8", "replace")


def sri_from_hex(hex_digest: str) -> str:
    """SHA256SUMS.txt gives hex; Nix wants base64 of the same 32 bytes."""
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_digest.strip())).decode()


def read(path: Path) -> str:
    return path.read_text()


def sub_once(pattern: str, replacement: str, text: str, what: str, path: Path) -> str:
    """Replace exactly one match or stop.

    A bump script that silently rewrites zero or two matches is worse than one
    that fails, because the failure surfaces at build time as a hash mismatch
    with nothing pointing back here.
    """
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(
            f"{path.name}: expected exactly one {what}, matched {count}. "
            f"The file's shape changed; update this script."
        )
    return updated


# ── GUI ──────────────────────────────────────────────────────────────────────

def gui_current(text: str) -> str:
    match = re.search(r'^[ \t]*version = "([^"]+)";', text, re.MULTILINE)
    if not match:
        raise SystemExit("omnirush-gui.nix: no `version =` line")
    return match.group(1)


def gui_latest() -> str:
    """Newest final release whose tag is a bare vX.Y.Z.

    The releases list also carries `box-*` tags for a different product; a
    naive [0] picks those up.
    """
    for release in fetch_json(f"{GUI_RELEASES}?per_page=30"):
        tag = release.get("tag_name", "")
        if release.get("prerelease") or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
            continue
        return tag[1:]
    raise SystemExit("no vX.Y.Z release found")


def gui_asset_name(text: str, version: str) -> str:
    """Reuse the asset the file already pins.

    Keeps the arch choice in the .nix file, where it belongs, instead of
    hardcoding amd64 here.
    """
    match = re.search(r"download/v[\d.]+/([\w.\-]+\.deb)", text)
    if not match:
        raise SystemExit("omnirush-gui.nix: could not find the .deb asset name in the url")
    return match.group(1).replace(re.search(r"[\d.]+(?=\.deb$)", match.group(1)).group(0), version)


def bump_gui(version: str, check_only: bool) -> tuple[str, str]:
    text = read(GUI_NIX)
    current = gui_current(text)
    asset = gui_asset_name(text, version)

    sums = fetch_text(
        f"https://github.com/omnirush-ai/omnirush-gui/releases/download/v{version}/SHA256SUMS.txt"
    )
    digest = None
    for line in sums.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lstrip("*") == asset:
            digest = parts[0]
            break
    if not digest:
        raise SystemExit(
            f"SHA256SUMS.txt for v{version} has no line for {asset}. "
            f"Available: {' '.join(sorted(l.split()[1] for l in sums.splitlines() if len(l.split()) == 2))}"
        )
    sri = sri_from_hex(digest)

    if current == version:
        # Still re-verify the hash: same version, republished asset is possible.
        match = re.search(r'hash = "([^"]+)";', text)
        if match and match.group(1) == sri:
            return current, f"{version} (already pinned, hash verified)"
    if check_only:
        return current, version

    url = f"https://github.com/omnirush-ai/omnirush-gui/releases/download/v{version}/{asset}"
    text = sub_once(r'^\s*version = "[^"]+";', f'  version = "{version}";', text, "version", GUI_NIX)
    text = sub_once(
        r'(download/v)[\d.]+/(omnirush-linux-amd64-)[\d.]+(\.deb")',
        rf"\g<1>{version}/\g<2>{version}\g<3>",
        text, "download url", GUI_NIX,
    )
    # The hex digest is kept in the comment above the hash; keep it honest.
    text = sub_once(
        r'^(    #   )[0-9a-f]{64}$',
        rf"\g<1>{digest}",
        text, "hex digest comment", GUI_NIX,
    )
    text = sub_once(r'^(\s*hash = ")[^"]+(";?)$', rf'\g<1>{sri}\g<2>', text, "hash", GUI_NIX)
    GUI_NIX.write_text(text)
    return current, version


# ── CLI ──────────────────────────────────────────────────────────────────────

def cli_current(text: str) -> str:
    match = re.search(r'^[ \t]*version = "([^"]+)";', text, re.MULTILINE)
    if not match:
        raise SystemExit("omnirush.nix: no `version =` line")
    return match.group(1)


def cli_latest() -> str:
    return fetch_json(f"{NPM}/omnirush/latest")["version"]


def bump_cli(version: str, check_only: bool) -> tuple[str, str]:
    text = read(CLI_NIX)
    current = cli_current(text)

    # The runtime package is optionalDependencies, not part of the omnirush
    # package's own integrity, and a release can land without it.
    packages = {
        "src": "omnirush",
        "runtime": "@omnirush-ai/cli-linux-x64",
    }
    digests: dict[str, str] = {}
    for label, package in packages.items():
        try:
            digests[label] = fetch_json(f"{NPM}/{package}/{version}")["dist"]["integrity"]
        except urllib.error.HTTPError as error:
            if error.code == 404:
                raise SystemExit(
                    f"{package}@{version} is not on npm. The CLI and its runtime "
                    f"package are published together; if this version is real, the "
                    f"runtime tarball is late or the version was pulled."
                )
            raise

    if check_only:
        return current, version

    text = sub_once(r'^\s*version = "[^"]+";', f'  version = "{version}";', text, "version", CLI_NIX)
    for label in ("src", "runtime"):
        text = sub_once(
            rf'(^[ \t]*{label} = fetchurl \{{\n(?:.*\n)*?    hash = ")[^"]+(")',
            rf'\g<1>{digests[label]}\g<2>',
            text, f"{label} hash", CLI_NIX,
        )
    CLI_NIX.write_text(text)
    return current, version


# ── main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="report what would move, write nothing")
    parser.add_argument("--version", help="pin an explicit release instead of latest")
    parser.add_argument("--only", choices=["gui", "cli"], help="bump just one of the two")
    args = parser.parse_args()

    want_gui = args.only in (None, "gui")
    want_cli = args.only in (None, "cli")
    changed = False

    try:
        if want_gui:
            target = args.version or gui_latest()
            current, moved = bump_gui(target, args.check)
            changed = changed or moved.partition(" ")[0] != current
            print(f"gui  {current} -> {moved}{'  (--check, not written)' if args.check else ''}")
        if want_cli:
            target = args.version or cli_latest()
            current, moved = bump_cli(target, args.check)
            changed = changed or moved.partition(" ")[0] != current
            print(f"cli  {current} -> {moved}{'  (--check, not written)' if args.check else ''}")
    except SystemExit as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except urllib.error.URLError as error:
        print(f"error: {error.reason}", file=sys.stderr)
        return 1

    # Only when something moved, and naming a recipe that exists. This script
    # runs at the front of every `nrs` / `just switch`, where "Rebuild and
    # switch" is what the caller is already doing, and `.#homeConfigurations`
    # is not an output this flake has — the hint used to send people to a
    # command that cannot resolve.
    if changed and not args.check:
        print("\nBumped. Rebuild and switch:")
        print("  just switch          # or: nrs")
    return 0


if __name__ == "__main__":
    sys.exit(main())