<p align="right"><b>English</b> · <a href="WHY.md">Русский</a></p>

<p align="center">
  <img src="../ol.png" alt="open-lzt" width="100%">
</p>

# Why open-lzt exists

> **TL;DR** — Doing things on lzt.market by hand is slow and boring. Scripting it yourself means
> fighting auth, rate-limits, proxies, and pagination before you write a single useful line.
> **open-lzt is the stack that already fought those fights** — so you go straight to the part you
> actually care about: the automation. It runs on your server, and starts in a safe fake-market mode
> so you can't break anything while you learn.

Read this top to bottom. Each project below is the answer to a problem the previous step created.
That's the whole story.

---

## First: what is lzt.market?

[lzt.market](https://lzt.market) is the lolzteam marketplace — people buy and sell accounts, and do
a lot of repetitive market chores: bumping listings so they stay visible, watching for new deals,
reacting when something sells. It has an API (a way for programs, not humans, to talk to it).

**The itch:** anything you do by hand more than twice, you want a program to do for you. Bump every
hour. Buy the second a cheap Steam account appears. Ping me when I sell something. That's automation.

---

## Problem 1: "I'll just script the API myself" — and then reality hits

You open the API docs, and here's what's actually in your way *before* any automation logic:

- **Auth & tokens** — one token gets rate-limited fast; serious use needs a *pool* of tokens rotated.
- **Rate limits** — hit the market too hard and you're blocked. You need throttling.
- **Proxies** — same story, IP-level.
- **Pagination, retries, weird error shapes** — the boring 80% of any API client.

You'd spend a week on plumbing before your bump-bot bumps anything.

### → The answer: **pylzt** (the SDK)

`pylzt` is a typed Python client that already solved all of that: **token pool, rate-limiting, proxy
rotation, retries, pagination**, generated straight from the official API spec. You call one typed
method and it handles the mess.

> **This is the foundation.** Everything else in open-lzt talks to the market *through* pylzt. You
> never build a raw HTTP request yourself.

---

## Problem 2: "Okay it works — but I'm terrified of testing on real accounts"

Your first script has bugs. Every run hits the *real* market, spends *real* money, touches a *real*
account. Learning like that is nerve-wracking.

### → The answer: **testnet** (the fake market)

`testnet` is a mock server that speaks the **exact same API** as the real market — but it's fake and
offline. No token, no money, no risk. You point your code at it, break things freely, and only switch
to the real market when you're confident.

> **open-lzt ships in testnet mode by default.** You literally cannot hit the real market until you
> flip one switch (`MARKET_MODE=prod`). Safety is the default, not an afterthought.

---

## Problem 3: "I want to *react* to things, not just poke the market"

Bumping on a timer is easy. But "do X the moment something sells" is harder — you'd have to poll the
market in a loop, remember what you already saw, and not miss events if your script restarts.

### → The answer: **eventus** (the event engine) + **eventus-sdk** (its client)

`eventus` does the polling *once*, centrally. It turns market changes into **events** ("new order",
"item sold"), writes them to a durable log you can **replay**, and pushes them to you over webhook /
SSE / WebSocket. Your app just *subscribes* and reacts. `eventus-sdk` is the little library you
import to consume that stream.

> Think of it as: the market whispers changes to eventus, eventus shouts them to everyone who's
> listening — reliably, even after a restart.

---

## Problem 4: "I don't even want to write code"

Maybe you just want to *describe* the automation: "bump my lots every hour," "buy Steam accounts
under 500₽." You shouldn't need to be a Python developer for that.

### → The answer: **flow** (the no-code engine)

`flow` runs automations described as a **graph**: `trigger → fetch → filter → action → notify`. You
describe it (in JSON, or in plain text that a helper turns into the graph), and flow executes it on a
schedule or on an event — using pylzt for the actual market actions. No deploy, no code.

Need something flow doesn't have out of the box? It's extensible **two ways**, and the difference
matters:

- **Flow modules** (`kind: flow`) — automations shared as *data*. Anyone can publish; a validator
  checks them. Safe.
- **Python plugins** (`kind: python`) — new node types as *real code*. **Owner-only**, installed by
  `pip` + restart, no sandbox — because running arbitrary code from strangers *is* the security hole.
  So only the owner does it, on purpose.

---

## Problem 5: "Can an AI just do all this for me?"

You've got an AI agent. You want it to test API calls, spin up flows, check events — without it
fat-fingering the real market and spending your money.

### → The answer: **mcp** (the agent gateway)

`mcp` is an MCP server: a typed toolbox an AI agent plugs into. It can drive the whole stand — but
it's **testnet-default and prod-guarded**, so the agent plays in the sandbox unless you explicitly
let it out.

---

## The whole picture, in one breath

```
pylzt      →  talk to the market without the plumbing pain
testnet    →  ...safely, against a fake market first
eventus    →  react to what happens, reliably
flow       →  automate without writing code
mcp        →  let an AI do it, guarded
open-lzt   →  all of the above, one server, one command
```

Each layer exists because the one below it left a gap. Stacked, they take you from "raw API is
scary" to "my automation runs itself and an AI can babysit it."

---

## Where do *you* start?

Pick the sentence that sounds like you:

- **"I just want to run the whole thing and poke at it."** → [monorepo README](../README.en.md):
  `sudo bash quickstart.sh`, everything comes up in testnet mode. Poke away.
- **"I want to automate a task without coding."** → flow's
  [flow-design guide](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md).
- **"I want to add a new capability (code)."** → flow's
  [plugins guide](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md) + our
  [CONTRIBUTING](../CONTRIBUTING.en.md).
- **"I'm building my own app on the market API."** → import
  [pylzt](https://github.com/open-lzt/pylzt) and, if you need events,
  [eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk).
- **"I want the deep technical map."** → [ARCHITECTURE.en.md](ARCHITECTURE.en.md).

## Your first 15 minutes

1. Install the stand (README quickstart). It comes up in **testnet mode** — safe.
2. Hit a health check, watch five services report green.
3. Create one tiny flow (a single bump) and run it against the testnet. Watch it complete.
4. *Now* you understand the loop. Everything else is more nodes and more flows.

---

> **One rule, always:** automate on **your own** accounts, within lolzteam's rules. The testnet
> default exists so you learn without risk — keep that spirit when you go to prod.
