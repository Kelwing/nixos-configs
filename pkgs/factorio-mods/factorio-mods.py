#!/usr/bin/env python3
"""
Manage a TOML file of Factorio mods.

Entry format:
    [[mod]]
    name = "AutoDeconstruct"
    download_id = "69a0d19734a726c6c089b0ea"
    hash = "sha256:130nz4vykc00j5m3bmx83p82gl3c5kvahn15b7vj7q1nxflhxcj0"
    version = "1.0.12"

Requires: requests, tomlkit
Requires on PATH: nix-prefetch-url, nix-hash
Environment: FACTORIO_USERNAME, FACTORIO_TOKEN
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

import requests
import tomlkit
from tomlkit import TOMLDocument
from tomlkit.items import AoT, Table

API_BASE = "https://mods.factorio.com/api/mods"
DOWNLOAD_BASE = "https://mods.factorio.com"
HASH_PREFIX = "sha256:"


# ---------- version parsing ----------


def parse_version(v: str) -> tuple[int, ...]:
    """Parse a Factorio mod version like '1.0.12' into a tuple for comparison."""
    parts = []
    for part in v.split("."):
        m = re.match(r"(\d+)", part)
        parts.append(int(m.group(1)) if m else 0)
    return tuple(parts)


# ---------- credentials ----------


def get_credentials() -> tuple[str, str]:
    username = os.environ.get("FACTORIO_USERNAME")
    token = os.environ.get("FACTORIO_TOKEN")
    if not username or not token:
        sys.exit("Error: FACTORIO_USERNAME and FACTORIO_TOKEN must be set.")
    assert username is not None and token is not None
    return username, token


# ---------- factorio API ----------


@dataclass
class ReleaseInfo:
    name: str
    version: str
    download_url: str  # path, e.g. "/download/AutoDeconstruct/69a0..."
    download_id: str
    dependencies: list[str] = field(
        default_factory=list
    )  # required mod names (excludes base/builtins)

    @property
    def authenticated_url(self) -> str:
        username, token = get_credentials()
        return f"{DOWNLOAD_BASE}{self.download_url}?username={username}&token={token}"

    @property
    def store_name(self) -> str:
        """
        Store path name for nix-prefetch-url --name. Must not contain query
        string characters ('?', '&', '='), which the default naming would
        otherwise pull in from the authenticated URL.
        """
        return f"{self.name}_{self.version}.zip"


def fetch_latest_release(name: str) -> ReleaseInfo:
    """Query the mod portal API and return the latest release for `name`."""
    url = f"{API_BASE}/{name}/full"
    resp = requests.get(url, timeout=30)
    if resp.status_code == 404:
        sys.exit(f"Error: mod '{name}' not found on the Factorio Mod Portal.")
    resp.raise_for_status()
    data = resp.json()

    releases = data.get("releases") or []
    if not releases:
        sys.exit(f"Error: mod '{name}' has no releases.")

    latest = max(releases, key=lambda r: parse_version(r["version"]))
    download_url = latest["download_url"]
    download_id = urlparse(download_url).path.rstrip("/").rsplit("/", 1)[-1]
    return ReleaseInfo(
        name=name,
        version=latest["version"],
        download_url=download_url,
        download_id=download_id,
        dependencies=parse_dependencies(
            latest.get("info_json", {}).get("dependencies", [])
        ),
    )


# Built-in mods that ship with Factorio and should never be fetched.
BUILTIN_MODS = {"base", "elevated-rails", "quality", "space-age"}


def parse_dependencies(dep_strings: list[str]) -> list[str]:
    """
    Parse Factorio dependency strings and return names of required dependencies.

    Dependency format: "[prefix] mod-name [op version]"
    Prefixes:
      (none) — hard required
      ~      — required, no effect on load order
      ?      — optional
      (?)    — hidden optional
      !      — incompatible

    We only care about required deps (no prefix or ~).
    """
    required: list[str] = []
    for dep in dep_strings:
        dep = dep.strip()
        if not dep:
            continue
        # Skip optional, hidden-optional, and incompatible
        if dep.startswith("?") or dep.startswith("(?)") or dep.startswith("!"):
            continue
        # Strip the ~ prefix (still required)
        if dep.startswith("~"):
            dep = dep[1:].strip()
        # Extract just the mod name (before any version operator)
        mod_name = re.split(r"\s+[><=!]", dep)[0].strip()
        if mod_name and mod_name not in BUILTIN_MODS:
            required.append(mod_name)
    return required


# ---------- hashing ----------


def nix_hash_file(path: Path) -> str:
    """Compute sha256 in nix-base32 form. Matches `nix-prefetch-url` output."""
    result = subprocess.run(
        ["nix-hash", "--flat", "--base32", "--type", "sha256", str(path)],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def download_and_hash(release: ReleaseInfo) -> str:
    """Download the mod release to a temp file and return its nix-base32 sha256."""
    with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        with requests.get(
            release.authenticated_url, stream=True, allow_redirects=True, timeout=120
        ) as resp:
            resp.raise_for_status()
            with open(tmp_path, "wb") as f:
                for chunk in resp.iter_content(chunk_size=1 << 16):
                    f.write(chunk)
        return nix_hash_file(tmp_path)
    finally:
        tmp_path.unlink(missing_ok=True)


def nix_prefetch(release: ReleaseInfo, expected_hash: str | None = None) -> str:
    """
    Run nix-prefetch-url to add the mod to the nix store. Returns the sha256 in
    nix-base32. If expected_hash is supplied, nix-prefetch-url will short-circuit
    when the store already has a matching file.

    Uses --name to override the store path name; otherwise nix-prefetch-url
    would derive it from the last path component of the URL, which for our
    authenticated URLs includes the '?username=...&token=...' query string —
    and '?' and '&' are not valid in Nix store path names.
    """
    cmd = [
        "nix-prefetch-url",
        "--type",
        "sha256",
        "--name",
        release.store_name,
        release.authenticated_url,
    ]
    if expected_hash is not None:
        cmd.append(expected_hash)
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout.strip()


# ---------- TOML handling ----------


def load_toml(path: Path) -> TOMLDocument:
    if not path.exists():
        doc = tomlkit.document()
        doc["mod"] = tomlkit.aot()
        return doc
    with open(path, "r", encoding="utf-8") as f:
        return tomlkit.load(f)


def save_toml(doc: TOMLDocument, path: Path) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        tomlkit.dump(doc, f)
    tmp.replace(path)


def get_mods(doc: TOMLDocument) -> AoT:
    mods = doc.get("mod")
    if mods is None:
        aot = tomlkit.aot()
        doc["mod"] = aot
        return aot
    return mods


def find_mod_index(mods: AoT, name: str) -> int | None:
    for i, m in enumerate(mods):
        if m.get("name") == name:
            return i
    return None


def make_entry(name: str, release: ReleaseInfo, nix_hash: str) -> Table:
    t = tomlkit.table()
    t["name"] = name
    t["download_id"] = release.download_id
    t["hash"] = f"{HASH_PREFIX}{nix_hash}"
    t["version"] = release.version
    return t


# ---------- commands ----------


def add_mod_recursive(
    name: str, path: Path, doc: TOMLDocument, mods: AoT, seen: set[str]
) -> None:
    """Add a mod and its required dependencies recursively."""
    if name in seen:
        return
    seen.add(name)

    if find_mod_index(mods, name) is not None:
        print(f"  '{name}' already present, skipping.")
        return

    print(f"Fetching mod info for '{name}'...")
    release = fetch_latest_release(name)
    print(f"  latest version: {release.version} (download_id={release.download_id})")

    if release.dependencies:
        print(f"  required dependencies: {', '.join(release.dependencies)}")
        for dep in release.dependencies:
            add_mod_recursive(dep, path, doc, mods, seen)

    print(f"  [{name}] downloading and hashing...")
    nix_hash = download_and_hash(release)
    print(f"  hash: sha256:{nix_hash}")

    mods.append(make_entry(name, release, nix_hash))
    print(f"Added '{name}' {release.version}.")


def cmd_add(args: argparse.Namespace) -> None:
    path = Path(args.file)
    doc = load_toml(path)
    mods = get_mods(doc)

    if find_mod_index(mods, args.name) is not None:
        sys.exit(f"Error: mod '{args.name}' is already present in {path}.")

    seen: set[str] = {m.get("name") for m in mods}
    add_mod_recursive(args.name, path, doc, mods, seen)
    save_toml(doc, path)


def cmd_remove(args: argparse.Namespace) -> None:
    path = Path(args.file)
    doc = load_toml(path)
    mods = get_mods(doc)

    idx = find_mod_index(mods, args.name)
    if idx is None:
        sys.exit(f"Error: mod '{args.name}' not found in {path}.")

    assert idx is not None
    del mods[idx]
    save_toml(doc, path)
    print(f"Removed '{args.name}'.")


def cmd_update(args: argparse.Namespace) -> None:
    path = Path(args.file)
    doc = load_toml(path)
    mods = get_mods(doc)

    if len(mods) == 0:
        print("No mods to update.")
        return

    updated = 0
    unchanged = 0
    errors: list[str] = []

    for i, entry in enumerate(mods):
        name = entry.get("name")
        current_version = entry.get("version", "0.0.0")
        print(f"[{name}] current {current_version}")
        try:
            release = fetch_latest_release(name)
        except SystemExit as e:
            errors.append(f"{name}: {e}")
            continue
        except requests.RequestException as e:
            errors.append(f"{name}: {e}")
            continue

        if parse_version(release.version) <= parse_version(current_version):
            print(f"  up to date ({release.version})")
            unchanged += 1
            continue

        print(f"  updating to {release.version}...")
        try:
            nix_hash = download_and_hash(release)
        except requests.RequestException as e:
            errors.append(f"{name}: download failed: {e}")
            continue
        except subprocess.CalledProcessError as e:
            errors.append(f"{name}: hashing failed: {e.stderr}")
            continue

        mods[i] = make_entry(name, release, nix_hash)
        updated += 1
        print(f"  updated -> {release.version} (sha256:{nix_hash})")

    save_toml(doc, path)
    print(f"\n{updated} updated, {unchanged} unchanged, {len(errors)} errors.")
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)


def cmd_validate(args: argparse.Namespace) -> None:
    """Re-download each mod and verify the hash in the TOML matches."""
    path = Path(args.file)
    doc = load_toml(path)
    mods = get_mods(doc)

    if len(mods) == 0:
        print("No mods to validate.")
        return

    ok = 0
    failures: list[str] = []

    for entry in mods:
        name = entry["name"]
        version = entry["version"]
        download_id = entry["download_id"]
        expected = entry["hash"]
        if not expected.startswith(HASH_PREFIX):
            failures.append(f"{name}: hash field missing 'sha256:' prefix")
            continue
        expected_b32 = expected[len(HASH_PREFIX) :]

        # Reconstruct the download path from the recorded download_id.
        download_url = f"/download/{name}/{download_id}"
        release = ReleaseInfo(
            name=name,
            version=version,
            download_url=download_url,
            download_id=download_id,
        )

        print(f"[{name}] {version} ...", end=" ", flush=True)
        try:
            actual = download_and_hash(release)
        except Exception as e:
            print("ERROR")
            failures.append(f"{name}: {e}")
            continue

        if actual == expected_b32:
            print("ok")
            ok += 1
        else:
            print("MISMATCH")
            failures.append(
                f"{name}: expected sha256:{expected_b32}, got sha256:{actual}"
            )

    print(f"\n{ok} ok, {len(failures)} failed.")
    if failures:
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)


def cmd_prefetch(args: argparse.Namespace) -> None:
    """Prefetch all mods into the nix store and verify the hashes match."""
    if shutil.which("nix-prefetch-url") is None:
        sys.exit("Error: nix-prefetch-url not found on PATH.")

    path = Path(args.file)
    doc = load_toml(path)
    mods = get_mods(doc)

    if len(mods) == 0:
        print("No mods to prefetch.")
        return

    ok = 0
    failures: list[str] = []

    for entry in mods:
        name = entry["name"]
        version = entry["version"]
        download_id = entry["download_id"]
        expected = entry["hash"]
        if not expected.startswith(HASH_PREFIX):
            failures.append(f"{name}: hash field missing 'sha256:' prefix")
            continue
        expected_b32 = expected[len(HASH_PREFIX) :]

        download_url = f"/download/{name}/{download_id}"
        release = ReleaseInfo(
            name=name,
            version=version,
            download_url=download_url,
            download_id=download_id,
        )

        print(f"[{name}] {version} prefetching...", end=" ", flush=True)
        try:
            actual = nix_prefetch(release, expected_hash=expected_b32)
        except subprocess.CalledProcessError as e:
            print("ERROR")
            failures.append(
                f"{name}: nix-prefetch-url failed: "
                f"{e.stderr.strip() or e.stdout.strip()}"
            )
            continue

        if actual == expected_b32:
            print("ok")
            ok += 1
        else:
            print("MISMATCH")
            failures.append(
                f"{name}: expected sha256:{expected_b32}, got sha256:{actual}"
            )

    print(f"\n{ok} ok, {len(failures)} failed.")
    if failures:
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)


# ---------- CLI ----------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Manage a Factorio mods TOML file.")
    p.add_argument(
        "-f",
        "--file",
        default="mods.toml",
        help="Path to the TOML file (default: mods.toml)",
    )
    sub = p.add_subparsers(dest="command", required=True)

    p_add = sub.add_parser("add", help="Add a mod by name.")
    p_add.add_argument("name")
    p_add.set_defaults(func=cmd_add)

    p_rm = sub.add_parser("remove", help="Remove a mod by name.")
    p_rm.add_argument("name")
    p_rm.set_defaults(func=cmd_remove)

    p_up = sub.add_parser("update", help="Update all mods to the latest version.")
    p_up.set_defaults(func=cmd_update)

    p_val = sub.add_parser("validate", help="Validate all mod hashes.")
    p_val.set_defaults(func=cmd_validate)

    p_pf = sub.add_parser("prefetch", help="Prefetch all mods into the nix store.")
    p_pf.set_defaults(func=cmd_prefetch)

    return p


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
