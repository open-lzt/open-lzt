# Грабли API: токены, ключи, что значат коды ошибок

## AntiPublic — не тот же токен, что маркет и форум

Ловушка: раз это часть одной экосистемы lolzteam — можно предположить,
что один OAuth-токен открывает всё, включая проверку утечек.

AntiPublic (antipublic.one, сервис проверки паролей/утечек) авторизуется
**отдельным Bearer license-ключом**, который никак не взаимозаменяем с
OAuth-токеном маркета и форума. Нет ключа — нет доступа именно к
AntiPublic, при живом и рабочем токене маркета/форума.

Источник: `projects/pylzt/src/pylzt/client.py` (комментарий
"AntiPublic is never fungible with the market/forum fleet (a license key,
not an OAuth token)").

## `retry_request` — не код отказа, а команда повторить (см. timing.md)

Тот же факт, что и в `timing.md`, но со стороны кодов ошибок: `retry_request`
живёт в теле ответа как строка, а не как HTTP-статус — это одна из причин,
по которой его легко принять за обычную бизнес-ошибку и не повторить запрос.

Источник: `projects/pylzt/src/pylzt/errors.py` (`RetryableUpstream`).

## `429` — это `retry-after` в заголовке, не в теле

Rate-limit сервер сообщает статусом `429` и заголовком `Retry-After` —
именно оттуда, а не из тела ответа, нужно брать время ожидания перед
повтором.

Источник: `projects/pylzt/src/pylzt/errors.py` (`RateLimited.check`).
