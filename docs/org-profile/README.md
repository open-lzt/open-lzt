<p align="right"><a href="README.en.md">English</a> · <b>Русский</b></p>

<p align="center">
  <img src="ol.png" alt="open-lzt — экосистема автоматизации lolz" width="100%">
</p>

<h1 align="center">open-lzt</h1>
<h3 align="center">Открытый набор инструментов для автоматизации <a href="https://lzt.market">lzt.market</a></h3>
<p align="center">Типизированный Python — от «сырого» API до no-code движка автоматизаций.<br/>Свой сервер, <b>testnet по умолчанию</b>, ноль реальных денег пока сам не переключишь.</p>

<p align="center">
  <a href="https://github.com/open-lzt/open-lzt"><img src="https://img.shields.io/badge/монорепо-open--lzt-7c86ff?style=flat-square" alt="монорепо"></a>
  <img src="https://img.shields.io/badge/python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.12">
  <img src="https://img.shields.io/badge/типизация-mypy--strict-2b7489?style=flat-square" alt="mypy strict">
  <img src="https://img.shields.io/badge/тесты-1500%2B-3fb950?style=flat-square" alt="тесты">
  <img src="https://img.shields.io/badge/лицензия-MIT-blue?style=flat-square" alt="MIT">
</p>

<br/>

### Посмотреть всё за одну команду

```bash
git clone --recurse-submodules https://github.com/open-lzt/open-lzt /opt/open-lzt \
  && cd /opt/open-lzt && sudo bash demo.sh
```

Поднимает стенд с нуля и прогоняет сквозное демо: мок-маркет, SDK, движок событий, автопокупку Steam-аккаунтов флоу, MCP-сервер. Каждый запрос и каждый ответ печатается как есть. Ничего не касается реального маркета — для этого есть отдельный `--mode prod`.

<br/>

<table align="center">
<tr>
<td align="center" width="260"><b>Testnet по умолчанию</b><br/><sub>всё гоняется против мок-маркета — без токена,<br/>реальных денег и реального аккаунта</sub></td>
<td align="center" width="260"><b>Типизировано насквозь</b><br/><sub>mypy --strict, 1500+ тестов, DTO на каждой<br/>границе — не «скрипты», а система</sub></td>
<td align="center" width="260"><b>No-code автоматизации</b><br/><sub>задача как граф-флоу вместо хардкода,<br/>расширяется Python-плагинами</sub></td>
</tr>
</table>

---

### Как это устроено

Шесть самостоятельных проектов, которые складываются друг на друга. Внизу — типизированный SDK, всё остальное стоит на нём. Бери один кубик или весь стенд.

```mermaid
flowchart TD
    pylzt["pylzt · типизированный SDK над lzt.market"]
    eventus["eventus · движок событий"]
    autolzt["auto-lzt · no-code автоматизации"]
    mcp["mcp · сервер для ИИ-агентов"]
    eventussdk["eventus-sdk · клиент событий"]
    testnet["testnet · мок-маркет"]

    pylzt --> eventus
    pylzt --> autolzt
    pylzt --> mcp
    eventus --> eventussdk
    eventus --> autolzt
    testnet -. тестовый двойник .-> pylzt

    classDef base fill:#7c86ff,stroke:#5b63d6,color:#ffffff,font-weight:bold
    classDef node fill:#1c1f2b,stroke:#3a3f52,color:#e8e8e8
    class pylzt base
    class eventus,autolzt,mcp,eventussdk,testnet node
```

| Проект | Что это | Читать |
|---|---|---|
| **[pylzt](https://github.com/open-lzt/pylzt)** | Типизированный async-SDK над API lzt.market / lolzteam / AntiPublic — пул токенов, рейт-лимиты, прокси, сгенерирован из OpenAPI-спеки. Фундамент. | [README](https://github.com/open-lzt/pylzt#readme) |
| **[testnet](https://github.com/open-lzt/lzt-testnet)** | Мок-сервер lzt.market. Оффлайн-двойник, против которого гоняются все проекты — без токена, без реального маркета. | [docs](https://github.com/open-lzt/lzt-testnet/tree/main/docs) |
| **[eventus](https://github.com/open-lzt/lzt-eventus)** | Движок событий: опрос маркета → долговечный, воспроизводимый лог событий → REST / webhook / SSE / WS. | [архитектура](https://github.com/open-lzt/lzt-eventus/blob/main/docs/architecture.md) |
| **[eventus-sdk](https://github.com/open-lzt/lzt-eventus-sdk)** | Async-клиент к eventus — подписки, опрос, проверка webhook-подписи. | [архитектура](https://github.com/open-lzt/lzt-eventus-sdk/blob/main/docs/architecture.md) |
| **[auto-lzt](https://github.com/open-lzt/auto-lzt)** | Серверный движок **no-code автоматизаций**. Описываешь задачу («поднимай лоты каждый час») как граф-флоу — движок исполняет. Расширяется плагинами. | [дизайн флоу](https://github.com/open-lzt/auto-lzt/blob/main/docs/flow-design-guide.md) · [плагины](https://github.com/open-lzt/auto-lzt/blob/main/docs/plugins.md) |
| **[mcp](https://github.com/open-lzt/lzt-mcp)** | MCP-сервер — даёт ИИ-агенту безопасно управлять маркетом и тестировать его (testnet по умолчанию, prod под защитой). | [README](https://github.com/open-lzt/lzt-mcp#readme) |

---

### Запуск за одну команду

Монорепо **[open-lzt](https://github.com/open-lzt/open-lzt)** собирает все шесть в единый `systemd`-стенд на одном Linux-хосте:

```bash
git clone --recursive https://github.com/open-lzt/open-lzt
cd open-lzt && sudo bash quickstart.sh
```

### С чего начать

- **Впервые здесь?** → [**Зачем нужен open-lzt**](https://github.com/open-lzt/open-lzt/blob/main/docs/WHY.md) — разбор с самых азов, простым языком: что это и как на этом строить софт под lolz.
- **Хочешь запустить?** → [README монорепо](https://github.com/open-lzt/open-lzt/blob/main/README.md) — установка одной командой, testnet по умолчанию.
- **Хочешь расширять?** → [Контрибуция](https://github.com/open-lzt/open-lzt/blob/main/CONTRIBUTING.md) — напиши флоу, плагин или пришли PR в SDK.
- **Ты ИИ-агент?** → [Карта архитектуры](https://github.com/open-lzt/open-lzt/blob/main/docs/ARCHITECTURE.md) — все репозитории и все связи между ними в одном документе.

<br/>

<p align="center"><sub>Сделал <a href="https://github.com/zlexdev">zlexdev</a> · лицензия MIT · автоматизируй с умом и на своих аккаунтах</sub></p>
