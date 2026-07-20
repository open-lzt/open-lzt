<p align="right"><a href="README.en.md">English</a> · <b>Русский</b></p>

<p align="center">
  <img src="ol.png" alt="open-lzt" width="100%">
</p>

<p align="center">
  <strong>Свой стенд автоматизации lzt.market — пять сервисов, одна команда, один сервер.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.12">
  <img src="https://img.shields.io/badge/postgres-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="Postgres 16">
  <img src="https://img.shields.io/badge/redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis 7">
  <img src="https://img.shields.io/badge/systemd-managed-333333?style=for-the-badge&logo=linux&logoColor=white" alt="systemd">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License: MIT"></a>
</p>

### Посмотреть, ничего не устанавливая

```bash
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/demo.sh | sudo bash
```

Одна команда поднимает стенд и прогоняет по нему все пять проектов, показывая каждый запрос и
каждый ответ.

Идёт в **testnet-режиме**: запросы уходят во встроенный мок, реальный маркет не задет, токен не
нужен.

---

**open-lzt** собирает пять lzt-проектов — SDK `pylzt`, мок-маркет `testnet`, движок событий `eventus`,
сервис автоматизаций `flow` и сервер `mcp` для ИИ-агентов — в одно монорепо, которое ставится на один
Linux-хост командой `./install.sh`. По умолчанию он запускается в **testnet-режиме**: каждый сервис
ходит во встроенный мок, так что ничего не касается реального маркетплейса, пока ты не переключишь один
тумблер.

> **Впервые здесь?** Начни с [**Зачем нужен open-lzt**](docs/WHY.md) — простым языком, с азов. Затем
> [**карта архитектуры**](docs/ARCHITECTURE.md) — как связаны все репо, и
> [**CONTRIBUTING**](CONTRIBUTING.md), чтобы собрать флоу, плагин или прислать PR.

### Проекты

