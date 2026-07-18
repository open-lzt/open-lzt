"""A module's manifest must name the person who opened the pull request.

Without this, anyone could submit a module attributed to someone the community already trusts —
which is the only currency this registry has, since the checksum proves integrity and not
authorship (R-6).

Runs in the `pull_request` workflow: read-only token, no secrets, fork's code. It reads the PR
author from the event payload rather than from anything in the diff, because a field the submitter
controls cannot be the thing that checks the submitter.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _pr_author() -> str:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        sys.exit("not running in a GitHub pull_request event")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    return str(event["pull_request"]["user"]["login"])


def _changed_modules() -> list[str]:
    base = os.environ.get("GITHUB_BASE_REF", "main")
    diff = subprocess.run(
        ["git", "diff", "--name-only", f"origin/{base}...HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    names = {
        line.split("/")[1]
        for line in diff.splitlines()
        if line.startswith("modules/") and len(line.split("/")) > 1
    }
    return sorted(names)


def _manifest_author(module: str) -> str | None:
    manifest = ROOT / "modules" / module / "module.yaml"
    if not manifest.is_file():
        return None
    for line in manifest.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep and key.strip() == "author":
            return value.strip().strip("\"'")
    return None


def _known_authors() -> set[str]:
    """authors.yml is the roster. A new author is a separate, separately-reviewed pull request —
    which is exactly why validate.yml refuses a PR that touches both it and a module."""
    path = ROOT / "authors.yml"
    if not path.is_file():
        return set()
    return {
        line.removeprefix("- ").strip().strip("\"'")
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith("- ")
    }


def main() -> int:
    author = _pr_author()
    known = _known_authors()
    failures: list[str] = []

    for module in _changed_modules():
        declared = _manifest_author(module)
        if declared is None:
            failures.append(f"{module}: manifest has no author")
        elif declared != author:
            # Case-sensitive on purpose: GitHub logins are, and a near-miss is the interesting case.
            failures.append(f"{module}: manifest says author {declared!r} but the PR is from {author!r}")
        elif known and declared not in known:
            failures.append(f"{module}: {declared!r} is not in authors.yml — add yourself in a separate PR")

    for failure in failures:
        print(f"::error::{failure}")
    if not failures:
        print(f"author ok: {author}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
