"""Rebuild index.json from what is actually on disk.

The index is the integrity record every lzt-flow install reads: a module's entry names the sha256
the backend will check the downloaded flow.json against. Generating it from the merged tree — never
accepting one from a pull request — is what makes the checksum mean "these are the reviewed bytes"
rather than "these are the bytes whoever wrote the entry wanted".

To be clear about what that buys (R-6): the checksum is transport integrity. It proves the file did
not change between this repo and the install. It is not a signature and says nothing about whether
the author is trustworthy — that is what the pull-request review is for.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

INDEX_SCHEMA_VERSION = 1
ROOT = Path(__file__).resolve().parents[2]
MODULES = ROOT / "modules"


MODULE_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,63}$")


def main() -> None:
    entries = []
    for module_dir in sorted(p for p in MODULES.iterdir() if p.is_dir()):
        manifest_path = module_dir / "module.yaml"
        if not manifest_path.is_file():
            continue
        # The name becomes a URL segment and a path segment on every operator's box. Git already
        # rejects `/` and `..` in a path component, so this cannot currently fire — which is
        # exactly why it is cheap to keep: the index is the one artifact every install trusts, and
        # its safety should not rest on a property of git that nobody wrote down.
        if not MODULE_NAME_RE.match(module_dir.name):
            raise SystemExit(f"{module_dir.name}: not a module name")

        kind = _field(manifest_path, "kind") or "flow"
        # What the checksum covers, per kind: a flow module's graph is the thing that executes; a
        # python module's pyproject is the thing pip reads. Neither is a signature (R-6) — both
        # only prove the bytes did not change between this repo and the install.
        hashed = module_dir / ("flow.json" if kind == "flow" else "pyproject.toml")
        if not hashed.is_file():
            continue
        entries.append(
            {
                "name": module_dir.name,
                "version": _field(manifest_path, "version") or _fail(manifest_path),
                "sha256": hashlib.sha256(hashed.read_bytes()).hexdigest(),
                "kind": kind,
            }
        )

    index = {"schema_version": INDEX_SCHEMA_VERSION, "modules": entries}
    # Trailing newline + fixed separators so a regenerated file is byte-identical when nothing
    # changed — that is what makes generate.yml's "commit only if changed" check work.
    (ROOT / "index.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    print(f"index.json: {len(entries)} module(s)")


def _field(manifest_path: Path, name: str) -> str | None:
    """One flat `key: value` from the manifest, read without pulling in PyYAML.

    A manifest is a handful of flat lines and it has already passed lzt-flow-validate's real parse
    by the time this runs on main, so a dependency here would buy nothing but a slower workflow.
    """
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep and key.strip() == name:
            return value.strip().strip("\"'")
    return None


def _fail(manifest_path: Path) -> str:
    raise SystemExit(f"{manifest_path}: no version field")


if __name__ == "__main__":
    main()