| Проект | Роль | Доки |
|---|---|---|
| [pylzt](https://github.com/open-lzt/pylzt) | Типизированный async-SDK над API маркета — фундамент | [README](https://github.com/open-lzt/pylzt#readme) |
| [testnet](https://github.com/open-lzt/lzt-testnet) | Мок lzt.market — оффлайн-двойник, в который ходят все сервисы | [docs/for_ai](https://github.com/open-lzt/lzt-testnet/tree/main/docs/for_ai) |
| [eventus](https://github.com/open-lzt/lzt-eventus) | Движок событий: опрос → долговечный лог → REST/webhook/SSE/WS | [architecture](https://github.com/open-lzt/lzt-eventus/blob/main/docs/architecture.md) · [extending](https://github.com/open-lzt/lzt-eventus/blob/main/docs/extending.md) |
| [eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk) | Async-клиент к eventus | [architecture](https://github.com/open-lzt/lzt-eventus-sdk/blob/main/docs/architecture.md) |
| [flow](https://github.com/open-lzt/auto-lzt) | No-code движок автоматизаций (флоу + плагины) | [flow-design](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md) · [modules](https://github.com/open-lzt/auto-lzt/blob/main/docs/modules.md) · [plugins](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md) |
| [mcp](https://github.com/open-lzt/lzt-mcp) | MCP-сервер для ИИ-агентов (testnet по умолчанию) | [README](https://github.com/open-lzt/lzt-mcp#readme) |
| [lzt-ui](https://github.com/open-lzt/lzt-ui) | UI-кит в стиле LZT: токены, компоненты, демо-форум | [README](https://github.com/open-lzt/lzt-ui#readme) |

[Доки для ИИ](docs/for_ai/) · [Архитектура](docs/ARCHITECTURE.md) · [Зачем](docs/WHY.md) · [Контрибуция](CONTRIBUTING.md) · [Грабли API маркета](docs/lzt-gotchas/)

---

## Быстрый старт — поставить всё на чистый сервер

Цель: Ubuntu 22.04 / 24.04, root. Docker, `uv` и все зависимости ставит сам скрипт; заранее не нужно
ничего.

**Одно исключение — панель.** Она собирается из исходников, и для этого нужны `node` 20+ и `pnpm`.

Скрипт пробует включить `pnpm` через `corepack` (идёт в комплекте с node) сам.

Если node на сервере нет — установка **не падает**: ставится всё остальное, панель просто не
собирается, API работает как раньше. Поставить node и перезапустить `install.sh` можно потом.

Почему не готовый бандл в релизе: сборка из исходников — это и есть гарантия того, что отдаётся
именно тот код, который лежит в репозитории.

**1. Залей код на сервер** (`/opt/open-lzt`):

Всё ставится **одной командой** — она клонирует сабмодули, ставит Docker + `uv`, поднимает Postgres и
Redis, создаёт обе базы, генерирует все секреты (включая пароль Postgres), рендерит по-сервисные
env-файлы, синхронизирует каждый проект, применяет обе цепочки миграций Alembic, ставит и запускает
пять `systemd`-сервисов и прогоняет health-check:

```bash
git clone https://github.com/open-lzt/open-lzt.git /opt/open-lzt \
  && cd /opt/open-lzt && sudo bash quickstart.sh
```

`quickstart.sh` подтягивает сабмодули и запускает установщик. Повторный запуск в любой момент безопасен
(идемпотентно) и заодно служит путём переконфигурации.

**2. Проверь** — все пять сервисов должны рапортовать «здоров»:

```bash
cd /opt/open-lzt && set -a && . .env && set +a && bash scripts/healthcheck.sh
```

```
  ok testnet        http://127.0.0.1:8765/testnet/health
  ok eventus        http://127.0.0.1:27543/healthz
  ok flow           http://127.0.0.1:8000/catalog/list
  ok mcp            :8770 (listening)
```

> Все порты слушают на `127.0.0.1` — это внутренний стенд. Достучись до сервисов со своей рабочей
> машины через SSH-туннель (см. [Удалённый доступ](#удалённый-доступ)), а не выставляя их наружу.

---

## Поставить готовый флоу — одной командой

Стенд уже стоит, теперь нужен сам сценарий. `install-flow.sh` берёт готовый модуль из каталога,
спрашивает его параметры и создаёт флоу:

```bash
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/install-flow.sh | sudo bash
```

Он показывает нумерованное меню модулей, спрашивает цену, количество и холостой прогон, создаёт
флоу и предлагает запустить.

**Это не установщик стенда.** Если стенда нет, скрипт печатает команду `install.sh` и выходит —
он ничего не скачивает и ничего не ставит сам.

Без вопросов, из скрипта или CI — то же самое флагами:

```bash
sudo bash install-flow.sh --module steam-autobuy --param max_price=10 --param count=1 --run
```

Что передано через `--param`, то не спрашивается. Если терминала нет вообще, остальные параметры
берут значения по умолчанию — скрипт не зависает никогда.

Модули лежат в [lzt-flows](lzt-flows/) — там же список того, что уже готово.

---

## Что где работает

| Сервис | systemd-юнит | Порт (127.0.0.1) | Роль |
|---|---|---|---|
| testnet | `open-lzt-testnet` | `8765` | Мок API lzt.market — тест-двойник, в который ходят все сервисы в testnet-режиме |
| eventus | `open-lzt-eventus` | `27543` | Движок событий: опрашивает маркет, отдаёт доменные события по REST/webhook/SSE/WS |
| flow API | `open-lzt-flow-api` | `8000` | HTTP-API автоматизаций flow |
| панель | — (статика в nginx) | `80`/`443` | Веб-панель: задачи по расписанию, поднятие, аккаунты, конструктор флоу |
| flow worker | `open-lzt-flow-worker` | — | очередь arq + планировщик + встроенный роутер событий |
| mcp | `open-lzt-mcp` | `8770` | MCP-сервер — даёт ИИ-агенту безопасно управлять/тестировать маркет на testnet |
| Postgres | docker `open-lzt-postgres-1` | `55432` | Две базы: `lztflow`, `lzteventus` |
| Redis | docker `open-lzt-redis-1` | `56379` | Очереди, дедуп, кэш |

Инфра (Postgres, Redis) работает в Docker; пять Python-сервисов — под `systemd` через `uv`.

Панель — не сервис: `install.sh` собирает её из исходников, nginx отдаёт готовые файлы с диска
и проксирует `/api/` на flow.

Как устроена — [docs/panel-architecture.md](docs/panel-architecture.md).

---

## Эксплуатация

### Мониторинг

```bash
# Разовый health всех сервисов
cd /opt/open-lzt && set -a && . .env && set +a && bash scripts/healthcheck.sh

# Кросс-сервисный smoke-тест (testnet -> eventus -> flow, без реального маркета)
bash scripts/smoke.sh

# Живой статус / логи одного сервиса
systemctl status open-lzt-eventus
journalctl -u open-lzt-flow-worker -f

# Инфра-контейнеры
docker compose ps
docker compose logs -f postgres
```

### Обновление

```bash
cd /opt/open-lzt && sudo bash update.sh
```

Подтягивает монорепо, продвигает каждый сабмодуль проекта **до последнего коммита его отслеживаемой
ветки** (чтобы новый код проектов реально приезжал), пересинхронизирует зависимости, применяет новые
миграции, перезапускает каждый сервис и заново прогоняет health-check — с health-гейтом: упавший сервис
оставляет предыдущие юниты работать для разбора.

### Авто-обновление (опционально, выключено по умолчанию)

Стенд может отслеживать git-ветку каждого проекта и накатываться вперёд автоматически, с гейтом на e2e-тест
и health-check с откатом. Поставляется **выключенным** — см. [docs/AUTOUPDATE.md](docs/AUTOUPDATE.md),
чтобы включить по-сервисно. Dry-run в любой момент:

```bash
sudo bash deploy/autoupdate.sh --dry-run
```

### Управление отдельными сервисами

```bash
# Перезапустить / остановить / запустить один сервис
sudo systemctl restart open-lzt-flow-api
sudo systemctl stop     open-lzt-mcp
sudo systemctl start    open-lzt-mcp

# Перезапустить весь стенд
for s in testnet eventus flow-api flow-worker mcp; do sudo systemctl restart open-lzt-$s; done
```

### Переключить режим маркета (testnet <-> prod)

```bash
cd /opt/open-lzt
# testnet (по умолчанию): все сервисы ходят во встроенный мок, ноль риска для реального маркета
sed -i 's/^MARKET_MODE=.*/MARKET_MODE=testnet/' .env
# prod: реальный lzt.market — требует реальные токены в EVENTUS_TOKENS
sed -i 's/^MARKET_MODE=.*/MARKET_MODE=prod/' .env
sed -i 's/^EVENTUS_TOKENS=.*/EVENTUS_TOKENS=["your-real-token"]/' .env
sudo ./install.sh   # перерендерит env-файлы + перезапустит; идемпотентно
```

### Удаление

```bash
cd /opt/open-lzt
# остановить + отключить сервисы
for s in testnet eventus flow-api flow-worker mcp; do
  sudo systemctl disable --now open-lzt-$s
  sudo rm -f /etc/systemd/system/open-lzt-$s.service
done
sudo systemctl daemon-reload
# остановить инфру. Добавь -v, чтобы ТАКЖЕ удалить тома данных Postgres/Redis (необратимо).
docker compose down          # сохраняет данные
# docker compose down -v     # сотрёт и базы lztflow + lzteventus
```

Чекаут репо и `deploy/env/*.env` остаются на диске, пока не сделаешь `rm -rf /opt/open-lzt`.

---

## Поверхности интеграции

Разные способы работать с запущенным стендом. Сперва достучись до loopback-портов через
[SSH-туннель](#удалённый-доступ).

### ИИ-агент через MCP (безопасно тестировать маркет)

Наведи свой MCP-клиент на сервер (`http://127.0.0.1:8770` через туннель) или дёргай инструмент напрямую.
В testnet-режиме `send_request` бьёт в мок — без реальных денег, без реального токена:

```python
from lzt_dev_mcp.testing.tools import send_request

# метод в скоупе маркета
lot = await send_request(method_name="GetLot", params={"item_id": 123}, target="testnet")
# метод в скоупе форума — тоже остаётся на testnet (без утечки в prod)
cats = await send_request(method_name="CategoriesGet", params={"category_id": 1}, target="testnet")
assert lot.status == 200 and cats.status == 200
```

### REST — API автоматизаций flow

```bash
curl -s http://127.0.0.1:8000/catalog/list \
     -H "X-API-Key: $(grep ^FLOW_API_KEY= /opt/open-lzt/.env | cut -d= -f2)"
```

### REST — движок событий eventus

```bash
# readiness + опрос подписки (admin-ключ из .env -> deploy/env/eventus.env)
curl -s http://127.0.0.1:27543/healthz
curl -s http://127.0.0.1:27543/subscriptions \
     -H "Authorization: Bearer $(grep ^EVENTUS_ADMIN_API_KEY= /opt/open-lzt/.env | cut -d= -f2)"
```

### Дёргать testnet напрямую

```bash
curl -s http://127.0.0.1:8765/testnet/health
curl -s -X POST http://127.0.0.1:8765/testnet/reset          # очистить in-memory состояние
curl -s -X POST http://127.0.0.1:8765/testnet/revoke-token \
     -H 'Content-Type: application/json' -d '{"token":"testnet-fake-token"}'
```

---

## Публичный доступ (HTTPS)

Панель всегда открыта на портах `80`/`443` — не только на loopback. Без домена сервер не может
получить сертификат от публичного CA (**Let's Encrypt не выдаёт сертификаты на голый IP**), поэтому
`install.sh` сам ставит **самоподписанный сертификат на IP сервера** — браузер один раз покажет
предупреждение, дальше запомнит.

- **Задан домен** (`--domain` или интерактивный ввод) → nginx + сертификат **Let's Encrypt**
  (`certbot`, авто-обновление), `https://<domain>/` → панель, `/api/` → flow API, `/eventus/` →
  eventus. DNS домена уже должен указывать на сервер, порты 80/443 — быть открыты.
- **Домена нет** → самоподписанный сертификат на IP (поведение по умолчанию).
- **`--tls none`** → явный отказ, только HTTP без сертификата.

Сертификат генерируется один раз в `/etc/open-lzt/tls/` — повторный запуск `install.sh` его не
трогает, поэтому однажды принятое предупреждение браузера не сбрасывается на каждом обновлении.

Перезапусти `sudo bash install.sh` (или задай `DOMAIN` / `TLS_MODE` в `.env`), чтобы поменять это позже;
настройка TLS живёт в `deploy/setup_tls.sh`.

## Удалённый доступ

Без публичного домена сервисы слушают только на `127.0.0.1`. Пробрось нужные порты со своей рабочей
машины:

```bash
ssh -N \
  -L 8000:127.0.0.1:8000 \
  -L 8770:127.0.0.1:8770 \
  -L 27543:127.0.0.1:27543 \
  -L 8765:127.0.0.1:8765 \
  root@SERVER_IP
# теперь http://localhost:8000, :8770, :27543, :8765 достают до стенда
```

---

## Разработка и тесты

Каждый проект — самостоятельный пакет `uv`. Прогоняй его сьют из папки проекта:

```bash
cd projects/mcp     && uv run pytest -q       # MCP-сервер + регресс live-testnet
cd projects/testnet && uv run pytest -q       # мок-сервер (roundtrip всех методов)
cd projects/flow    && uv run pytest -q -m "not live and not e2e and not pg"
cd projects/eventus && uv run pytest -q -m "not live and not e2e"
```

---

## Контрибуция

Прогони сьют нужного проекта (выше) и держи `ruff`, `ruff format` и `mypy` чистыми перед PR:

```bash
cd projects/<name>
uv run ruff check . && uv run ruff format --check . && uv run mypy src   # или `app` для flow
```

Полный гайд по контрибуции — [CONTRIBUTING.md](CONTRIBUTING.md). Для багов и фич-реквестов
используй issue-трекер.

## Авторы

<a href="https://github.com/zlexdev"><img src="https://github.com/zlexdev.png" width="48" height="48" style="border-radius:50%" alt="zlexdev" /></a>

## Лицензия

[MIT](LICENSE) © 2026 zlexdev
