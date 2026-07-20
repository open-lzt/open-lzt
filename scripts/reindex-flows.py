#!/usr/bin/env python3
"""Rebuild lzt-flows/index.json from the modules on disk.

The index is what a stand fetches before importing a module, and every entry carries the sha256 of
that module's flow.json. Hand-editing it drifts: the checked-in index listed steam-autobuy at 1.0.0
while its manifest already said 2.0.0, which is exactly the mismatch that makes an import fail with
CHECKSUM_MISMATCH long after the change that caused it.

So: version and checksum both come from the module directory, never from the previous index.
Idempotent by construction — running it twice leaves the file byte-identical.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "lzt-flows"
MODULES = ROOT / "modules"
INDEX = ROOT / "index.json"

SCHEMA_VERSION = 1
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,63}$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
# module.yaml is flat where it matters, so a 2-line reader beats requiring pyyaml in a hook script.
FIELD_RE = re.compile(r"^(\w+):[ \t]*(.*)$")


def read_manifest(path: pathlib.Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = FIELD_RE.match(line)
        if match:
            fields[match.group(1)] = match.group(2).strip().strip("'\"")
    return fields


def main() -> int:
    entries = []
    problems = []

    for directory in sorted(p for p in MODULES.iterdir() if p.is_dir()):
        manifest_path = directory / "module.yaml"
        if not manifest_path.is_file():
            problems.append(f"{directory.name}: no module.yaml")
            continue

        manifest = read_manifest(manifest_path)
        name = manifest.get("name", "")
        version = manifest.get("version", "")
        kind = manifest.get("kind", "flow")

        if name != directory.name:
            problems.append(f"{directory.name}: manifest name is {name!r}")
        if not NAME_RE.match(name):
            problems.append(f"{directory.name}: name does not match the module name pattern")
        if not SEMVER_RE.match(version):
            problems.append(f"{directory.name}: version {version!r} is not semver")

        flow_path = directory / "flow.json"
        if kind == "flow":
            if not flow_path.is_file():
                problems.append(f"{directory.name}: kind is flow but there is no flow.json")
                continue
            digest = hashlib.sha256(flow_path.read_bytes()).hexdigest()
        else:
            # A python module ships a package, not a graph; its checksum covers the manifest.
            digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()

        entries.append({"name": name, "version": version, "sha256": digest, "kind": kind})

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1

    payload = {"schema_version": SCHEMA_VERSION, "modules": entries}
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    changed = not INDEX.is_file() or INDEX.read_text(encoding="utf-8") != rendered
    INDEX.write_text(rendered, encoding="utf-8", newline="\n")

    print(f"{'rewrote' if changed else 'unchanged'} {INDEX} ({len(entries)} modules)")
    for entry in entries:
        print(f"  {entry['name']:<20} {entry['version']:<8} {entry['kind']:<7} {entry['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
