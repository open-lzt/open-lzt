<p align="right"><b>English</b> · <a href="CONTRIBUTING.md">Русский</a></p>

# Contributing to open-lzt

Thanks for helping. There are **three different ways** to contribute, and they have different rules
because they carry different levels of trust. Find yours below.

New to the ecosystem? Read [docs/WHY.en.md](docs/WHY.en.md) and [docs/ARCHITECTURE.en.md](docs/ARCHITECTURE.en.md)
first — they explain how the pieces fit, which makes the rest of this obvious.

---

## Pick your contribution surface

| I want to… | Trust level | Where | Guide |
|---|---|---|---|
| **Share an automation** (a flow, as data) | Anyone | flow catalog / API | [flow-design-guide](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md) · [modules](https://github.com/open-lzt/auto-lzt/blob/main/docs/modules.md) |
| **Add a new node/capability** (Python code) | Owner-only | flow plugin | [plugins](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md) |
| **Improve a core project** (SDK, engine, bugfix) | Reviewed PR | any repo | this file, §Core PRs |

---

## 1. Share a flow (no code, anyone)

A **flow module** (`kind: flow`) is an automation expressed as *data* — a graph of
`trigger → fetch → filter → action → notify`. Because it's data, anyone can publish it and a
validator checks it before it runs.

- Design it with the [flow-design guide](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md).
- Or describe it in plain text and let the `flow-from-text` helper draft + validate the FlowSpec.
- Publishing and the catalog are covered in [modules.md](https://github.com/open-lzt/auto-lzt/blob/main/docs/modules.md).

This is the friendliest entry point — no Python required.

## 2. Write a Python plugin (code, owner-only)

A **Python plugin** (`kind: python`) adds real executable capability — new node types, routers,
handlers. **This is trusted code with no sandbox**: by design it can do anything on the account. That
is why plugins are **owner-only**, installed via `pip` + a service restart — *never* accepted through
the API from a stranger. Running arbitrary code from untrusted authors would be a security hole, not
a feature.

- Follow [plugins.md](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md): the minimal
  structure is a `pyproject.toml` entry point + a `nodes.py` with the `REGISTRATIONS` pattern.
- If you're proposing a plugin for the main project, open an issue first — it will be reviewed as
  trusted code, held to the same standards as §3.

## 3. Improve a core project (reviewed PR)

Bug fixes and features in `pylzt`, `testnet`, `eventus`, `eventus-sdk`, `flow`, or `mcp` go through a
normal pull request.

**Vibe-coded PRs are welcome** — hand-written or AI-assisted, doesn't matter. The result does. But:

- **Small.** One clear change, not "the AI generated 2000 lines across the whole project". A large
  refactor gets an issue first.
- **Not slop.** Typed (`mypy --strict`, DTOs at boundaries, no `Any`), layered (Handler → Service →
  Repo — no logic in the handler, no SQL outside the repository), tests for the new behaviour.
- **Described in detail.** What you change and why; for a bug fix, the reproduction and the root
  cause — not just the symptom.

Run the checklist below before opening the PR — it's the line between "vibe-coded" and "slop".

### Dev setup

Each project is a standalone [`uv`](https://docs.astral.sh/uv/) package. Work inside the one you're
changing:

```bash
cd projects/<name>
uv sync --all-extras
uv run pytest -q                       # run the suite
```

The stand defaults to **testnet**, and so do the tests — they run against the mock market, no token
needed. Only opt-in markers (`-m live`, `-m pg`) touch real infra; leave them off unless you mean it.

### Before you open a PR — the checklist

```bash
cd projects/<name>
uv run ruff format --check .
uv run ruff check .
uv run mypy src        # 'app' for flow
uv run pytest -q       # green, including the default e2e where present
```

- **Typed.** `mypy --strict` clean. No `Any` as a shortcut, no bare `dict` across a boundary — DTOs.
- **Tested.** New behavior gets a test. Bugfix gets a regression test. Suite stays green.
- **Lint-clean.** `ruff` + `ruff format` pass.
- **Testnet-safe.** No test hits the real market by default.
- **Focused.** One logical change per PR. Update the touched project's docs (`docs/`, `_MODULE.md`).
- **No secrets.** Never commit `.env`, `*.session`, `*.db`, tokens, or keys.

Commit messages describe the **user-visible change**, not the internal mechanic. One commit per
logical change.

---

## Reporting bugs & security

- **Bugs / features:** open an issue on the relevant repo. Include repro steps, the project, and
  whether you were on testnet or prod.
- **Security:** do **not** open a public issue for a vulnerability — contact the maintainer
  ([@zlexdev](https://github.com/zlexdev)) privately. Given the plugin trust model, treat anything
  touching the owner-only code path as sensitive.

---

By contributing you agree your work is released under the project's [MIT license](LICENSE).
Automate responsibly, on your own accounts.
