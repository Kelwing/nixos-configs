#!/usr/bin/env python3
"""
Verify Factorio mod hashes listed in a TOML manifest by invoking `nix-prefetch-url`.

Expected TOML format:

    [[mod]]
    name = "AutoDeconstruct"
    download_id = "69a0d19734a726c6c089b0ea"
    hash = "sha256:130nz4vykc00j5m3bmx83p82gl3c5kvahn15b7vj7q1nxflhxcj0"

Environment variables:
    FACTORIO_USERNAME  Factorio.com username (required)
    FACTORIO_TOKEN     Factorio.com service token (required)

Exit codes:
    0  all mods prefetched and hashes matched
    1  hash mismatch or prefetch failure
    2  configuration / usage error (bad args, missing env, malformed TOML)
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

import tomllib

FACTORIO_DOWNLOAD_BASE = "https://mods.factorio.com/download"


@dataclass(frozen=True)
class Mod:
    name: str
    download_id: str
    expected_hash: str  # e.g. "sha256:130nz4vykc0..."


def log(msg: str) -> None:
    # Flush so output is interleaved correctly in GitHub Actions logs.
    print(msg, flush=True)


def gha_group(title: str) -> None:
    # Collapsible log group in GitHub Actions; harmless elsewhere.
    print(f"::group::{title}", flush=True)


def gha_endgroup() -> None:
    print("::endgroup::", flush=True)


def gha_error(msg: str) -> None:
    print(f"::error::{msg}", flush=True)


def parse_mods(path: Path) -> list[Mod]:
    try:
        with path.open("rb") as f:
            data = tomllib.load(f)
    except OSError as e:
        raise SystemExit(f"error: could not read {path}: {e}")
    except tomllib.TOMLDecodeError as e:
        raise SystemExit(f"error: malformed TOML in {path}: {e}")

    raw_mods = data.get("mod")
    if not isinstance(raw_mods, list) or not raw_mods:
        raise SystemExit(f"error: {path} contains no [[mod]] entries")

    mods: list[Mod] = []
    for i, entry in enumerate(raw_mods):
        if not isinstance(entry, dict):
            raise SystemExit(f"error: [[mod]] #{i} is not a table")
        try:
            name = entry["name"]
            download_id = entry["download_id"]
            expected_hash = entry["hash"]
        except KeyError as e:
            raise SystemExit(
                f"error: [[mod]] #{i} is missing required field {e.args[0]!r}"
            )
        if not (
            isinstance(name, str)
            and isinstance(download_id, str)
            and isinstance(expected_hash, str)
        ):
            raise SystemExit(f"error: [[mod]] #{i} has non-string field(s)")
        mods.append(
            Mod(name=name, download_id=download_id, expected_hash=expected_hash)
        )
    return mods


def split_hash(expected: str) -> tuple[str, str]:
    """Split 'sha256:abc...' into ('sha256', 'abc...'). Defaults to sha256 if no prefix."""
    if ":" in expected:
        algo, _, digest = expected.partition(":")
        return algo, digest
    return "sha256", expected


def build_url(name: str, download_id: str, username: str, token: str) -> str:
    # URL-encode the path components defensively. Mod names generally contain only
    # URL-safe characters, but we don't want to assume that.
    safe_name = quote(name, safe="")
    safe_id = quote(download_id, safe="")
    safe_user = quote(username, safe="")
    safe_token = quote(token, safe="")
    return (
        f"{FACTORIO_DOWNLOAD_BASE}/{safe_name}/{safe_id}"
        f"?username={safe_user}&token={safe_token}"
    )


def prefetch(url: str, algo: str, filename: str) -> str:
    """
    Run `nix-prefetch-url --type <algo> <url>` and return the prefetched hash.
    Raises RuntimeError on failure.
    """
    # Note: --type selects the hash algorithm. nix-prefetch-url emits the hash
    # on stdout (and download progress on stderr).
    try:
        proc = subprocess.run(
            ["nix-prefetch-url", "--type", algo, "--name", filename, url],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        raise RuntimeError(
            "`nix-prefetch-url` not found on PATH. Install Nix or add it to PATH."
        )
    except subprocess.CalledProcessError as e:
        # Do NOT print the URL here; it contains the auth token.
        stderr = e.stderr.strip() if e.stderr else ""
        raise RuntimeError(
            f"nix-prefetch-url exited with status {e.returncode}:\n{stderr}"
        )

    got = proc.stdout.strip()
    if not got:
        raise RuntimeError("nix-prefetch-url produced no output")
    return got


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Verify Factorio mod hashes via nix-prefetch-url.",
    )
    _ = ap.add_argument(
        "manifest",
        type=Path,
        help="Path to the TOML manifest containing [[mod]] entries.",
    )
    args = ap.parse_args(argv)

    username = os.environ.get("FACTORIO_USERNAME")
    token = os.environ.get("FACTORIO_TOKEN")
    if not username or not token:
        gha_error("FACTORIO_USERNAME and FACTORIO_TOKEN must both be set.")
        return 2

    try:
        mods = parse_mods(args.manifest)
    except SystemExit as e:
        gha_error(str(e))
        return 2

    log(f"Verifying {len(mods)} mod(s) from {args.manifest}")

    failures: list[tuple[Mod, str]] = []
    for mod in mods:
        gha_group(f"{mod.name} ({mod.download_id})")
        try:
            algo, expected_digest = split_hash(mod.expected_hash)
            url = build_url(mod.name, mod.download_id, username, token)
            filename = f"{mod.name}_{mod.download_id}.zip"
            got_digest = prefetch(url, algo, filename)

            if got_digest == expected_digest:
                log(f"  OK  {mod.name}: {algo}:{got_digest}")
            else:
                msg = (
                    f"hash mismatch for {mod.name}:\n"
                    f"  expected: {algo}:{expected_digest}\n"
                    f"  actual:   {algo}:{got_digest}"
                )
                log(f"  FAIL  {msg}")
                failures.append((mod, msg))
        except RuntimeError as e:
            log(f"  FAIL  {mod.name}: {e}")
            failures.append((mod, str(e)))
        finally:
            gha_endgroup()

    if failures:
        gha_error(f"{len(failures)} of {len(mods)} mod(s) failed verification")
        for mod, msg in failures:
            gha_error(f"{mod.name}: {msg}")
        return 1

    log(f"All {len(mods)} mod(s) verified successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
