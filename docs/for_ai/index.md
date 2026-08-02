<p align="right"><a href="index.en.md">English</a> · <b>Русский</b></p>

# open-lzt — карта для AI-агента

Сжатая ориентировка для агента, работающего в этом монорепо. Читать до грепа по исходникам.

## Раскладка

```
open-lzt/
├─ install.sh / update.sh        # жизненный цикл стенда одной командой (README, «Эксплуатация»)
├─ quickstart.sh / demo.sh       # bootstrap свежего клона и сквозное демо
├─ docker-compose.yml            # только инфраструктура: postgres + redis
├─ .env.example                  # канонический конфиг; install.sh рендерит из него deploy/env/<svc>.env
├─ deploy/systemd/               # юниты: 6 сервисов + пара autoupdate (service и timer)
├─ scripts/{smoke,healthcheck}.sh
├─ lzt-flows/                    # каталог готовых модулей-флоу (сабмодуль)
└─ projects/
   ├─ pylzt/       # async-SDK маркета, форума и antipublic
   ├─ testnet/     # мок-сервер lzt.market на FastAPI — тестовый двойник
   ├─ eventus/     # сервис движка событий (REST :27543 + поллер + PG/Redis)
   ├─ flow/        # сервис автоматизаций (API :8000 + arq-воркер + фронтенд)
   ├─ mcp/         # MCP-сервер для AI-агентов (stdio / http :8770)
   ├─ eventus-sdk/ # клиентская библиотека к движку событий
   └─ lzt-ui/      # UI-кит веб-панели
```

## Что важно знать

- **Имена клиента.** Часть потребителей делает `import lztforge` — это шим, реэкспортирующий `pylzt` (`projects/pylzt/src/lztforge/`, MetaPathFinder в рантайме плюс `.pyi`-заглушки). Полное переименование лежит в бэклоге.
- **Проводка testnet.** `MARKET_MODE=testnet` разворачивает всех потребителей на встроенный мок: у mcp это `LZT_DEV_MCP_TESTNET_BASE_URL`, у eventus — `LZT_API_BASE_URL`, у flow — `LZT_FLOW_MARKET_BASE_URL`. Переопределяются оба хоста, и маркет, и форум, чтобы форумные методы не утекли в прод.
- **Изоляция конфигов.** У flow префикс `LZT_FLOW_`, у eventus и встроенного в flow движка — `LZT_`. `install.sh` рендерит отдельный `deploy/env/<svc>.env` на каждый сервис, поэтому префикс `LZT_` нигде не сталкивается.
- Внутренности каждого проекта — в его собственных `projects/<x>/docs/for_ai/` и файлах `_MODULE.md`.

## Куда смотреть

- Установка, карта портов, эксплуатация → `README.md`.
- Внутренности сервиса → `projects/<x>/docs/for_ai/`, `projects/<x>/_MODULE.md`.
- Грабли API маркета → `docs/lzt-gotchas/`.
