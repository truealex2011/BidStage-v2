# Архитектура BidStage

## Слой за слоем

### 1. Точка входа — `app.py`

```python
app = create_app()              # Flask с blueprint routes
socketio = create_socketio(app) # Socket.IO поверх Flask
_bootstrap_database()           # CREATE TABLE IF NOT EXISTS для всех таблиц
scheduler = _start_scheduler()  # APScheduler в фоне
```

Шедулер запускает 2 задачи каждые 30 секунд:
- `payments.end_expired_lots` — закрывает истёкшие лоты, создаёт payment'ы для победителей
- `payments.cascade_expired_payments` — переключает каскад если победитель не оплатил

### 2. HTTP — `routes.py`

Один большой blueprint `bp = Blueprint('main', __name__)`. Около 80 эндпоинтов разделены на группы:

| Префикс | Что |
|---|---|
| `/` `/lot/*` `/seller/*` | Публичные страницы |
| `/me` `/sell` `/chats` | Залогиненные страницы |
| `/auth/*` | Авторизация |
| `/api/*` | JSON API |
| `/webhook/*` | Платёжные провайдеры |
| `/sw.js` `/manifest.webmanifest` | PWA |

### 3. Данные — `models.py`

Тонкий слой над `psycopg2`. Все функции получают `conn` снаружи (управление транзакциями — у вызывающего):

```python
def get_lot(conn, lot_id): ...
def insert_bid(conn, lot_id, user_id, amount, share_url): ...
def hall_of_fame(conn): ...
```

Каждая `ensure_*_table` функция идемпотентна (`CREATE TABLE IF NOT EXISTS`), вызывается из `_bootstrap_database` при старте и точечно из роутов на всякий случай.

### 4. Платежи и шара — `payments.py`

Содержит:
- `verify_share()` — асинхронная проверка поста через HTTP
- `_accept_bid()`, `_reject_bid()` — финализация ставок
- `end_expired_lots()` — фоновая закрытие лотов
- `cascade_expired_payments()` — каскад
- Эскроу-операции (списание/возврат)
- Интеграция со Stripe/YooKassa/IDram

### 5. Уведомления — `notify.py`

```python
def insert_notification(user_id, kind, title, body, lot_id=None, payment_id=None)
```

Дедуп по `(user_id, kind, lot_id)` за последний час — не плодим дубли при шедулере. После INSERT'а отправляется WebSocket-событие `notification_new`.

### 6. WebSocket — `socket_events.py`

```python
@socketio.on('connect')
def on_connect(): ...     # привязываем session к sid

@socketio.on('join_lot')
def on_join_lot(data): ...# счётчик viewers per lot

emit_to_user(user_id, event, payload)
emit_to_lot(lot_id, event, payload)
```

Async-режим: `threading` (по умолчанию). Можно переключить на `eventlet` для прода.

### 7. Поиск — `smart_search.py`

Кастомный fuzzy-matching с весами:
- Точное совпадение в `title` × 100
- Совпадение в `artist` × 50
- Левенштейн < 2 символов × 30
- Bigram-overlap × 10

Результат сортируется по убыванию веса. Если ничего не найдено — fallback на ILIKE через `models.quick_search_lots`.

### 8. Курсы валют — `currency.py`

Обращение к `exchangerate-api.com`. Кэш 1 час в памяти процесса (`threading.Lock`). Fallback `AMD=390, RUB=90` при недоступности API.

### 9. i18n — `translator.py`

Серверный кеш переводов. Эндпоинт `/api/translate` принимает текст и язык, возвращает кэшированный или свежий перевод.

### 10. Фронтенд

**Шаблоны Jinja2** наследуются от `base.html`:
- header (логотип, поиск, колокольчик, баланс)
- сайдбар (бургер-меню) с настройками
- подложка (gradient-mesh)
- блок `{% block content %}{% endblock %}`
- футер
- глобальные скрипты: SW регистрация, тема, поиск, нотификации

**`static/js/main.js`** — клиентская логика:
- i18n словари RU/HY/EN
- переключение валют (с пересчётом всех `[data-price-usd]` элементов)
- `bidstageToast()` — flash уведомления
- Socket.IO подключение
- авто-обновление таймеров и цен на странице лота
- `LotCarousel` — 3D-карусель Топ

