# Фронтенд BidStage

## Стек на стороне клиента

- **Tailwind CSS** через CDN (для утилитарных классов)
- **Кастомный CSS** в `static/css/main.css` (~4000 строк)
- **Iconify** через CDN (Lucide иконки)
- **Vanilla JS** (никаких фреймворков, всё через `addEventListener` и IIFE)
- **Socket.IO client** для realtime
- **Service Worker** для PWA

Без бандлеров, без сборки. Прямая отдача файлов из `static/`.

---

## Структура CSS

`main.css` разбит на смысловые секции:

```
0. CSS-переменные (тёмная тема по умолчанию)
1. Базовая типографика, скроллбары, scanline
2. cyber-card (clip-path-карточка с скошенными углами)
3. Кнопки (.btn .btn-violet .btn-amber .btn-ghost .btn-outline)
4. Pills (.pill .pill-violet .pill-amber-soft .pill-success ...)
5. Хедер (.bs-header)
6. Сайдбар (.bs-sidebar, .bs-sidebar-prefs)
7. Колокольчик и уведомления
8. Поиск (.bs-search-*)
9. Модалка (.modal-overlay, .modal-card)
10. Hero (.hero-stage, .hero-bid-card)
11. Карусель «Топ» (.carousel-track, .lot-card-snap)
12. Bento-каталог (.lot-mosaic, .lot-card-mosaic)
13. Cat-tabs (.cat-tab, .cat-fs-btn)
14. Страница лота (.lot-hero, .lot-bid-card, #lot-tabs)
15. Чаты (.bs-messenger, .bs-chat-row, .bs-msg)
16. Auth-страницы (.auth-card, .auth-side)
17. Hall of fame (.hall-podium, .hall-award, .hall-list)
18. Toast (.bs-toast-persistent)
19. PWA (.bs-install-btn)
20. Pull-to-refresh (.bs-ptr-indicator)
21. Mobile (большой блок @media (max-width: 767px))
22. Светлая тема (:root[data-theme="light"] для каждого компонента)
```

---

## Темы

### Активация

`<html data-theme="light">` или `data-theme="dark"`. Дефолт — `dark`.

### No-flash bootstrap

В `<head>` до отрисовки:

```js
(function () {
  try {
    var t = localStorage.getItem('bs.theme') || 'dark';
    document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
})();
```

### Кнопка переключения

Две точки управления:
- На desktop — кнопка в шапке (`#bs-theme-toggle`)
- На mobile — в сайдбаре, блок «Настройки» (`#bs-sidebar-theme-toggle`)

Обе кнопки синхронизированы одним IIFE в `base.html`.

### CSS-переменные

```css
:root {
  --bg: #0a0a0f;          /* фон страницы */
  --bg-elevated: #11111c; /* подложка карточек */
  --card: rgba(...);
  --primary: #7c5cfc;     /* фиолетовый */
  --primary-strong: ...;
  --secondary: #f0a500;   /* золотой */
  --success: #00c896;
  --danger: #ff4d6d;
  --text-main: #fff;
  --text-muted: rgba(255, 255, 255, 0.62);
  --text-faint: rgba(255, 255, 255, 0.42);
  --border: rgba(255, 255, 255, 0.08);
  --glow-violet: rgba(124, 92, 252, 0.45);
  --glow-amber: rgba(240, 165, 0, 0.45);
  --glow-gold: rgba(240, 165, 0, 0.45);
  --status-live: #ff4757;
  --status-active: #2ed573;
  --status-ended: #747d8c;
}

:root[data-theme="light"] {
  --bg: #f5f3ee;
  --bg-elevated: #ffffff;
  --primary: #5a3edd;     /* чуть глубже для контраста */
  --secondary: #b87800;
  --text-main: #1d1d2b;
  ...
}
```

---

## Компоненты

### `.cyber-card`

Базовая карточка с скошенными углами через `clip-path: polygon(...)`. На светлой теме упрощается до прямоугольника с тонкой обводкой.

### `.hero-stage` (главная)

Большое превью лота слева, бид-карта справа. На мобиле — стек (одна колонка).

```html
<section class="hero-stage cyber-card">
  <img class="hero-stage-img" ...>
  <div class="hero-stage-grad"></div>
  <div class="hero-stage-vignette"></div>
  <div class="hero-stage-shine"></div>
  <h1 class="hero-stage-title">
    <span class="hero-stage-word-white">КОНЦЕРТ</span>
    <span class="hero-stage-word-gold">LINKIN</span>
    <span class="hero-stage-word-violet">PARK</span>
  </h1>
  ...
</section>
```

Трёхцветное разбиение слов через `.hero-stage-word-*` (белый/золотой/фиолетовый).

### `.lot-mosaic` (каталог)

Bento-сетка 16-колонок, каждая карточка получает класс `lot-card-{xl|l|m|s|xs}`. Размер задаёт `_assign_catalog_layout` в `routes.py`. На мобиле сетка превращается в одну колонку.

### `.lot-card-snap` (карусель «Топ»)

Гибкий снапп-скролл. На десктопе с 3D-перспективой, на мобиле просто горизонтальный свайп с `scroll-snap-align: center`.

### `.modal-overlay` + `.modal-card`

Центрирование на десктопе, slide-up снизу на мобиле:

```css
@media (max-width: 767px) {
  .modal-overlay { align-items: flex-end; padding: 0; }
  .modal-card {
    border-radius: 18px 18px 0 0;
    animation: modal-slide-up 0.28s cubic-bezier(0.32, 0.72, 0.18, 1.06);
  }
}
```

### `.lot-mobile-bar`

