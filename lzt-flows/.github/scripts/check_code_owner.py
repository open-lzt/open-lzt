"""Only the repo owner may publish a module that contains code.

**Read this before trusting it.** This check is a guardrail, NOT the security boundary.

For a `pull_request` event GitHub runs the workflow from the merge of head into base — so the
author of a fork PR can edit `validate.yml` *in that same PR* and delete this step. They get no
secrets and no write token, but they do get to remove the check. Anyone who plans to bypass this
will bypass it.

What actually keeps a `.py` out of `main` is CODEOWNERS plus branch protection: the file lands
because the owner clicked merge. This script exists so the owner learns *why* a PR is suspicious
before reading 400 lines of it, and so an honest contributor who adds a `.py` by accident gets a
clear answer instead of a silent rejection weeks later.

The runtime does not trust this either: `ModuleService.import_module` refuses any non-FLOW module
outright, so even a merged code module cannot be installed through the API.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# The one account allowed to publish code. Not read from a file in the repo: a value a PR can edit
# is not a control, and this one is small enough to be read at a glance during a review of the
# workflow itself.
CODE_OWNER = "zlexdev"


def _pr_author() -> str:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        sys.exit("not running in a GitHub pull_request event")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    return str(event["pull_request"]["user"]["login"])


def _changed() -> list[str]:
    base = os.environ.get("GITHUB_BASE_REF", "main")
    diff = subprocess.run(
        ["git", "diff", "--name-only", f"origin/{base}...HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return [line for line in diff.splitlines() if line.startswith("modules/")]


def _declared_kind(module: str) -> str:
    """The manifest's own `kind`. Read with a line scan rather than PyYAML: this runs before any
    pip install, and a dependency here is a dependency in the untrusted-PR job."""
    manifest = ROOT / "modules" / module / "module.yaml"
    if not manifest.is_file():
        return "flow"
    for line in manifest.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep and key.strip() == "kind":
            return value.strip().strip("\"'")
    return "flow"


def main() -> int:
    author = _pr_author()
    changed = _changed()
    failures: list[str] = []

    code_files = [f for f in changed if f.endswith(".py") or f.endswith("pyproject.toml")]
    if code_files and author != CODE_OWNER:
        failures.append(
            f"{author!r} is not the code owner. A module containing code runs on every operator's "
            f"box with their market tokens — only {CODE_OWNER!r} publishes those. "
            f"Offending files: {', '.join(sorted(code_files)[:5])}"
        )

    # A manifest that CLAIMS kind: python is the same claim, whether or not the PR carries a .py
    # yet — the next PR would add one.
    touched = {f.split("/")[1] for f in changed if len(f.split("/")) > 1}
    for module in sorted(touched):
        if _declared_kind(module) != "flow" and author != CODE_OWNER:
            failures.append(f"{module}: only {CODE_OWNER!r} may publish a code module")

    for failure in failures:
        print(f"::error::{failure}")
    if not failures:
        print(f"code-owner check ok: {author}, {len(changed)} changed path(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
