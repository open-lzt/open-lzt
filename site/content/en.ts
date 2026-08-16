import { runCommand } from '@/lib/site';

import type { Content } from './types';

export const en = {
  meta: {
    title: 'OPENLZT — open toolkit for automating lzt.market',
    description:
      'Self-hosted stand for lzt.market: typed SDK, event engine, no-code automation and an MCP server. Testnet by default.',
  },

  nav: {
    stand: 'Stand',
    projects: 'Projects',
    install: 'Install',
    github: 'GitHub',
    hosting: 'Hosting',
  },

  hero: {
    titleTop: 'Automate lzt.market.',
    titleAccent: 'In the open.',
    sub: 'A self-hosted stand: typed SDK, event engine, no-code automation and an MCP server. Testnet-first — zero real money until you switch it yourself.',
    ctaGithub: 'View on GitHub',
    pip: 'pip install pylzt',
    demo: {
      caption: 'One command on a clean server — installs the stand, then walks you through it',
      label: runCommand('demo', '', { short: true }),
      copy: runCommand('demo'),
    },
  },

  builder: {
    title: 'Build your install command',
    tabStand: 'Install the stand',
    tabFlow: 'Install a flow',
    output: 'Ready to paste',
    copy: 'copy',
    copied: 'copied',
    share: 'link to this setup',
    shared: 'link copied',
    reset: 'reset',
    prodWarning: 'prod hits the real market and spends real money. Testnet spends nothing.',
    prodConfirm: 'Yes, install against the real market',
    fields: {
      market: { label: 'Market mode', hint: 'testnet is a mock — nothing is spent' },
      tls: { label: 'TLS without a domain', hint: 'self-signed certificate on a bare IP' },
      domain: { label: 'Domain', hint: 'together with the email it enables HTTPS via Let’s Encrypt' },
      email: { label: 'Email for Let’s Encrypt' },
      botToken: { label: 'Telegram bot token', hint: 'never written to the link — it is a secret' },
      botAdmins: { label: 'Admin ids', hint: 'comma separated; without them the bot does not start' },
      yes: { label: 'Ask nothing', hint: '--yes' },
      dryRun: { label: 'Print the plan only', hint: '--dry-run: changes nothing' },
      module: { label: 'Catalogue module' },
      params: { label: 'Module parameters' },
      account: { label: 'Account id' },
      cron: { label: 'Schedule (cron)' },
      run: { label: 'Run right away' },
      noRun: { label: 'Do not run' },
    },
    addParam: 'add parameter',
    paramKey: 'name',
    paramValue: 'value',
  },

  stand: {
    hint: 'Live map of the stand — click a node to jump to its project',
    nodes: [
      { tag: 'PYLZT', goto: 'p-pylzt', caption: '**pylzt** — the typed SDK. The foundation the whole stand sits on.' },
      { tag: 'TESTNET', goto: 'p-testnet', caption: '**lzt-testnet** — an offline twin of the market for tests.' },
      { tag: 'EVENTUS', goto: 'p-eventus', caption: '**lzt-eventus** — event engine with a replayable log.' },
      { tag: 'AUTO-LZT', goto: 'p-auto', caption: '**auto-lzt** — automation engine: flow graphs on a React Flow canvas.' },
      { tag: 'MCP', goto: 'p-mcp', caption: '**lzt-dev-mcp** — 29 tools for a dev agent, production hard-blocked.' },
      { tag: 'SDK', goto: 'p-sdk', caption: '**lzt-eventus-sdk** — async client for the event engine.' },
      { tag: 'FLOWS', goto: 'p-flows', caption: '**lzt-flows** — catalogue of ready scenarios: autobuy and bump-daily.' },
      { tag: 'PLUGINS', goto: 'p-flows', caption: '**lzt-plugins** — owner-trusted plugin catalogue for auto-lzt.' },
      { tag: 'UI', goto: 'p-ui', caption: '**lzt-ui** — CSS kit with no build step and no dependencies.' },
    ],
  },

  facts: [
    { value: '10', label: 'projects in the ecosystem' },
    { value: 'testnet', label: 'by default', accent: true },
    { value: '4', label: 'event transports' },
    { value: '29', label: 'tools in the MCP server' },
  ],

  projectsHead: {
    title: 'One stand.',
    titleAccent: 'Ten bricks.',
    sub: 'Every project stands alone: take one brick or bring up the whole stand. At the bottom sits the typed SDK; everything else rests on it.',
  },

  projects: [
    {
      id: 'p-pylzt',
      kicker: 'Foundation',
      name: 'pylzt',
      href: 'https://github.com/open-lzt/pylzt',
      body: 'A typed async framework over the **lzt.market** API, the lolzteam forum and AntiPublic. Token pool, rate limits and proxies out of the box. **Generated from the official OpenAPI spec.** The sync client is the same engine, not a second implementation.',
      tags: ['Python · async', '3 namespaces: market · forum · antipublic', 'OpenAPI codegen'],
      scene: 'pylzt',
      install: {
        title: 'Install',
        rows: [{ ps: '$', label: 'pip install pylzt', copy: 'pip install pylzt' }],
        optsTitle: 'In code',
        opts: [
          { label: 'ClientConfig.for_testnet()', copy: 'ClientConfig.for_testnet()' },
          { label: 'Category.STEAM', copy: 'Category.STEAM' },
        ],
        note: 'Against the mock no token is needed.',
      },
    },
    {
      id: 'p-testnet',
      kicker: 'Safe by default',
      name: 'lzt-testnet',
      href: 'https://github.com/open-lzt/lzt-testnet',
      body: 'A FastAPI mock of the lzt.market API surface. An **offline twin** every project in the stand runs against — no token, no real market, no risk. Flip the switch and watch where the requests land.',
      tags: ['FastAPI', 'no token', 'offline'],
      scene: 'testnet',
      install: {
        title: 'Install',
        rows: [
          { ps: '$', label: 'git clone .../lzt-testnet', copy: 'git clone https://github.com/open-lzt/lzt-testnet' },
          { ps: '$', label: 'uv run python -m lzt_testnet', copy: 'uv run python -m lzt_testnet' },
        ],
        optsTitle: 'Flags',
        opts: [
          { label: '--host 127.0.0.1', copy: '--host 127.0.0.1' },
          { label: '--port 8000', copy: '--port 8000' },
        ],
        note: 'In tests it comes up in-process via uvicorn.',
      },
    },
    {
      id: 'p-eventus',
      kicker: 'Event engine',
      name: 'lzt-eventus',
      href: 'https://github.com/open-lzt/lzt-eventus',
      body: 'Polls the market and turns it into a **durable, replayable event log**. Anyone subscribes to that log — your own process, a webhook on another host, an SSE/WS stream, a cron poller. Each gets its own cursor, **catch-up after downtime**, retries and a DLQ.',
      tags: ['durable log', '4 transports', 'on top of pylzt'],
      scene: 'eventus',
      install: {
        title: 'Install',
        rows: [
          { ps: '$', label: 'git clone .../lzt-eventus lzt-core', copy: 'git clone https://github.com/open-lzt/lzt-eventus lzt-core && cd lzt-core' },
          { ps: '$', label: 'scripts/quickstart.sh', copy: 'scripts/quickstart.sh' },
          { ps: '$', label: 'uv run python -m lzt_eventus run', copy: 'uv run python -m lzt_eventus run' },
        ],
        optsTitle: 'Flags',
        opts: [{ label: '--dry-run', copy: '--dry-run' }],
        note: 'The stack comes up from deploy/docker-compose.yml. With --dry-run it polls and diffs but writes nothing.',
      },
    },
    {
      id: 'p-auto',
      kicker: 'No-code automation',
      name: 'auto-lzt',
      href: 'https://github.com/open-lzt/auto-lzt',
      body: 'A server-side automation engine. You describe the job — **“bump my lots every day”** — as a flow graph and the engine runs it on schedule. React Flow canvas, extended by owner-trusted Python plugins.',
      tags: ['flow graphs', 'React Flow canvas', 'owner plugins'],
      scene: 'flow',
      install: {
        title: 'Install — the whole stand in one script',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'pnpm --dir frontend dev', copy: 'pnpm --dir frontend dev' },
        ],
        note: 'The canvas comes up on localhost:5173. Building the panel needs node 20+ and pnpm.',
      },
    },
    {
      id: 'p-sdk',
      kicker: 'Client for the engine',
      name: 'lzt-eventus-sdk',
      href: 'https://github.com/open-lzt/lzt-eventus-sdk',
      body: 'Async client for the engine’s management API: **subscriptions, polling, webhook signature verification**. Three lines connect your service to the bus — the cursor and catch-up are the engine’s job.',
      tags: ['subscriptions', 'signature verification', 'poll · webhook · SSE · WS'],
      scene: 'sdk',
      install: {
        title: 'Install',
        rows: [
          { ps: '$', label: 'pip install lzt-eventus-sdk', copy: 'pip install lzt-eventus-sdk' },
          { ps: '$', label: 'pip install lzt-eventus-sdk[ws]', copy: 'pip install lzt-eventus-sdk[ws]' },
        ],
        optsTitle: 'Transports',
        opts: [
          { label: 'WEBHOOK', copy: 'SubscriptionTransport.WEBHOOK' },
          { label: 'SSE', copy: 'SubscriptionTransport.SSE' },
          { label: 'WEBSOCKET', copy: 'SubscriptionTransport.WEBSOCKET' },
        ],
        note: 'The WebSocket source lives in a separate extra.',
      },
    },
    {
      id: 'p-mcp',
      kicker: 'For dev agents',
      name: 'lzt-dev-mcp',
      href: 'https://github.com/open-lzt/lzt-mcp',
      body: '**29 tools** for an AI agent: send and test raw API requests, drive auto-lzt scenarios and eventus subscriptions, introspect the API surface without grepping sources. Testnet by default — **production is hard-blocked**.',
      tags: ['MCP · 29 tools', 'testnet-first', 'API introspection'],
      scene: 'mcp',
      install: {
        title: 'Run',
        rows: [
          { ps: '$', label: 'uv run python -m lzt_dev_mcp --http --port 8765', copy: 'uv run python -m lzt_dev_mcp --http --port 8765' },
        ],
        optsTitle: 'Flags',
        opts: [
          { label: '--http', copy: '--http' },
          { label: '--port 8765', copy: '--port 8765' },
        ],
        note: 'Point your agent at http://127.0.0.1:8765 as an MCP server.',
      },
    },
    {
      id: 'p-flows',
      kicker: 'Extension catalogues',
      name: 'lzt-flows + plugins',
      href: 'https://github.com/open-lzt/lzt-flows',
      body: '**lzt-flows** — a community catalogue of ready scenarios: autobuy for Steam, Riot, Supercell, Fortnite, Telegram — and a sniper across any of 21 categories. **lzt-plugins** — executable owner-trusted Python plugins: nodes, routers, handlers.',
      tags: ['9 catalogue modules', 'manifest + flow.json', 'PR catalogue'],
      scene: 'catalog',
      install: {
        title: 'Install a module',
        rows: [
          { ps: 'bot', label: '/import bump-daily', copy: '/import bump-daily' },
          { ps: '$', label: 'install-flow.sh --module steam-autobuy --run', copy: 'sudo bash install-flow.sh --module steam-autobuy --param max_price=10 --param count=1 --run' },
        ],
        optsTitle: 'Parameters',
        opts: [
          { label: '--module steam-autobuy', copy: '--module steam-autobuy' },
          { label: '--param max_price=10', copy: '--param max_price=10' },
          { label: '--param count=1', copy: '--param count=1' },
          { label: '--run', copy: '--run' },
        ],
        note: 'In the bot: /modules lists, /import installs.',
      },
    },
    {
      id: 'p-ui',
      kicker: 'Design system',
      name: 'lzt-ui',
      href: 'https://github.com/open-lzt/lzt-ui',
      body: 'A library of building blocks in the LZT visual language: **plain CSS and 150 lines of vanilla JS**. No build step, no dependencies, no utility framework. The same CSS is consumed by plain HTML and by React components alike.',
      tags: ['plain CSS', 'icons', 'zero dependencies'],
      scene: 'uikit',
      install: {
        title: 'Include',
        rows: [
          { ps: 'html', label: '<link rel="stylesheet" href="lzt-ui.css">', copy: '<link rel="stylesheet" href="lzt-ui.css">' },
          { ps: 'html', label: '<script src="lzt-ui.js"></script>', copy: '<script src="lzt-ui.js"></script>' },
          { ps: 'html', label: '<script src="lzt-icons.js"></script>', copy: '<script src="lzt-icons.js"></script>' },
        ],
      },
    },
    {
      id: 'p-mono',
      kicker: 'The whole stand at once',
      name: 'open-lzt',
      href: 'https://github.com/open-lzt/open-lzt',
      body: 'The ecosystem monorepo: **eight projects as git submodules** under one roof. One clone and the whole stand is yours, from the SDK to the panel. Install and update ship as its own scripts.',
      tags: ['8 submodules', 'docker compose', 'install · update'],
      scene: 'mono',
      install: {
        title: 'Install',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'git clone --recursive .../open-lzt.git /opt/open-lzt', copy: 'git clone --recursive https://github.com/open-lzt/open-lzt.git /opt/open-lzt' },
        ],
        optsTitle: 'Operations',
        opts: [
          { label: 'logs', copy: 'docker compose logs -f api worker' },
          { label: 'stop', copy: 'docker compose down' },
          { label: 'wipe with data', copy: 'docker compose down -v' },
        ],
        note: 'Without -v the Postgres and Redis data survive a reinstall.',
      },
    },
  ],

  install: {
    title: 'Up and running',
    titleAccent: 'in a minute',
    sub: 'Every line is clickable — it copies in full.',
    tabs: [
      {
        id: 'sdk',
        label: 'SDK only',
        rows: [{ ps: '$', label: 'pip install pylzt', copy: 'pip install pylzt' }],
      },
      {
        id: 'stand',
        label: 'Whole stand',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'git clone --recursive .../open-lzt.git /opt/open-lzt', copy: 'git clone --recursive https://github.com/open-lzt/open-lzt.git /opt/open-lzt' },
          { ps: '$', label: 'docker compose -f deploy/docker-compose.yml up -d', copy: 'docker compose -f deploy/docker-compose.yml up -d' },
        ],
      },
      {
        id: 'flow',
        label: 'A ready flow',
        rows: [
          { ps: '$', label: runCommand('flow', '--module steam-autobuy', { short: true }), copy: runCommand('flow', '--module steam-autobuy --param max_price=10 --run') },
          { ps: 'bot', label: '/modules · /import bump-daily', copy: '/import bump-daily' },
        ],
      },
    ],
  },

  cta: {
    title: 'Join us',
    titleAccent: 'on GitHub',
    url: 'github.com/open-lzt',
    text: '**Ten projects** that stack on one another. At the bottom sits the typed SDK; everything else rests on it. Take one brick or the whole stand in one script.',
    copied: 'copied',
  },

  footer: { note: 'open source' },

  hosting: {
    meta: {
      title: 'OPENLZT — hosted stand',
      description:
        'The engine is open and self-hostable. Hosting is for people who want a working stand, not a server.',
    },
    titleTop: 'A stand that is',
    titleAccent: 'already running.',
    sub: 'The same open engine — you just do not have to deploy, update or fix it. Connect the marketplace account, switch a scenario on.',
    free: {
      title: 'The free path first',
      body: 'The engine is **open and free forever**. One script on your own server installs the whole stand: SDK, event engine, automations. Nothing stripped, nothing expiring.',
      cta: 'Self-host it',
    },
    paid: {
      title: 'What the money buys',
      body: 'Only somebody else running it. The code is the same — you pay for the hands, not for the features.',
      points: [
        'Server, updates and monitoring on our side',
        'Updates arrive on their own, no reinstall',
        'Cancel in one tap; access lives out the paid period',
      ],
    },
    steps: {
      title: 'How to start',
      items: [
        'Open the bot and create your own — Telegram asks for a name, the token arrives on its own',
        'Connect the marketplace account',
        'Pick a scenario and switch it on',
      ],
    },
    review: {
      title: 'Access for a review',
      body: 'Access opens **immediately**; the review comes after. The terms are on screen before anything is pressed.',
      points: [
        'The review comes from the marketplace account you connected',
        'Screenshots: the bot and an open subscription',
        'The review has to stay up — a deleted one closes the access',
      ],
    },
    cta: {
      label: 'Open the bot',
      note: 'Telegram login, no password.',
    },
    back: 'Home',
  },
} satisfies Content;
