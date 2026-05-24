# BidStage

> Премиум-аукцион билетов на концерты, VIP-столы, спортивные события и бэкстейдж-моменты в реальном времени.

Платформа для прямых торгов между владельцами редких билетов и фанатами. Каждая ставка верифицируется через шару в соцсети, защита покупателя реализована через эскроу, антиснайпинг продлевает торги в последние минуты.

---

## Содержание

- [Что есть в проекте](#что-есть-в-проекте)
- [Стек](#стек)
- [Быстрый запуск](#быстрый-запуск)
- [Структура репозитория](#структура-репозитория)
- [Переменные окружения](#переменные-окружения)
- [Архитектура](#архитектура)
- [Бизнес-логика](#бизнес-логика)
- [API](#api)
- [WebSocket-события](#websocket-события)
- [База данных](#база-данных)
- [PWA и оффлайн](#pwa-и-оффлайн)
- [Темизация](#темизация)
- [Скрипты сидинга](#скрипты-сидинга)
- [Деплой](#деплой)

---

## Что есть в проекте

**Главное**
- Аукционы с таймером, антиснайпингом, прокси-ставками (автоматическая перебивка до максимума)
- Каскад платежей: не оплатил — лот переходит ко второму биддеру
- Эскроу: деньги удерживаются до подтверждения получения билета
- Шеринг-протокол: каждая ставка должна сопровождаться публичным постом со ссылкой
- Чат с продавцом, чат с поддержкой (бот BidStage)
- Уведомления в шапке + persistent toasts на действия

**Каталог**
- Bento-сетка 16-колоночная с разными размерами карточек (XL/L/M/S/XS), подбор случайным алгоритмом
- Карусель «Топ» (featured-лоты) с 3D-эффектом и snap-листанием
- Категорийные табы (Все, Горящие, Концерты, VIP, Столы) с горячей фильтрацией
- Кнопка «Развернуть на весь экран» для каталога
- Глобальный поиск с авто-комплитом + фильтрами (категория, ценовой диапазон)

**PWA и мобилка**
- Service Worker с офлайн-кэшем
- Manifest для установки на главный экран
- Push-уведомления (инфраструктура готова, отправка опционально)
- Sticky bottom bar на странице лота с большой CTA «Сделать ставку»
- Pull-to-refresh на главной
- Native share через `navigator.share()` (с fallback на clipboard)
- Полноэкранный мобильный поиск с фильтрами
- Безопасные зоны (notch на iPhone), модалки выезжают снизу

**Страницы**
- `/` — каталог + hero + карусель «Топ»
- `/lot/<id>` — детальная страница лота с табами «Ставки/Топ/Лента/График»
- `/me` — профиль: баланс, мои ставки, watchlist, эскроу-платежи, способы оплаты
- `/sell` — выставление лота
- `/seller/<id>` — публичный профиль продавца
- `/chats` — мессенджер с чатами по лотам
- `/notifications` — лента уведомлений
- `/hall-of-fame` — зал славы (подиум, награды, топ-листы, битва дня)
- `/how-it-works` — подробная инструкция с FAQ
- `/auth/login`, `/auth/register`, `/auth/dev` — вход
- `/offline` — офлайн-страница

**Интеграции**
- Stripe / YooKassa / IDram (по стране пользователя)
- ExchangeRate API (курсы AMD/RUB/USD с кэшем 1 час)
- VK OAuth, опционально VK API для верификации шары

**Темизация**
- Тёмная (по умолчанию) и светлая темы
- Сохранение в `localStorage` без вспышки при загрузке
- Полный набор переопределений для всех компонентов

---

## Стек

| Слой | Технология |
|---|---|
| Backend | Python 3.10+, Flask, Flask-SocketIO |
| База | PostgreSQL 14+ через `psycopg2` |
| Фронт | Jinja2 + Tailwind (CDN) + кастомный CSS |
| Realtime | Socket.IO (threading async mode) |
| Шедулер | APScheduler (фон, проверка истёкших лотов и каскада) |
| PWA | Service Worker, manifest |
| Иконки | Iconify (Lucide) |
| Шрифты | Inter, Syne, JetBrains Mono, DM Mono (Google Fonts) |

---

## Быстрый запуск

```bash
# 1. Клон + зависимости
git clone <repo>
cd BidStage
pip install -r requirements.txt

# 2. .env (пример в .env.example)
# Минимум:
#   DATABASE_URL=postgresql://user:pass@host/db
#   SECRET_KEY=<random>

# 3. Запуск
python app.py
# или (Windows)
py app.py
```

Сервер поднимется на `http://0.0.0.0:5000`. Первая загрузка создаст все таблицы автоматически (через `_bootstrap_database` в `app.py`).

### Заполнить тестовыми данными

```bash
py seed_lots.py            # 14 базовых лотов
py seed_bids.py            # 8 demo-юзеров и 23 ставки
py seed_internet_lots.py   # лоты с реальными картинками из picsum.photos
```

### Войти как demo-юзер

Открой `/auth/dev` и выбери одного из подготовленных пользователей: `demo_anna` (AM), `demo_boris` (RU), `demo_carl` (US), и т.д.

---

## Структура репозитория

```
BidStage/
├─ app.py                  # точка входа: Flask + SocketIO + BG-шедулер
├─ routes.py               # все HTTP роуты (94 KB, ~80 эндпоинтов)
├─ models.py               # SQL-функции: lots, bids, payments, watchlist, push, hall_of_fame
├─ payments.py             # эскроу, каскад, верификация шары через HTTP
├─ notify.py               # уведомления + bot-сообщения в чате
├─ socket_events.py        # WebSocket: подключения, broadcast, viewers
├─ currency.py             # курсы валют с кэшем
├─ smart_search.py         # поиск с fuzzy-matching и ранжированием
├─ translator.py           # i18n
├─ vk_auth.py              # OAuth через ВКонтакте
│
├─ seed_lots.py            # сид 14 базовых лотов
├─ seed_bids.py            # сид demo-юзеров и ставок
├─ seed_internet_lots.py   # сид с картинками из picsum.photos
│
├─ static/
│  ├─ css/main.css         # ~4000 строк: hero, каталог, карусель, темы, мобилка
│  ├─ js/main.js           # клиентская логика (i18n, валюты, тосты, сокеты, авто-обновление цен)
│  ├─ sw.js                # Service Worker (PWA)
│  ├─ manifest.webmanifest # PWA-манифест
│  ├─ icon-192.png, icon-512.png, apple-touch-icon.png
│  └─ lot_images/          # загружаемые/посеянные картинки лотов
│
├─ templates/
│  ├─ base.html            # шапка, сайдбар, футер, темы, поиск, тосты
│  ├─ index.html           # главная: hero + карусель + каталог
│  ├─ lot.html             # страница лота
│  ├─ auth_login.html, auth_register.html, dev_login.html
│  ├─ profile.html         # /me
│  ├─ sell.html            # /sell
│  ├─ seller.html          # /seller/<id>
│  ├─ chats.html           # мессенджер
│  ├─ notifications.html
│  ├─ hall_of_fame.html
│  ├─ how_it_works.html
│  └─ offline.html
│
├─ requirements.txt
├─ amvera.yml              # деплой-конфиг (https://amvera.ru/)
├─ .replit, replit.nix     # конфиг для Replit
├─ bidstage_dump.sql       # дамп БД (опционально)
└─ .env.example
```

---

## Переменные окружения

Минимум для запуска:

```
DATABASE_URL=postgresql://user:pass@host:5432/dbname
SECRET_KEY=<random_64_chars>
```

Дополнительно (опционально):

```
# Курсы валют (без ключа будет fallback AMD=390, RUB=90)
EXCHANGERATE_API_KEY=<key from https://exchangerate-api.com>

# VK OAuth
VK_CLIENT_ID=<vk app id>
VK_CLIENT_SECRET=<vk secret>

# Дев-режим — пропустить проверку шары и OTP (для тестов)
VK_AUTO_VERIFY=1            # любая ставка засчитывается без HTTP-проверки
BID_OTP_DISABLED=1          # без OTP-кода

# Платёжные провайдеры (для прода)
STRIPE_SECRET_KEY=...
YOOKASSA_SHOP_ID=...
YOOKASSA_SECRET_KEY=...
IDRAM_MERCHANT_ID=...

# Web Push (опционально, для пушей)
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
VAPID_CLAIMS_SUB=mailto:you@example.com

# HTTPS local (необязательно)
USE_HTTPS=0
HOST=0.0.0.0
PORT=5000
```

Полный список — в `.env.example`.

---

## Архитектура

### Запрос -> ответ

```
Browser
   │ HTTPS
   ▼
Flask (app.py)
   │
   ├─ routes.py        ─► HTTP endpoints (auth, lots, bids, payments, search, notifications)
   ├─ socket_events.py ─► WebSocket (подключения, broadcast, viewers count)
   │
   └─ Background:
       APScheduler ───► payments.end_expired_lots         (каждые 30 сек)
                  └──► payments.cascade_expired_payments  (каждые 30 сек)
       
       Threads ───────► payments.verify_share              (после каждой ставки, ~60с)
```

### Жизненный цикл ставки

1. Пользователь жмёт «Сделать ставку» в `lot.html`
2. Открывается модалка → ввод суммы + ссылки на пост + OTP
3. `POST /api/bid` (routes.py) валидирует, создаёт `bids` запись с `share_verified=FALSE`
4. Сразу запускается `payments.schedule_share_verification(bid_id, share_url)` — `threading.Timer` через 60 сек
5. По истечении: `verify_share` идёт HTTP-запросом на сам пост, ищет в HTML подстроку `/lot/<id>`
6. Если найдено: `share_verified=TRUE`, broadcast `new_bid` через WebSocket всем смотрящим лот
7. Если не найдено: 3 ретрая → `_reject_bid()` → ставка отменена

### Жизненный цикл лота

```
created (active)
   │
   │ end_time приближается → payments.end_expired_lots проверяет каждые 30 сек
   ▼
ended → если есть winner → создаётся payment (24 часа на оплату)
                         │
                         │ payments.cascade_expired_payments каждые 30 сек
                         │
   ┌─────────── оплачено ──────────┐         не оплачено
   │                               │              │
   ▼                               │              ▼
payment.status='paid'              │      переход ко 2-му биддеру (каскад)
   │                               │              │
   │ продавец отправил билет       │              ▼
   ▼                               │      каскад исчерпан →
ticket_delivered=TRUE              │      лот в статус 'cancelled'
   │                               │      (auto-relist через 24 часа)
   │ покупатель подтвердил         │
   ▼                               │
buyer_confirmed=TRUE               │
   │                               │
   ▼                               │
released_to_seller=TRUE            │
(деньги ушли продавцу минус 10%)   │
                                   │
                                ничего не оплатили никогда
                                   │
                                   ▼
                            cancelled (relist через 24 часа)
```

---

## Бизнес-логика

### Антиснайпинг

Если ставка сделана в **последние 3 минуты** до конца торгов — таймер автоматически продлевается на **180 секунд**. Реализация в `routes.py:_execute_bid_transaction`:

```python
if (end_time - now).total_seconds() < 180:
    new_end_time = now + timedelta(seconds=180)
    # broadcast 'timer_extended'
```

### Прокси-ставки (автоставка)

В модалке ставки можно переключиться в режим «Авто». Указывается максимум, и система сама перебивает соперников на минимальный шаг при каждой их новой ставке.

Хранится в таблице `proxy_bids`. При новой ставке `payments.try_proxy_rebid` проверяет, есть ли активный proxy и перебивает.

### Каскад платежей

Если победитель не оплатил за 24 часа — `payments.cascade_expired_payments` (запускается шедулером каждые 30 сек):

1. Помечает текущий payment как `cancelled`
2. Находит следующего по сумме биддера (`share_verified=TRUE`)
3. Создаёт ему новый payment
4. Шлёт уведомление в чат с поддержкой и тост

Если каскад исчерпан — лот идёт на повторное выставление.

### Эскроу

Деньги удерживаются на эскроу-балансе платформы:
- При ставке: блокировка на балансе пользователя
- При победе и оплате: деньги уходят на эскроу-аккаунт
- Только после `buyer_confirmed=TRUE` (покупатель подтвердил билет): деньги перечисляются продавцу минус 10% комиссии

### Шеринг-проверка

`payments.verify_share` через HTTP-парсинг:

1. Проверяет белый список доменов (VK, Telegram, X, FB, OK, Instagram, LinkedIn, Reddit, Pinterest)
2. Делает GET-запрос с браузерным User-Agent
3. Ищет в HTML подстроку `/lot/<id>` (case-insensitive)
4. Если есть — ставка зачтена; если нет/404/удалён пост — отклонена

В dev-режиме `VK_AUTO_VERIFY=1` отключает Шаг 2.

### Дедуп уведомлений

`notify.insert_notification` не создаёт повторное уведомление, если у юзера уже есть **непрочитанное** уведомление того же `kind` по тому же `lot_id` за последний час. Это защищает от шедулерных дублей.

---

## API

Краткий справочник. Полные сигнатуры — в `routes.py`.

### Публичные

| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Главная: hero + карусель + каталог |
| GET | `/lot/<id>` | Страница лота |
| GET | `/seller/<id>` | Профиль продавца |
| GET | `/hall-of-fame`, `/how-it-works`, `/offline` | Статика |
| GET | `/api/lots?status=active|ended|upcoming` | JSON список лотов |
| GET | `/api/search?q=&cat=&max_price=&min_price=` | Поиск с фильтрами |
| GET | `/api/lot/<id>/live` | Текущая цена + таймер для анимации |
| GET | `/api/lot/<id>/viewers` | Сколько сейчас смотрят |
| GET | `/api/online` | Сколько онлайн всего |
| GET | `/api/rates` | Курсы AMD/RUB/USD |
| GET | `/sw.js`, `/manifest.webmanifest` | PWA |

### Авторизация

| Метод | Путь | Описание |
|---|---|---|
| GET | `/auth/login`, `/auth/register`, `/auth/dev` | Страницы |
| POST | `/api/auth/login`, `/api/auth/register` | JSON логин/регистрация |
| POST | `/auth/dev/login` | Демо-вход без пароля |
| GET | `/auth/vk`, `/auth/vk/callback` | OAuth ВКонтакте |
| POST | `/auth/logout` | Выход |

### Лоты и ставки (требуют сессии)

| Метод | Путь | Описание |
|---|---|---|
| POST | `/api/bid` | Сделать ставку (с OTP) |
| POST | `/api/lot/<id>/proxy-bid` | Автоставка с максимумом |
| POST | `/api/lot/<id>/watch` | Toggle подписки |
| GET | `/api/lot/<id>/watch` | Статус подписки |
| POST | `/api/lots/create` | Создать лот (продавец) |
| POST | `/api/lot/<id>/image` | Загрузить картинку (только продавец) |
| GET/POST | `/api/lot/<id>/chat` | Чат с продавцом |
| POST | `/api/translate` | Перевести текст |

### Платежи и эскроу

| Метод | Путь | Описание |
|---|---|---|
| POST | `/api/balance/topup` | Пополнение баланса |
| POST | `/api/payments/<id>/pay-with-card` | Оплата картой |
| POST | `/api/payments/<id>/pay-with-balance` | Оплата с баланса |
| POST | `/api/payment/<id>/deliver-ticket` | Продавец отправляет билет |
| POST | `/api/payment/<id>/confirm-delivery` | Покупатель подтверждает получение |
| POST | `/api/seller/<id>/review` | Отзыв продавцу |

### Карты

| Метод | Путь | Описание |
|---|---|---|
| GET | `/api/cards` | Список карт |
| POST | `/api/cards` | Добавить |
| DELETE | `/api/cards/<id>` | Удалить |
| POST | `/api/cards/<id>/default` | Сделать основной |

### Уведомления

| Метод | Путь | Описание |
|---|---|---|
| GET | `/api/notifications?unread=1&limit=20` | Список |
| POST | `/api/notifications/<id>/read` | Прочитать одно |
| POST | `/api/notifications/read-all` | Прочитать все |
| GET | `/api/chat/unread` | Счётчик непрочитанных чатов |

### Push (PWA)

| Метод | Путь | Описание |
|---|---|---|
| GET | `/api/push/vapid-public-key` | Публичный ключ |
| POST | `/api/push/subscribe` | Подписка устройства |
| POST | `/api/push/unsubscribe` | Отписка |

### Webhooks (платёжные провайдеры)

| Метод | Путь | Описание |
|---|---|---|
| POST | `/webhook/stripe` | Stripe events |
| POST | `/webhook/yookassa` | YooKassa события |
| POST | `/webhook/idram` | IDram callback |

---

## WebSocket-события

Сервер отправляет:

| Событие | Когда | Payload |
|---|---|---|
| `new_bid` | Новая подтверждённая ставка | `{lot_id, amount_usd, username, user_id}` |
| `timer_extended` | Антиснайпинг продлил таймер | `{lot_id, new_end_time, extension_seconds}` |
| `auction_ended` | Лот завершён | `{lot_id, winner_id, final_price}` |
| `chat_message` | Сообщение в чате | `{lot_id, sender_id, sender_username, recipient_id, message, created_at}` |
| `notification_new` | Новое уведомление | `{id, kind, title, body, lot_id, created_at}` |
| `viewers_changed` | Кто-то зашёл/вышел из лота | `{lot_id, count}` |

Клиент шлёт:

| Событие | Когда |
|---|---|
| `join_lot` | Зашёл на страницу лота (для viewers count) |
| `leave_lot` | Покинул страницу лота |

---

## База данных

Основные таблицы (создаются автоматически при первом старте через `app.py:_bootstrap_database`):

```
users           — пользователи (id, username, email, password_hash, country, balance_usd)
lots            — лоты (id, seller_id, title, artist, status, end_time, start_price, ...)
bids            — ставки (id, lot_id, user_id, amount_usd, share_verified, share_url)
proxy_bids      — автоставки (lot_id, user_id, max_amount, share_url)
payments        — эскроу (id, bid_id, user_id, status, amount_usd, held_in_escrow, ticket_code)
payment_methods — карты (id, user_id, brand, last4, is_default)
watchlist       — подписки на лоты
lot_chats       — сообщения чата
notifications   — уведомления
lot_events      — лог событий лота (для feed-ленты)
reviews         — отзывы о продавцах
otp_codes       — одноразовые коды для подтверждения ставок
push_subscriptions — Web Push подписки
```

Все `ensure_*_table` функции в `models.py` используют `CREATE TABLE IF NOT EXISTS` и идемпотентны.

---

## PWA и оффлайн

### Установка

Сайт регистрирует Service Worker (`sw.js`) при загрузке. Когда браузер посчитает, что условия PWA выполнены, он покажет нативное меню «Установить приложение». Также есть кнопка в сайдбаре «Установить приложение» (появляется когда Chrome шлёт `beforeinstallprompt`).

### Кэш-стратегии

- **Статика** (`/static/*`) — cache-first. Кэш `bs-static-<version>`.
- **Навигация** (HTML-страницы) — network-first с фолбэком на кэш или `/`.
- **API** (`/api/*`, `/auth/*`, `/socket.io/*`) — всегда сеть, не кэшируется.

### Версионирование

В `static/sw.js` константа `VERSION = 'bs-v1.0.3'`. При изменении версии старые кэши автоматически удаляются на `activate`.

### Обновление SW

`navigator.serviceWorker.register` + `setInterval(reg.update, 30 * 60 * 1000)` — проверяем обновления каждые 30 минут.

---

## Темизация

Тёмная — по умолчанию. Светлая включается через атрибут `<html data-theme="light">`. Состояние сохраняется в `localStorage['bs.theme']`.

В `<head>` есть **no-flash bootstrap**:

```html
<script>
  try {
    var t = localStorage.getItem('bs.theme') || 'dark';
    document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
</script>
```

Это применяется до отрисовки `<body>`, поэтому нет вспышки чёрным при загрузке светлой темы.

CSS-переменные:

```
--bg, --bg-elevated, --card
--primary, --primary-strong, --primary-dim
--secondary
--success, --danger
--text-main, --text-muted, --text-faint
--border, --border-strong
--glow-violet, --glow-amber, --glow-gold
--status-live, --status-active, --status-ended
```

Каждая компонента в `main.css` имеет блок `:root[data-theme="light"]` со своими override'ами.

---

## Скрипты сидинга

```bash
# Базовый набор: 14 лотов разных типов
py seed_lots.py

# Демо-юзеры (8 шт) + 23 ставки разных сумм
py seed_bids.py

# Лоты с реальными картинками из picsum.photos
py seed_internet_lots.py --count 12 --keep-existing

# Опции seed_internet_lots.py:
#   --count N         сколько лотов создать (по умолчанию 12)
#   --no-bids         без сидинга ставок
#   --keep-existing   не удалять существующие лоты
#   --seed N          фикс seed для воспроизводимости
```

---

## Деплой

### Amvera

Файл `amvera.yml` уже настроен. Создай проект, подключи репозиторий, добавь env переменные через панель.

### Replit

Файлы `.replit` и `replit.nix` настроены под автозапуск `python app.py`.

### Любая VPS

```bash
# Запустить через gunicorn (поддерживает SocketIO через eventlet)
pip install gunicorn eventlet
gunicorn -k eventlet -w 1 -b 0.0.0.0:8000 app:app
```

Для production-режима поставь Nginx перед Flask, проброс `/socket.io/*` к gunicorn, статику обслуживай прямо из Nginx.

---

## Подробные гайды

См. `docs/`:
- `docs/ARCHITECTURE.md` — деталь по слоям
- `docs/BUSINESS_LOGIC.md` — правила, антиснайпинг, каскад, эскроу
- `docs/FRONTEND.md` — структура CSS, темы, мобилка
- `docs/DEVELOPMENT.md` — как запустить локально, как добавить фичу

---

## Лицензия

Проприетарная (демо-проект). Все логотипы, шрифты, иконки — собственность их правообладателей.

---

## Контакты

Bug-репорты, фичи и вопросы — в issue tracker репозитория или в чат поддержки `@bidstage_support` внутри платформы.
