"""Sanity check: CSS parses balanced, every lzt-* class used in the demos is defined,
every var() reference resolves, and every <use href="#id"> has a matching <symbol>.

Run:  python check.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
CSS = (HERE / "lzt-ui.css").read_text(encoding="utf-8")
DEMOS = sorted((HERE / "demo").glob("*.html"))

failures: list[str] = []

# 1. braces balance
depth = 0
for ch in CSS:
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth < 0:
            failures.append("CSS: unbalanced '}' — more closers than openers")
            break
if depth != 0:
    failures.append(f"CSS: {depth} unclosed block(s)")

# 2. every lzt-* class used in markup exists in the stylesheet
defined = set(re.findall(r"\.(lzt-[A-Za-z0-9_-]+)", CSS))
for demo in DEMOS:
    html = demo.read_text(encoding="utf-8")
    used: set[str] = set()
    for attr in re.findall(r'class="([^"]+)"', html):
        for cls in attr.split():
            if cls.startswith("lzt-"):
                used.add(cls)
    missing = sorted(used - defined)
    if missing:
        failures.append(f"{demo.name}: classes used but not defined -> {missing}")

# 3. every var(--lzt-*) resolves to a declared custom property
declared = set(re.findall(r"(--lzt-[A-Za-z0-9_-]+)\s*:", CSS))
referenced = set(re.findall(r"var\((--lzt-[A-Za-z0-9_-]+)", CSS))
unresolved = sorted(referenced - declared)
if unresolved:
    failures.append(f"CSS: var() references with no declaration -> {unresolved}")

# 4. svg sprite references resolve within each demo
for demo in DEMOS:
    html = demo.read_text(encoding="utf-8")
    symbols = set(re.findall(r'<symbol id="([^"]+)"', html))
    uses = set(re.findall(r'<use href="#([^"]+)"', html))
    missing_icons = sorted(uses - symbols)
    if missing_icons:
        failures.append(f"{demo.name}: <use> without <symbol> -> {missing_icons}")

# 5. data-lzt-open targets an element that exists
for demo in DEMOS:
    html = demo.read_text(encoding="utf-8")
    ids = set(re.findall(r'id="([^"]+)"', html))
    for target in re.findall(r'data-lzt-open="([^"]+)"', html):
        if target not in ids:
            failures.append(f"{demo.name}: data-lzt-open='{target}' has no matching element")

if failures:
    print("FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)

print(f"OK — {len(defined)} classes defined, {len(declared)} tokens, {len(DEMOS)} demos checked")
