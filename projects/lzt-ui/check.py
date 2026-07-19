"""Sanity check for the CSS layer and the plain-HTML demos.

Verifies: CSS blocks balance, every lzt-* class used in markup is defined,
every var() resolves, every <use href="#i-*"> exists in the icon sprite,
modal targets resolve, and no off-scale spacing is hand-rolled in markup.

Run:  python check.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
CSS = (HERE / "lzt-ui.css").read_text(encoding="utf-8")
ICONS_JS = (HERE / "lzt-icons.js").read_text(encoding="utf-8")
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

# 4. icon references resolve against the sprite
sprite = set(re.findall(r"^\s*'([a-z0-9-]+)':", ICONS_JS, re.M))
if not sprite:
    failures.append("lzt-icons.js: no icons parsed — the sprite table shape changed")
for demo in DEMOS:
    html = demo.read_text(encoding="utf-8")
    used_icons = set(re.findall(r'<use href="#i-([a-z0-9-]+)"', html))
    missing_icons = sorted(used_icons - sprite)
    if missing_icons:
        failures.append(f"{demo.name}: icons not in the sprite -> {missing_icons}")

# 5. data-lzt-open targets an element that exists
for demo in DEMOS:
    html = demo.read_text(encoding="utf-8")
    ids = set(re.findall(r'id="([^"]+)"', html))
    for target in re.findall(r'data-lzt-open="([^"]+)"', html):
        if target not in ids:
            failures.append(f"{demo.name}: data-lzt-open='{target}' has no matching element")

# 6. no hand-rolled spacing in markup — the scale exists so nothing improvises.
#    `width:` on progress bars and swatch backgrounds are data, not spacing.
SPACING_PROP = re.compile(r'style="[^"]*\b(gap|margin|padding)\s*:', re.I)
for demo in DEMOS:
    for num, line in enumerate(demo.read_text(encoding="utf-8").splitlines(), 1):
        if SPACING_PROP.search(line):
            failures.append(f"{demo.name}:{num}: inline spacing — use the scale utilities")

if failures:
    print("FAIL")
    for f in failures:
        print("  -", f)
    sys.exit(1)

print(
    f"OK — {len(defined)} classes, {len(declared)} tokens, "
    f"{len(sprite)} icons, {len(DEMOS)} demos"
)