**`static/css/main.css`** — ~4000 строк:
- Базовые токены (CSS variables)
- Хедер, сайдбар, нотификации
- Hero-секция, карусель, bento-каталог
- Страница лота, модалка ставки
- Auth-страницы
- Чаты, профиль, sell, hall, how
- Темы (светлая)
- Мобильные правила (`@media (max-width: 767px)`)

---

## Критические потоки

### Сценарий: пользователь делает ставку

```
1. Browser:    клик «Сделать ставку» → открывается модалка
2. Browser:    POST /api/bid с {lot_id, amount, share_url, otp_code}
3. routes.py:  api_bid()
4.   ↳ _is_valid_share_url()      — синхронная проверка домена
5.   ↳ models.consume_otp_code()  — проверка OTP (одноразовый)
6.   ↳ _execute_bid_transaction()
7.     ↳ models.lock_lot(conn, lot_id)  — SELECT FOR UPDATE
8.     ↳ models.insert_bid(...)         — share_verified=FALSE
9.     ↳ если в последние 3 мин: продлеваем end_time на 180с
10.    ↳ commit
11. payments.schedule_share_verification(bid_id, share_url)
    ↳ threading.Timer(60, verify_share, args=(bid_id, share_url)).start()
12. socket_events.emit_to_lot(lot_id, 'new_bid', payload)
13. routes.py возвращает {bid_id, share_verified: False}

— через 60 секунд —

14. payments.verify_share(bid_id, share_url):
15.   ↳ _is_supported_share_host(url)   — белый список
16.   ↳ requests.get(url, headers=BROWSER)
17.   ↳ if expected_path in body.lower():
18.       ↳ _accept_bid(bid_id) → share_verified=TRUE
19.       ↳ socket emit 'new_bid' с verified=True
20.     else:
21.       ↳ retry 1с/5с/30с или _reject_bid()
```

### Сценарий: лот заканчивается

```
APScheduler (каждые 30с):
1. payments.end_expired_lots()
2.   ↳ SELECT id FROM lots WHERE status='active' AND end_time < NOW()
3.   ↳ для каждого:
       ↳ models.lock_lot(...)
       ↳ найти топ ставку с share_verified=TRUE
       ↳ если есть → status='ended', winner_id=top_user
       ↳ models.create_payment(bid_id, ...)
       ↳ notify.notify_event(winner_id, 'lot_won', ..., send_chat=True)
       ↳ socket emit 'auction_ended' to lot room
       ↳ если ставок не было → status='ended', winner=NULL, лот будет relist через 24 часа
```

### Сценарий: каскад платежей

```
APScheduler (каждые 30с):
1. payments.cascade_expired_payments()
2.   ↳ SELECT payments WHERE status='awaiting_payment' AND created_at + 24h < NOW()
3.   ↳ для каждого:
       ↳ status='cancelled', освобождаем эскроу
       ↳ ищем следующего биддера (по убыванию суммы, share_verified=TRUE)
       ↳ если есть → создаём новый payment, уведомление
       ↳ если каскад исчерпан → лот status='cancelled', relist
```

---

## Ограничения и особенности

### Single-process модель

Сейчас всё крутится в одном процессе Flask (dev-сервер). Шедулер — APScheduler в фоне этого же процесса. Это норм для демо/MVP, но в проде с несколькими воркерами:
- шедулер должен крутиться в одном leader-воркере
- состояние сокетов синхронизируется через Redis (`flask_socketio.SocketIO(message_queue='redis://...')`)

### Threading vs Eventlet

В dev — `threading` mode (по умолчанию). Простой, но блокирующий I/O в WebSocket-обработчиках уберёт всех клиентов. В проде — `eventlet`/`gevent`.

### БД-локи

При новой ставке делается `SELECT ... FOR UPDATE` в `models.lock_lot`. Это сериализует ставки на один лот, защищая от race-condition (две одновременные ставки видят одинаковую цену и вставляют одинаковую сумму).

### Безопасность

- CSRF: не используем (демо). В проде — Flask-WTF.
- XSS: Jinja2 escape по умолчанию + `escapeHtml` на клиенте для всего user-input.
- SQL injection: только параметризованные запросы через `psycopg2`.
- Rate limit: нет. В проде — nginx или `flask-limiter`.

---

## Зависимости

`requirements.txt`:

```
Flask
Flask-SocketIO
psycopg2-binary
APScheduler
python-dotenv
requests
Pillow
```

Версии в `.env.example` или фиксированные в lock-файле.
