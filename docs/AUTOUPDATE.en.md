# Auto-update guide

The stand can keep itself current by tracking each project's git branch and rolling forward when a
new commit lands. **Auto-update is off by default** — every service must be opted in explicitly.

## How it works

`deploy/autoupdate.sh` reads one config per service from `deploy/autoupdate/<service>.yaml`. For each
**enabled** service it:

1. fetches the tracked submodule branch and compares it to the checked-out commit;
2. if behind — checks out the new commit and runs `uv sync`;
3. runs the optional **e2e gate** (`e2e_cmd`) — a failing gate aborts and keeps the running version;
4. runs the service's **migrations** (flow / eventus alembic chains, or `none`);
5. **restarts** the service's systemd units;
6. waits on the **health gate** (HTTP `health_url`, or a port-listen check for mcp);
7. if the health gate fails and `rollback_on_failure: true` — reverts to the previous commit,
   re-syncs, restarts, and re-checks.

Run it once by hand, or on a timer:

```bash
sudo bash deploy/autoupdate.sh            # check + update every enabled service
sudo bash deploy/autoupdate.sh --dry-run  # show what it would do, change nothing
```

## Per-service config

One file per service under `deploy/autoupdate/`:

```yaml
# deploy/autoupdate/flow.yaml
enabled: false                                  # master switch — false = never touched
submodule: projects/flow                        # which submodule to track
branch: master                                  # branch to follow
units: "open-lzt-flow-api open-lzt-flow-worker" # systemd units to restart (space-separated)
migrate: flow                                    # flow | eventus | none
health_url: "http://127.0.0.1:8000/catalog/list" # gate after restart
e2e_cmd: ""                                       # optional pre-swap gate, e.g. below
rollback_on_failure: true
```

`mcp.yaml` has no HTTP health route, so it uses `health_port: 8770` instead of `health_url`.

## Enabling it

1. Turn a service on and (recommended) wire its e2e gate:

   ```yaml
   # deploy/autoupdate/flow.yaml
   enabled: true
   e2e_cmd: "uv run --project projects/flow pytest -q -m e2e"
   ```

2. Enable the periodic timer (installed but off by default):

   ```bash
   sudo systemctl enable --now open-lzt-autoupdate.timer
   systemctl list-timers open-lzt-autoupdate.timer   # confirm next run
   ```

   The timer runs `deploy/autoupdate.sh` ~15 min after boot and every 15 min after (edit
   `deploy/systemd/open-lzt-autoupdate.timer` to change the cadence).

To turn it back off: `sudo systemctl disable --now open-lzt-autoupdate.timer`, and/or set
`enabled: false` in the per-service configs.

## Notes

- The **e2e gate is your safety net** — with it wired, a broken commit is caught before it ever
  restarts the service. Leave `e2e_cmd` empty only if you accept updates without a pre-swap test.
- **Signature verification** — set `verify: true` in a service config to require a GPG-signed commit
  (`git verify-commit`) before the updater runs its code as a privileged rollout. Recommended if the
  branch is signed; a failed verification aborts the update.
- The updater advances the submodule checkout in place; it does not push the parent pointer, so a
  `git status` in the monorepo will show the submodule moved — that's expected on a live stand.
- Rollback reverts **code**, not the database. Keep migrations backward-compatible if you rely on
  auto-rollback (add columns, don't drop them in the same release).
- Behaviour is covered by `tests/test_autoupdate.sh` (drives the updater against a throwaway repo in
  `--dry-run`, including the flow-worker restart path).
