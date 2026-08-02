<p align="right"><a href="README.en.md">English</a> · <b>Русский</b></p>

# open-lzt

Свой стенд автоматизации [lzt.market](https://lzt.market): шесть сервисов, одна команда, один Linux-хост. **По умолчанию testnet — запросы уходят во встроенный мок-маркет, реальные деньги не тратятся, пока вы сами не переключите режим.**

Посмотреть, ничего не устанавливая:

```bash
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/demo.sh | sudo bash
```

Демо поднимает стенд и само же прогоняет по нему все проекты, показывая каждый запрос и каждый ответ.

| Флаг demo.sh | Что делает |
|---|---|
| `--mode testnet\|prod` | против мока или живого маркета |
| `--skip-install` | не ставить, использовать уже поднятый стенд |
| `--speed fast\|normal\|slow` | темп показа сцен |
| `--max-price` · `--count` | параметры демонстрационной покупки |
| `--no-update` · `--yes` | не обновляться, не задавать вопросов |

## Установка

Debian или Ubuntu 22.04/24.04, systemd, root. Kubernetes и облачные схемы не поддерживаются — это один хост.

```bash
git clone https://github.com/open-lzt/open-lzt.git /opt/open-lzt \
  && cd /opt/open-lzt && sudo bash quickstart.sh
```

`quickstart.sh` подтягивает сабмодули и вызывает `install.sh`. Если сабмодули уже на месте, ставьте напрямую:

```bash
sudo ./install.sh --dry-run    # показать план, ничего не делая
sudo ./install.sh
```

`install.sh` идемпотентен: ставит Docker и uv, поднимает Postgres и Redis, синхронизирует зависимости всех проектов, применяет миграции и включает systemd-юниты.

| Флаг install.sh | Что делает |
|---|---|
| `--market-mode testnet\|prod` | против чего работает стенд |
| `--bot-token` · `--bot-admins` | Telegram-бот управления |
| `--domain` · `--email` · `--tls` | публичный домен и сертификат Let's Encrypt |
| `--dry-run` · `--yes` | план без изменений; без вопросов |

## Что поднимается

| Сервис | systemd-юнит | Порт | Роль |
|---|---|---|---|
| testnet | `open-lzt-testnet` | 8765 | мок API маркета |
| eventus | `open-lzt-eventus` | 27543 | движок событий и management API |
| flow API | `open-lzt-flow-api` | 8000 | HTTP-API автоматизаций |
| flow worker | `open-lzt-flow-worker` | — | очередь arq и планировщик |
| mcp | `open-lzt-mcp` | 8770 | MCP-сервер для AI-агентов |
| bot | `open-lzt-bot` | — | Telegram-бот, только если включён |
| Postgres | контейнер | 55432 | базы `lztflow` и `lzteventus` |
| Redis | контейнер | 56379 | очереди, дедуп, кэш |

Все порты слушают `127.0.0.1`. Наружу стенд выходит только через nginx, если вы задали домен.

Обновление стенда по расписанию — юниты `open-lzt-autoupdate.service` и `.timer`, разбор в [docs/AUTOUPDATE.md](docs/AUTOUPDATE.md).

## testnet или prod

Режим задаётся `MARKET_MODE` в `.env` либо флагом `--market-mode` при установке. В `testnet` токен маркета не нужен вовсе. Переключение на `prod` — единственный момент, когда стенд начинает тратить настоящие деньги.

## Состав

Восемь сабмодулей.

| Путь | Репозиторий | Что это |
|---|---|---|
| `projects/pylzt` | [pylzt](https://github.com/open-lzt/pylzt) | типизированный async-SDK над API маркета, форума и AntiPublic. Фундамент |
| `projects/testnet` | [lzt-testnet](https://github.com/open-lzt/lzt-testnet) | мок-сервер маркета, оффлайн-двойник для тестов |
| `projects/eventus` | [lzt-eventus](https://github.com/open-lzt/lzt-eventus) | движок событий: опрос → лог → webhook, SSE, WS, REST |
| `projects/eventus-sdk` | [lzt-eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk) | клиент к движку событий |
| `projects/flow` | [auto-lzt](https://github.com/open-lzt/auto-lzt) | no-code автоматизации, задача как граф |
| `projects/mcp` | [lzt-mcp](https://github.com/open-lzt/lzt-mcp) | MCP-сервер, даёт AI-агенту работать с маркетом |
| `projects/lzt-ui` | [lzt-ui](https://github.com/open-lzt/lzt-ui) | UI-кит веб-панели |
| `lzt-flows` | [lzt-flows](https://github.com/open-lzt/lzt-flows) | каталог готовых модулей-флоу |

## Обновление и готовые флоу

```bash
sudo ./update.sh                                                              # rolling update стенда
wget -qO- https://github.com/open-lzt/open-lzt/raw/main/install-flow.sh | sudo bash   # поставить готовый флоу
```

## Конфигурация

`.env` создаётся установщиком, секреты генерируются им же. Главное:

| Переменная | По умолчанию | Что это |
|---|---|---|
| `MARKET_MODE` | `testnet` | против чего работает стенд |
| `TESTNET_PORT` · `EVENTUS_PORT` · `FLOW_PORT` · `MCP_PORT` | 8765 · 27543 · 8000 · 8770 | порты сервисов |
| `POSTGRES_PORT` · `REDIS_PORT` | 55432 · 56379 | порты контейнеров |
| `FLOW_MASTER_KEY` · `EVENTUS_TOKEN_ENC_KEY` | генерируются | шифрование токенов; ключи разные и не взаимозаменяемы |
| `FLOW_API_KEY` · `EVENTUS_ADMIN_API_KEY` | генерируются | доступ к API |
| `EVENTUS_TOKENS` | `[]` | токены маркета, JSON-массив в одинарных кавычках |
| `LZT_FLOW_EGRESS_ALLOWED_HOSTS` | `api.telegram.org` | куда узлам-запросам разрешено ходить |
| `BOT_ENABLED` · `BOT_TOKEN` · `BOT_ADMIN_IDS` | `0` | Telegram-бот |
| `DOMAIN` · `TLS_MODE` · `LETSENCRYPT_EMAIL` | пусто · `none` | публичный доступ и сертификат |

Полный список с комментариями — `.env.example`.

## Эксплуатация

```bash
scripts/healthcheck.sh                  # все сервисы разом
scripts/smoke.sh                        # сквозная проверка стенда
journalctl -u open-lzt-flow-api -f      # логи сервиса
systemctl stop open-lzt-flow-api        # остановить сервис
```

## Документация

[Зачем это нужно](docs/WHY.md) — с самых азов, простым языком · [Архитектура](docs/ARCHITECTURE.md) — все репозитории и связи · [Автообновление](docs/AUTOUPDATE.md) · [Архитектура панели](docs/panel-architecture.md) · [Грабли API маркета](docs/lzt-gotchas/) · [Для AI-агентов](docs/for_ai/) · [Контрибуция](CONTRIBUTING.md)

## Лицензия

[MIT](LICENSE)
