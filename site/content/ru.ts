import { runCommand } from '@/lib/site';

import type { Content } from './types';

export const ru = {
  meta: {
    title: 'OPENLZT — открытая экосистема автоматизации lzt.market',
    description:
      'Self-hosted стенд для lzt.market: типизированный SDK, событийный движок, no-code автоматизации и MCP-сервер. Testnet по умолчанию.',
  },

  nav: {
    stand: 'Стенд',
    projects: 'Проекты',
    install: 'Установка',
    github: 'GitHub',
    hosting: 'Хостинг',
  },

  hero: {
    titleTop: 'Автоматизируй lzt.market.',
    titleAccent: 'Открыто.',
    sub: 'Self-hosted стенд: типизированный SDK, событийный движок, no-code автоматизации и MCP-сервер. Testnet-first — ноль реальных денег, пока сам не переключишь.',
    ctaGithub: 'Смотреть на GitHub',
    pip: 'pip install pylzt',
    demo: {
      caption: 'Одна команда на чистом сервере — поставит стенд и покажет его по сценам',
      label: runCommand('demo', '', { short: true }),
      copy: runCommand('demo'),
    },
  },

  builder: {
    title: 'Собери свою команду установки',
    tabStand: 'Поставить стенд',
    tabFlow: 'Поставить флоу',
    output: 'Готовая команда',
    copy: 'скопировать',
    copied: 'скопировано',
    share: 'ссылка на эту сборку',
    shared: 'ссылка скопирована',
    reset: 'сбросить',
    prodWarning:
      'Режим prod бьёт по реальному маркету и тратит реальные деньги. Testnet ничего не тратит.',
    prodConfirm: 'Да, я ставлю на реальный маркет',
    fields: {
      market: { label: 'Режим маркета', hint: 'testnet — мок, ничего не тратится' },
      tls: { label: 'TLS без домена', hint: 'самоподписанный сертификат на голом IP' },
      domain: { label: 'Домен', hint: 'вместе с почтой включает HTTPS через Let’s Encrypt' },
      email: { label: 'Почта для Let’s Encrypt' },
      botToken: { label: 'Токен телеграм-бота', hint: 'не попадает в ссылку — это секрет' },
      botAdmins: { label: 'ID администраторов', hint: 'через запятую; без них бот не стартует' },
      yes: { label: 'Не задавать вопросов', hint: '--yes' },
      dryRun: { label: 'Только показать план', hint: '--dry-run: ничего не меняет' },
      module: { label: 'Модуль каталога' },
      params: { label: 'Параметры модуля' },
      account: { label: 'ID аккаунта' },
      cron: { label: 'Расписание (cron)' },
      run: { label: 'Запустить сразу' },
      noRun: { label: 'Не запускать' },
    },
    addParam: 'добавить параметр',
    paramKey: 'имя',
    paramValue: 'значение',
  },

  stand: {
    hint: 'Живая схема стенда — кликни узел, чтобы перейти к проекту',
    nodes: [
      { tag: 'PYLZT', goto: 'p-pylzt', caption: '**pylzt** — типизированный SDK. Фундамент: на нём стоит весь стенд.' },
      { tag: 'TESTNET', goto: 'p-testnet', caption: '**lzt-testnet** — оффлайн-двойник маркета для тестов.' },
      { tag: 'EVENTUS', goto: 'p-eventus', caption: '**lzt-eventus** — событийный движок с воспроизводимым логом.' },
      { tag: 'AUTO-LZT', goto: 'p-auto', caption: '**auto-lzt** — движок автоматизаций: граф-флоу + канвас React Flow.' },
      { tag: 'MCP', goto: 'p-mcp', caption: '**lzt-dev-mcp** — 29 инструментов для dev-агента, прод заблокирован.' },
      { tag: 'SDK', goto: 'p-sdk', caption: '**lzt-eventus-sdk** — async-клиент к событийному движку.' },
      { tag: 'FLOWS', goto: 'p-flows', caption: '**lzt-flows** — каталог готовых сценариев: autobuy и bump-daily.' },
      { tag: 'PLUGINS', goto: 'p-flows', caption: '**lzt-plugins** — каталог плагинов владельца для auto-lzt.' },
      { tag: 'UI', goto: 'p-ui', caption: '**lzt-ui** — CSS-кит без сборки и зависимостей.' },
    ],
  },

  facts: [
    { value: '10', label: 'проектов в экосистеме' },
    { value: 'testnet', label: 'по умолчанию', accent: true },
    { value: '4', label: 'транспорта событий' },
    { value: '29', label: 'инструментов у MCP' },
  ],

  projectsHead: {
    title: 'Один стенд.',
    titleAccent: 'Десять кубиков.',
    sub: 'Каждый проект самостоятелен: бери один кубик или разворачивай весь стенд. Внизу — типизированный SDK, всё остальное стоит на нём.',
  },

  projects: [
    {
      id: 'p-pylzt',
      kicker: 'Фундамент',
      name: 'pylzt',
      href: 'https://github.com/open-lzt/pylzt',
      body: 'Типизированный async-фреймворк над API **lzt.market**, форума lolzteam и AntiPublic. Пул токенов, рейт-лимиты, прокси — из коробки. **Сгенерирован из официальной OpenAPI-спеки.** Sync-клиент — тот же движок, а не вторая реализация.',
      tags: ['Python · async', '3 namespace: market · forum · antipublic', 'OpenAPI-кодоген'],
      scene: 'pylzt',
      install: {
        title: 'Установка',
        rows: [{ ps: '$', label: 'pip install pylzt', copy: 'pip install pylzt' }],
        optsTitle: 'В коде',
        opts: [
          { label: 'ClientConfig.for_testnet()', copy: 'ClientConfig.for_testnet()' },
          { label: 'Category.STEAM', copy: 'Category.STEAM' },
        ],
        note: 'Против мока токен не нужен.',
      },
    },
    {
      id: 'p-testnet',
      kicker: 'Безопасность по умолчанию',
      name: 'lzt-testnet',
      href: 'https://github.com/open-lzt/lzt-testnet',
      body: 'Мок-сервер поверхности API lzt.market на FastAPI. **Оффлайн-двойник**, против которого гоняются все проекты стенда — без токена, без реального маркета, без риска. Переключи тумблер и посмотри, куда бьют запросы.',
      tags: ['FastAPI', 'без токена', 'оффлайн'],
      scene: 'testnet',
      install: {
        title: 'Установка',
        rows: [
          { ps: '$', label: 'git clone .../lzt-testnet', copy: 'git clone https://github.com/open-lzt/lzt-testnet' },
          { ps: '$', label: 'uv run python -m lzt_testnet', copy: 'uv run python -m lzt_testnet' },
        ],
        optsTitle: 'Флаги',
        opts: [
          { label: '--host 127.0.0.1', copy: '--host 127.0.0.1' },
          { label: '--port 8000', copy: '--port 8000' },
        ],
        note: 'В тестах поднимается прямо в процессе через uvicorn.',
      },
    },
    {
      id: 'p-eventus',
      kicker: 'Событийный движок',
      name: 'lzt-eventus',
      href: 'https://github.com/open-lzt/lzt-eventus',
      body: 'Опрашивает маркет и превращает его в **долговечный, воспроизводимый лог событий**. На лог подписывается кто угодно — свой же процесс, вебхук на другом хосте, SSE/WS-стрим, cron-поллер. У каждого свой курсор, **catch-up после простоя**, ретраи и DLQ.',
      tags: ['durable-лог', '4 транспорта', 'поверх pylzt'],
      scene: 'eventus',
      install: {
        title: 'Установка',
        rows: [
          { ps: '$', label: 'git clone .../lzt-eventus lzt-core', copy: 'git clone https://github.com/open-lzt/lzt-eventus lzt-core && cd lzt-core' },
          { ps: '$', label: 'scripts/quickstart.sh', copy: 'scripts/quickstart.sh' },
          { ps: '$', label: 'uv run python -m lzt_eventus run', copy: 'uv run python -m lzt_eventus run' },
        ],
        optsTitle: 'Флаги',
        opts: [{ label: '--dry-run', copy: '--dry-run' }],
        note: 'Стек поднимается из deploy/docker-compose.yml. С --dry-run поллит и диффит, но не пишет.',
      },
    },
    {
      id: 'p-auto',
      kicker: 'No-code автоматизации',
      name: 'auto-lzt',
      href: 'https://github.com/open-lzt/auto-lzt',
      body: 'Серверный движок автоматизаций. Описываешь задачу — **«поднимай лоты каждый день»** — как граф-флоу, движок исполняет по расписанию. Канвас на React Flow, расширяется Python-плагинами владельца.',
      tags: ['flow-графы', 'React Flow канвас', 'плагины владельца'],
      scene: 'flow',
      install: {
        title: 'Установка — весь стенд одним скриптом',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'pnpm --dir frontend dev', copy: 'pnpm --dir frontend dev' },
        ],
        note: 'Канвас поднимется на localhost:5173. Для сборки панели нужны node 20+ и pnpm.',
      },
    },
    {
      id: 'p-sdk',
      kicker: 'Клиент к движку',
      name: 'lzt-eventus-sdk',
      href: 'https://github.com/open-lzt/lzt-eventus-sdk',
      body: 'Async-клиент к management-API движка: **подписки, опрос, проверка webhook-подписи**. Подключаешь свой сервис к шине событий тремя строками — курсор и catch-up движок держит сам.',
      tags: ['подписки', 'верификация подписи', 'poll · webhook · SSE · WS'],
      scene: 'sdk',
      install: {
        title: 'Установка',
        rows: [
          { ps: '$', label: 'pip install lzt-eventus-sdk', copy: 'pip install lzt-eventus-sdk' },
          { ps: '$', label: 'pip install lzt-eventus-sdk[ws]', copy: 'pip install lzt-eventus-sdk[ws]' },
        ],
        optsTitle: 'Транспорты',
        opts: [
          { label: 'WEBHOOK', copy: 'SubscriptionTransport.WEBHOOK' },
          { label: 'SSE', copy: 'SubscriptionTransport.SSE' },
          { label: 'WEBSOCKET', copy: 'SubscriptionTransport.WEBSOCKET' },
        ],
        note: 'WebSocket-источник живёт в отдельном extra.',
      },
    },
    {
      id: 'p-mcp',
      kicker: 'Для dev-агентов',
      name: 'lzt-dev-mcp',
      href: 'https://github.com/open-lzt/lzt-mcp',
      body: '**29 инструментов** для ИИ-агента: слать и тестировать сырые API-запросы, управлять сценариями auto-lzt и подписками eventus, изучать поверхность API без грепа исходников. По умолчанию testnet — **прод жёстко заблокирован**.',
      tags: ['MCP · 29 инструментов', 'testnet-first', 'интроспекция API'],
      scene: 'mcp',
      install: {
        title: 'Запуск',
        rows: [
          { ps: '$', label: 'uv run python -m lzt_dev_mcp --http --port 8765', copy: 'uv run python -m lzt_dev_mcp --http --port 8765' },
        ],
        optsTitle: 'Флаги',
        opts: [
          { label: '--http', copy: '--http' },
          { label: '--port 8765', copy: '--port 8765' },
        ],
        note: 'Подключи http://127.0.0.1:8765 как MCP-сервер в своём агенте.',
      },
    },
    {
      id: 'p-flows',
      kicker: 'Каталоги расширений',
      name: 'lzt-flows + plugins',
      href: 'https://github.com/open-lzt/lzt-flows',
      body: '**lzt-flows** — комьюнити-каталог готовых сценариев: автовыкуп по Steam, Riot, Supercell, Fortnite, Telegram — и снайпер по любой из 21 категории. **lzt-plugins** — каталог исполняемых Python-плагинов владельца: ноды, роутеры, обработчики.',
      tags: ['9 модулей каталога', 'manifest + flow.json', 'PR-каталог'],
      scene: 'catalog',
      install: {
        title: 'Установка модуля',
        rows: [
          { ps: 'bot', label: '/import bump-daily', copy: '/import bump-daily' },
          { ps: '$', label: 'install-flow.sh --module steam-autobuy --run', copy: 'sudo bash install-flow.sh --module steam-autobuy --param max_price=10 --param count=1 --run' },
        ],
        optsTitle: 'Параметры',
        opts: [
          { label: '--module steam-autobuy', copy: '--module steam-autobuy' },
          { label: '--param max_price=10', copy: '--param max_price=10' },
          { label: '--param count=1', copy: '--param count=1' },
          { label: '--run', copy: '--run' },
        ],
        note: 'В боте: /modules — список, /import — установка.',
      },
    },
    {
      id: 'p-ui',
      kicker: 'Дизайн-система',
      name: 'lzt-ui',
      href: 'https://github.com/open-lzt/lzt-ui',
      body: 'Библиотека заготовок в визуальном языке LZT: **чистый CSS и 150 строк ванильного JS**. Без сборки, без зависимостей, без утилити-фреймворка. Один и тот же CSS потребляется и обычным HTML, и React-компонентами.',
      tags: ['чистый CSS', 'иконки', 'ноль зависимостей'],
      scene: 'uikit',
      install: {
        title: 'Подключение',
        rows: [
          { ps: 'html', label: '<link rel="stylesheet" href="lzt-ui.css">', copy: '<link rel="stylesheet" href="lzt-ui.css">' },
          { ps: 'html', label: '<script src="lzt-ui.js"></script>', copy: '<script src="lzt-ui.js"></script>' },
          { ps: 'html', label: '<script src="lzt-icons.js"></script>', copy: '<script src="lzt-icons.js"></script>' },
        ],
      },
    },
    {
      id: 'p-mono',
      kicker: 'Весь стенд разом',
      name: 'open-lzt',
      href: 'https://github.com/open-lzt/open-lzt',
      body: 'Монорепозиторий экосистемы: **восемь проектов как git-субмодули** под одной крышей. Один clone — и весь стенд у тебя, от SDK до панели. Установка и обновление — своими скриптами.',
      tags: ['8 субмодулей', 'docker compose', 'install · update'],
      scene: 'mono',
      install: {
        title: 'Установка',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'git clone --recursive .../open-lzt.git /opt/open-lzt', copy: 'git clone --recursive https://github.com/open-lzt/open-lzt.git /opt/open-lzt' },
        ],
        optsTitle: 'Эксплуатация',
        opts: [
          { label: 'логи', copy: 'docker compose logs -f api worker' },
          { label: 'остановить', copy: 'docker compose down' },
          { label: 'снести с данными', copy: 'docker compose down -v' },
        ],
        note: 'Без -v данные Postgres и Redis переживут переустановку.',
      },
    },
  ],

  install: {
    title: 'Поставить',
    titleAccent: 'за минуту',
    sub: 'Каждая строка кликабельна — копируется целиком.',
    tabs: [
      {
        id: 'sdk',
        label: 'Только SDK',
        rows: [{ ps: '$', label: 'pip install pylzt', copy: 'pip install pylzt' }],
      },
      {
        id: 'stand',
        label: 'Весь стенд',
        rows: [
          { ps: '$', label: runCommand('all', '', { short: true }), copy: runCommand('all') },
          { ps: '$', label: 'git clone --recursive .../open-lzt.git /opt/open-lzt', copy: 'git clone --recursive https://github.com/open-lzt/open-lzt.git /opt/open-lzt' },
          { ps: '$', label: 'docker compose -f deploy/docker-compose.yml up -d', copy: 'docker compose -f deploy/docker-compose.yml up -d' },
        ],
      },
      {
        id: 'flow',
        label: 'Готовый флоу',
        rows: [
          { ps: '$', label: runCommand('flow', '--module steam-autobuy', { short: true }), copy: runCommand('flow', '--module steam-autobuy --param max_price=10 --run') },
          { ps: 'bot', label: '/modules · /import bump-daily', copy: '/import bump-daily' },
        ],
      },
    ],
  },

  cta: {
    title: 'Присоединяйся',
    titleAccent: 'к нам!',
    url: 'github.com/open-lzt',
    text: '**Десять проектов**, которые складываются друг на друга. Внизу — типизированный SDK, всё остальное стоит на нём. Бери один кубик или весь стенд одним скриптом.',
    copied: 'скопировано',
  },

  footer: { note: 'открытый исходный код' },

  // Страница хостинга. Правило одно и оно несущее: **бесплатный путь называется первым**.
  // Страница, которая продаёт то, что рядом лежит открытым, и молчит об этом, читается как
  // обман ровно в ту секунду, когда человек находит репозиторий, — а он его находит.
  hosting: {
    meta: {
      title: 'OPENLZT — хостинг стенда',
      description:
        'Движок открытый и ставится самостоятельно. Платный хостинг — для тех, кому нужен работающий стенд, а не сервер.',
    },
    titleTop: 'Стенд, который',
    titleAccent: 'уже работает.',
    sub: 'Тот же открытый движок, только поднимать, обновлять и чинить его не вам. Аккаунт площадки подключается за пару минут, сценарии включаются кнопкой.',
    free: {
      title: 'Сначала — бесплатный путь',
      body: 'Движок **открытый и бесплатный навсегда**. Один скрипт на своём сервере ставит тот же стенд целиком: SDK, событийный движок, автоматизации. Ничего урезанного, ничего просроченного.',
      cta: 'Поставить самому',
    },
    paid: {
      title: 'За что берутся деньги',
      body: 'Только за то, что стенд работает без вас. Код тот же — платите вы за чужие руки, а не за доступ к функциям.',
      points: [
        'Сервер, обновления и мониторинг на нашей стороне',
        'Обновления приезжают сами, без переустановки',
        'Отмена в один клик, доступ доживает оплаченный срок',
      ],
    },
    steps: {
      title: 'Как начать',
      items: [
        'Открыть бота и завести своего — Telegram спросит имя, токен придёт сам',
        'Подключить аккаунт площадки',
        'Выбрать сценарий и включить',
      ],
    },
    review: {
      title: 'Доступ за отзыв',
      body: 'Доступ открывается **сразу**, отзыв оставляется после. Условия видны в боте до того, как что-то нажато.',
      points: [
        'Отзыв с того же аккаунта площадки, что подключён',
        'Скриншоты: бот и открытая подписка',
        'Отзыв должен остаться на месте — удалённый закрывает доступ',
      ],
    },
    cta: {
      label: 'Открыть бота',
      note: 'Вход через Telegram, пароль не нужен.',
    },
    back: 'На главную',
  },
} satisfies Content;
