# Грабли API: что сервер возвращает на самом деле

Спецификация (OpenAPI на lzt-market.readme.io / lolzteam.readme.io)
описывает почти всё как обязательное. Живой сервер так не работает.

## "Обязательное" поле спецификации значит "иногда его нет"

Ловушка: поле помечено required в спеке — не значит, что оно придёт.

Реальность: какое поле пропущено или придёт `null`, зависит от категории,
от конкретного эндпоинта и от того, как был создан лот. Это не баг одного
эндпоинта — это системное свойство сервера.

Цена этого свойства — худший возможный вид отказа: `purchasing_fast_buy`,
который **уже списал деньги и уже отдал лот**, поднимал `ValidationError`
на десяти косметических полях. Вызывающая сторона видела отказ там, где
покупка на самом деле прошла.

Запомнить: сервер не наш, чинить его нельзя — только принимать его
вариативность на входе.

Источник: `projects/pylzt/src/pylzt/models/base.py` (docstring
`LolzObject.__pydantic_init_subclass__` — там же прямая цитата про
"a `purchasing_fast_buy` that ALREADY MOVED MONEY raised a ValidationError
on ten cosmetic fields").

## Живой `fast-buy` на проде: десять полей разом

Ловушка: тестовая покупка "просто чтобы проверить" — не безобидна, если
сервер потом откажется её подтверждать.

Реальный `purchasing_fast_buy` против прода (2026-07-20, Steam-лоты по
1 рублю) не прошёл валидацию сразу по десяти полям — при этом покупка на
маркетплейсе состоялась.

Семь полей просто отсутствовали в ответе: `buyer_avatar_date`,
`buyer_user_group_id`, `sold_items_category_count`,
`restore_items_category_count`, `canResellItemAfterPurchase`, `deposit`,
`bumpSettings`.

Два поля пришли как `null`: `emailLoginData.encodedOldPassword`,
`seller.restore_percents`.

Источник: `projects/pylzt/src/pylzt/models/market/publishing_check_item.py`.

## `priceWithSellerFee` — это не пропущенное значение, это неверный тип

Ловушка: если поле нельзя починить через "сделать nullable" — вероятно,
дело не в отсутствии, а в типе.

Спецификация объявляет `priceWithSellerFee` как `int`. Живой ответ несёт
дробное значение — например `0.9`. Любая проверка на `int` (в т.ч. через
nullable-обёртку) падает именно потому, что значение не целое.

Тот же паттерн — в `SteamItem`, `BattleNetItem`, `DiscordItem`: везде
`priceWithSellerFee` — `float`, не `int`.

Источник: `projects/pylzt/src/pylzt/models/market/publishing_check_item.py`,
`projects/pylzt/src/pylzt/models/market/steam_item.py`,
`projects/pylzt/src/pylzt/models/market/battle_net_item.py`,
`projects/pylzt/src/pylzt/models/market/discord_item.py`.

## `SteamItem` — восемь итераций несовпадений на одной живой выборке

Ловушка: "один прогон тестов — и всё ясно" не работает: реальный листинг
меняется от запуска к запуску, и новые расхождения всплывают только когда
в выборке случайно попадаются нужные аккаунты.

Что нашлось по `category_steam`, проход за проходом (все — 2026-07-05):

- `canResellItemAfterPurchase` (обязательное `bool`) и `bumpSettings`
  (вообще не описано в спеке) — оба отсутствуют на многих живых листингах;
- `isIgnored`, `hasPendingAutoBuy`, `note_text`, `email_provider`,
  `sold_items_category_count`, `restore_items_category_count` — отсутствуют
  на части листингов;
- `guarantee` — не просто с пустыми подполями, а отсутствует целиком на
  большинстве категорий;
- девять полей `steam_*_inv_value` — `None` на аккаунтах без своего
  инвентаря в игре (не строка и не 0, как можно было бы предположить);
- `steam_bans` — это `dict[str, str]` (Steam appid → причина бана, например
  `{"730": "CS2 Prime"}`), а не строка; при отсутствии банов приходит
  **пустая строка `""`**, а не `{}`;
- `inventoryValue` — список объектов `{"title", "value", "field"}`, не
  список строк;
- `steamCs2Medals`, `cs2MapsRanks` — тоже списки объектов, не строк;
- `cs2PremierElo` — на части аккаунтов приходит **один объект**
  (`{"big", "small", "brand"}`) вместо списка, который заявлен в спеке.

Запомнить: восемь проходов — не признак нестабильного кода, это разброс
самих данных на сервере.

Источник: `projects/pylzt/src/pylzt/models/market/steam_item.py`
(docstring класса `SteamItem`).

## Спецификация иногда ошибается не в сторону "необязательности", а в типе

Ловушка: не каждое расхождение со спекой — "поле стало nullable". Иногда
спека просто содержит опечатку в типе.

`CategoryDiscordItemSeller.restore_percents` объявлен в спеке как `str`.
Соседняя модель `ItemSeller` описывает то же самое поле как `int` — и
живая проверка подтверждает: сервер действительно шлёт `int`
(`int_type`-ошибка валидации при попытке принять `str`). Это опечатка
в самой спецификации, не наша догадка.

Источник:
`projects/pylzt/src/pylzt/models/market/category_discord_item_seller.py`.

## Гарантия на лот: тип неизвестен, потому что живых образцов не было

Ловушка: если поле в 100% живых образцов приходит `null` — это не значит,
что нужный тип угадан верно, это значит, что тип **не проверен вообще**.

`endDate`, `active`, `cancelled`, `remainingTime` внутри `guarantee`
объявлены в спеке как обязательный `str`. В живой выборке (2026-07-05,
категории BattleNet и Steam, по 40 лотов) все четыре поля были `null` на
каждом листинге — ни один лот с активной гарантией не попался. Базовый
тип оставлен `str` как есть, потому что подтвердить его нечем.

Источник: `projects/pylzt/src/pylzt/models/market/item_guarantee.py`.

Отдельно: формат самого поля `guarantee` на купленном лоте (не категорийном
листинге) не документирован вовсе. Код, который следит за истечением
гарантии, обращается с ним как с непрозрачной строкой: всё, что не похоже
на ISO-8601, трактуется как "нечего отслеживать", а не как ошибка формата.

Источник: `projects/eventus/src/lzt_eventus/sources/guarantee.py`.

## Лидерборд чатбокса — семь полей, которые есть не у всех

Ловушка: поле отсутствует не потому что сервер его не считает, а потому
что у аккаунта просто нет соответствующей настройки.

Живой снимок `/chatbox/messages/leaderboard` (2026-07-05) показывает:
`avatar_date`, `background_date`, `custom_title`, `display_style_group_id`,
`uniq_banner`, `uniq_username_css`, `short_link` — отсутствуют или `null`
у аккаунтов без аватара / фона / кастомного тайтла / баннера / короткой
ссылки на профиль. Спецификация объявляет все семь обязательными.

Источник: `projects/pylzt/src/pylzt/models/forum/leaderboard.py`.
