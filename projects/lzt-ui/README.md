# lzt-ui

Библиотека заготовок в визуальном языке LZT. Чистый CSS + 150 строк ванильного JS.
Без сборки, без зависимостей, без утилити-фреймворка.

Два способа потребления — один и тот же CSS:

```html
<!-- обычный HTML -->
<link rel="stylesheet" href="lzt-ui.css">
<script src="lzt-icons.js"></script>
<script src="lzt-ui.js"></script>
```

```tsx
// React — см. react/README.md
import '@open-lzt/ui/lzt-ui.css';
import { Button, Thread, ThemeProvider } from '@open-lzt/ui';
```

`react/` реализует поведение на хуках и **не** подключает `lzt-ui.js` — тот остаётся
для тех, кто пишет на голой разметке. Классы и токены общие, расхождений нет.

Тёмная тема по умолчанию. Светлая — `<html data-theme="light">` или кнопка с
`data-lzt-theme-toggle` (выбор сохраняется в `localStorage`).

## Демо

| Файл | Что показывает |
|---|---|
| `demo/index.html` | галерея всех компонентов и токенов |
| `demo/forum.html` | индекс форума — список тем, сайдбар, фильтры, модалка |
| `demo/thread.html` | страница темы — посты, цитаты, спойлеры, реакции |

Открываются двойным кликом, сервер не нужен.

## Язык дизайна