Sticky bottom-bar на странице лота на мобиле. Содержит цену + таймер + большую CTA-кнопку. При открытии любой модалки скрывается через `body.has-modal-open` (MutationObserver).

### `.bs-mobile-search-overlay`

Полноэкранный поиск на мобиле с фильтрами:
- Chip'ы категорий (Все/Горящие/Концерты/VIP/Столы)
- Слайдер «До $X»
- Список результатов

### `.bs-ptr-indicator`

Pull-to-refresh индикатор. Только на touch-устройствах. Триггер 80px, перезагрузка через 350мс.

---

## JavaScript-структура

### `static/js/main.js` (глобальный)

```js
// i18n словари
const I18N = { ru: {...}, en: {...}, hy: {...} };

// Переключение валют
window.bidstageSetCurrency('AMD'|'RUB'|'USD');

// Toast уведомления
window.bidstageToast(message, kind);  // kind: good|bad|warn

// Socket.IO
window.socket = io();

// Авто-обновление таймеров на странице
// (сканирует все .timer[data-target-time] каждую секунду)
```

### `base.html` inline-скрипты

```js
1. No-flash theme bootstrap (ASAP)
2. Theme toggle (header + sidebar sync)
3. Sidebar open/close
4. Global search dropdown (header)
5. Mobile search overlay
6. Bell dropdown (notifications)
7. Persistent toasts (push from socket)
8. Service Worker registration + install prompt
9. Native share helper (window.bidstageShare)
10. Modal vs sticky-bar coordination (MutationObserver)
```

### `index.html` inline-скрипты

```js
1. Lot carousel (3D перспектива)
2. Counter animation для метрик
3. Cat-tabs filter
4. Catalog fullscreen toggle
5. Dev win-now button
6. Pull-to-refresh
```

### `lot.html` inline-скрипты

```js
1. Bid modal lifecycle
2. Quick-bid buttons (+1 step, +3 steps, +5, +10)
3. Currency preview (AMD/RUB/USD live)
4. Auto-step timer
5. Watch toggle
6. Chat with seller
7. Live feed (WebSocket new_bid, timer_extended, auction_ended)
8. Time progress bar
9. Wave/animation на новой ставке
10. Mobile-bar padding-bottom
```

---

## Мобильные особенности

### Safe-area

`<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">` + CSS-переменные:

```css
:root {
  --safe-top: env(safe-area-inset-top, 0px);
  --safe-bottom: env(safe-area-inset-bottom, 0px);
}
body { padding-top: calc(60px + var(--safe-top)); padding-bottom: var(--safe-bottom); }
```

### Touch targets

Все интерактивные элементы ≥ 44×44 px при `pointer: coarse` (Apple HIG / Material). Hover-эффекты заменяются на `:active scale(0.97)`.

### `theme-color`

Меняет цвет статусбара браузера на iOS/Android:

```html
<meta name="theme-color" content="#0a0a0f" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#f5f3ee" media="(prefers-color-scheme: light)">
```

### `format-detection=telephone=no`

Чтобы цены не превращались в синие телефонные ссылки.

---

## PWA

### Manifest

`/manifest.webmanifest`:
- `display: standalone` — без браузерного chrome
- `orientation: portrait`
- 3 shortcuts (Каталог, Профиль, Чаты) — попадают в long-press по иконке приложения
- 3 иконки (192, 512, apple-touch)

### Service Worker

`/sw.js` (отдаётся из root через flask-роут с `Service-Worker-Allowed: /`):

- VERSION константа для инвалидации кэша
- 3 кеш-стратегии:
  - Static (`/static/*`) → cache-first
  - Navigate (HTML) → network-first с fallback
  - API → не кэшируется
- `push` event handler для нотификаций
- `notificationclick` → открывает соответствующий URL

### Install prompt

```js
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
  // Показать кнопку «Установить» в сайдбаре
});

window.bidstageInstallPWA = () => deferredPrompt?.prompt();
```

---

## Иконки

Везде Iconify через `<iconify-icon icon="lucide:NAME">`. Список используемых:

- `lucide:gavel` — молоток (логотип, ставки)
- `lucide:moon`, `lucide:sun` — тема
- `lucide:bell`, `lucide:bell-off` — уведомления, watch
- `lucide:search`, `lucide:x` — поиск, закрыть
- `lucide:wallet`, `lucide:credit-card` — баланс, карта
- `lucide:users`, `lucide:user-plus` — пользователи
- `lucide:crown`, `lucide:trophy`, `lucide:medal` — топ-биддеры
- `lucide:swords`, `lucide:flame`, `lucide:trending-up` — награды
- `lucide:share-2`, `lucide:arrow-up-right` — шара
- `lucide:menu`, `lucide:home`, `lucide:log-in`, `lucide:log-out`
- ...

Цвет иконки контролируется через `color: var(--secondary)` или Tailwind `text-amber`/`text-violet`.

---

## Шрифты

Через Google Fonts с подмножеством `cyrillic, cyrillic-ext, latin, latin-ext`:

- **Inter** — body text, основной
- **Syne** — заголовки, кнопки, премиальный акцент
- **JetBrains Mono** — цены, таймеры, моно-числа
- **DM Mono** — fallback для моно

```css
font-family: 'Inter', sans-serif;          /* default */
font-family: 'Syne', 'Inter', sans-serif;  /* heading */
font-family: 'JetBrains Mono', 'DM Mono', ui-monospace, monospace;
```

---

## Code style

- 2 пробела для отступов в HTML/CSS/JS
- `const`/`let` (не `var` кроме no-flash bootstrap)
- IIFE для изоляции скриптов в страницах
- Никаких внешних JS-зависимостей кроме Tailwind CDN, Iconify, Socket.IO client