Палитра и приёмы сведены из двух источников — публичного стиля форума и
[Lolzteam-Launcher](https://github.com/iamextasy/Lolzteam-Launcher) (Electron + React).
Они сходятся на одном ядре, расходятся в мелочах:

| | Форум | Launcher | Взято в библиотеку |
|---|---|---|---|
| Акцент | `#00ba78` | `#00ba78` | `#00ba78` |
| Фон страницы | `rgb(20,20,20)` | тот же | `#0f0f10` (темнее оригинала) |
| Поверхности | 28 / 36 / 48 / 54 | те же | ровные ступени ~8 пунктов |
| Шрифт | Open Sans | Inter | Inter, Open Sans в fallback |
| Радиусы | 10 / 6 / 8 px | 10 / 12 / 6 | 4 / 6 / 10 / 14 / pill |
| Motion | `.1s–.2s ease-in-out` | `120ms cubic-bezier(.16,1,.3,1)` | оба: `--lzt-fast` + `--lzt-ease` |
| Иконки | шрифтовой сет | inline SVG | inline SVG, `currentColor` |

Что осознанно **не** перенесено: 95 keyframes-анимаций общего назначения
(bounce/flip/rollIn и прочий animate.css), радужный текст на каждом втором нике,
z-index до 50000. Оставлены только приёмы, которые действительно делают вид:

- **глубина хайрлайнами, а не тенями** — `box-shadow: 0 0 0 1px inset rgba(255,255,255,.12)`;
  тени только у всплывающего (меню, модалка, тост);
- **рипл на кнопке** — радиальный градиент, растянутый на 15000% и схлопываемый на `:active`;
- **активная вкладка** — `inset 0 -2px 0 0` акцентом, без border-bottom-скачков;
- **скелетон** — бегущий блик `--lzt-grad-sheen`, а не мигание прозрачностью;
- **фирменный градиент** — `88deg, #1c6946 → #329c6c → #1d8254` в шапке и прогрессе,
  анимированная версия `--lzt-grad-flow` для «идёт работа».

Один акцент на экран. Серая шкала несёт ~95% интерфейса.

## Иконки

67 линейных иконок в одном сете: сетка 24, обводка 2px, скруглённые концы,
`currentColor`. Живут в `lzt-icons.js` и инжектятся спрайтом в документ.

```html
<svg class="lzt-icon"><use href="#i-search"/></svg>
<svg class="lzt-icon lzt-icon--lg"><use href="#i-bell"/></svg>
```

Спрайт инжектится скриптом, а не лежит внешним `.svg`, потому что
`<use href="file.svg#id">` режется CORS на `file://` и с другого домена —
внешний спрайт молча не отрисовался бы. Галерея всех имён — в `demo/index.html`,
она строится из самого спрайта и не может разойтись с ним.

## Компоненты

**Каркас** — `lzt-shell`, `lzt-container`, `lzt-main`, `lzt-stack`, `lzt-row`,
`lzt-grid`, `lzt-divider`, `lzt-spacer`
**Навигация** — `lzt-topbar`, `lzt-logo`, `lzt-tabs`, `lzt-sidenav`,
`lzt-breadcrumb`, `lzt-pagenav`, `lzt-segmented`
**Действия** — `lzt-btn` (`--primary --danger --outline --ghost --gradient`,
`--sm --lg --icon --block`, `is-loading`), `lzt-btn-group`
**Формы** — `lzt-field`, `lzt-input`, `lzt-textarea`, `lzt-select`, `lzt-search`,
`lzt-check`, `lzt-switch`, `lzt-label`, `lzt-hint`
**Контейнеры** — `lzt-block` (+`__header __body __footer`), `lzt-card`, `lzt-stat`
**Данные** — `lzt-table`, `lzt-thread`, `lzt-post`, `lzt-quote`, `lzt-code`,
`lzt-spoiler`, `lzt-reactions`
**Метки** — `lzt-badge`, `lzt-tag`, `lzt-chip`, `lzt-avatar`
**Обратная связь** — `lzt-alert`, `lzt-toast`, `lzt-modal`, `lzt-menu`, `lzt-tip`,
`lzt-progress`, `lzt-loaderbar`, `lzt-spinner`, `lzt-dots`, `lzt-skeleton`, `lzt-empty`
**Эффекты** — `lzt-gradient-text`, `lzt-glow`, `lzt-enter`, `lzt-stagger`

## JS-хуки

Обработчики делегированные — размеченное позже работает без переинициализации.

| Атрибут | Действие |
|---|---|
| `data-lzt-theme-toggle` | переключить тему |
| `data-lzt-open="id"` | открыть `.lzt-overlay#id` |
| `data-lzt-close` | закрыть текущий оверлей |
| `data-lzt-dropdown` | раскрыть меню (остальные закрываются) |
| `data-lzt-toast="текст"` | показать тост, `data-lzt-toast-variant="danger\|warning"` |
| `data-lzt-tabs` / `data-lzt-panel` | вкладки и панели |

Программно: `lzt.toast(msg, variant)`, `lzt.openModal(id)`, `lzt.setTheme('light')`.

`Esc` закрывает модалки и меню. `prefers-reduced-motion` уважается.

## Шрифты

`lzt-ui.css` ждёт self-hosted Inter в `./fonts/` (`Inter-Regular.woff2`,
`-Medium`, `-SemiBold`, `-Bold`). Без них подхватится системный fallback —
вид останется рабочим, но метрики поедут. CDN-импорты не используются намеренно.

## Проверка

```bash
python check.py
```

Ловит несбалансированные блоки, классы в демо без определения в CSS,
`var()` без объявления, `<use>` без `<symbol>`, битые цели модалок.

## Правила, которые держат вид

Три из них нарушить проще всего, поэтому они записаны:

1. **Один акцент на экран.** Зелёный — только у главного действия и активного
   пункта навигации. Прогресс-бары, бейджи, закреплённые темы по умолчанию
   нейтральные; акцент включается явно (`lzt-progress--brand`).
2. **Разделять чем-то одним.** Либо заливка, либо волосяная линия, либо воздух —
   никогда двумя сразу. Тени только у всплывающих слоёв.
3. **Никаких пикселей в разметке.** Отступы берутся из шкалы (`lzt-g3`, `lzt-mt4`),
   `check.py` валит сборку на инлайн-`gap`/`margin`/`padding`.

## Статус

Заготовка под идею «UI-кит экосистемы»: тот же кит должен стать host-китом
панели (`TaskCard`, `Countdown`, `LimitBar`, `AccountPicker`), чтобы плагины
получали полировку даром. Сейчас это CSS-слой; React-обёртки и Storybook —
следующий шаг, когда появится второй реальный потребитель.
