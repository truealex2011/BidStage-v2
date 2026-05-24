# Разработка BidStage

## Локальная установка

### Требования

- Python 3.10+
- PostgreSQL 14+ (локальный или в облаке)
- Git

### Шаги

```bash
git clone <repo>
cd BidStage

# venv (рекомендуется)
python -m venv .venv
.\.venv\Scripts\Activate.ps1   # Windows PowerShell
# или
source .venv/bin/activate       # macOS/Linux

pip install -r requirements.txt

# .env
cp .env.example .env
# отредактируй DATABASE_URL и SECRET_KEY

# Запуск
python app.py
# или Windows
py app.py
```

Сервер слушает `http://0.0.0.0:5000`. Открой в браузере `http://localhost:5000`.

### Проверка установки

```bash
# Проверим, что все зависимости подтянулись
py -c "import flask, flask_socketio, psycopg2, dotenv, apscheduler, requests, PIL; print('ok')"
```

---

## Заполнение тестовыми данными

Скрипты сидинга:

```bash
# 1. Базовые лоты (14 шт)
py seed_lots.py

# 2. Демо-юзеры + ставки
py seed_bids.py

# 3. Лоты с реальными картинками
py seed_internet_lots.py --count 12 --keep-existing
```

После сидинга открой `/auth/dev` и войди под любым демо-пользователем (`demo_anna`, `demo_boris` и т.д.).

---

## Workflow разработки

### Что менять под какие задачи

| Задача | Файлы |
|---|---|
| Новая страница | `routes.py` (добавить роут), `templates/<name>.html`, `static/css/main.css` |
| Новый API | `routes.py`, иногда `models.py` для SQL |
| Новое поле в БД | `models.py` (ensure_*_table добавить ALTER), миграция через `_bootstrap_database` |
| WebSocket-событие | `socket_events.py`, эмит из `routes.py` или `payments.py` |
| Новая фоновая задача | `app.py` → `_start_scheduler()`, реализация в `payments.py` |
| Стилизация | `static/css/main.css` (искать через grep "имя_класса {") |
| Клиентская логика | `static/js/main.js` или inline в шаблоне |

### Auto-reload

Templates auto-reload включён (`app.config['TEMPLATES_AUTO_RELOAD'] = True`). Изменил Jinja-шаблон → обнови страницу в браузере, Flask подхватит.

Для статики (`main.css`, `main.js`) есть cache-busting в `base.html`:

```html
<link rel="stylesheet" href="{{ url_for('static', filename='css/main.css') }}?v={{ range(100000,999999)|random }}">
```

То есть каждый запрос к странице — новый query string, кэш сбрасывается.

Python-код **не** auto-reload'ится — нужен рестарт сервера после изменений.

---

## Базовые паттерны

### Добавить новую страницу

1. **Route в `routes.py`:**
   ```python
   @bp.route('/my-page')
   def my_page():
       user_id = session.get('user_id')
       with models.get_conn() as conn:
           data = models.something(conn, user_id)
           conn.commit()
       return render_template('my_page.html', data=data)
   ```

2. **Шаблон в `templates/my_page.html`:**
   ```html
   {% extends "base.html" %}
   {% block title %}Моя страница · BidStage{% endblock %}
   {% block content %}
   <main class="relative mx-auto max-w-[1280px] px-6 py-10 lg:px-12">
     <h1 class="page-hero-title">
       <span class="hero-word-violet">Моя</span>
       <span class="hero-word-gold">страница</span>
     </h1>
     ...
   </main>
   {% endblock %}
   ```

3. **(если нужно) кастомный CSS в `main.css`:**
   ```css
   /* в конце файла */
   .my-component { ... }
   :root[data-theme="light"] .my-component { ... }
   @media (max-width: 767px) { .my-component { ... } }
   ```

### Добавить API эндпоинт

```python
@bp.route('/api/my-action', methods=['POST'])
def api_my_action():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    # валидация
    # обращение к БД через with models.get_conn() as conn: ...
    return jsonify({'ok': True})
```

### Добавить WebSocket-событие

```python
# routes.py
import socket_events
socket_events.emit_to_user(user_id, 'my_event', payload)
socket_events.emit_to_lot(lot_id, 'my_event', payload)
```

```js
// static/js/main.js или inline
window.socket.on('my_event', (payload) => {
  // обработать
});
```

### Добавить поле в БД

В `models.py` найти соответствующую `ensure_*_table` функцию (или создать новую):

```python
def ensure_my_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS my_table ("
            "id BIGSERIAL PRIMARY KEY, "
            "user_id BIGINT NOT NULL REFERENCES users(id), "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        # для миграций существующих таблиц используем ALTER TABLE IF NOT EXISTS
        cur.execute(
            "DO $$ BEGIN "
            "ALTER TABLE my_table ADD COLUMN IF NOT EXISTS new_col TEXT; "
            "EXCEPTION WHEN OTHERS THEN NULL; END $$;"
        )
```

В `app.py` добавить вызов в `_bootstrap_database()`:

```python
def _bootstrap_database():
    with models.get_conn() as conn:
        models.init_schema(conn)
        ...
        models.ensure_my_table(conn)  # ← добавить
        conn.commit()
```

---

## Тестирование

### Smoke-тест роутов

```bash
# Backend поднят на 5000
$urls = @('/', '/lot/86', '/me', '/chats', '/hall-of-fame')
foreach ($u in $urls) {
  $r = Invoke-WebRequest "http://127.0.0.1:5000$u" -UseBasicParsing
  "{0,-20} {1}" -f $u, $r.StatusCode
}
```

### Ручной чек-лист

См. `README.md` или прежние сообщения в чате — там есть полный список из ~50 пунктов.

### Проверка JS на синтаксис

```bash
node -e "new Function(require('fs').readFileSync('static/js/main.js', 'utf8'))"
node -e "new Function(require('fs').readFileSync('static/sw.js', 'utf8'))"
```

### Проверка Python-импортов

```bash
py -c "from app import app; print('ok')"
```

---

## Дебаг

### Логи

Стандартный logging:

```python
logger = logging.getLogger('bidstage.routes')
logger.info('something happened user_id=%s lot_id=%s', user_id, lot_id)
```

В `app.py`:

```python
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s %(message)s')
```

### SQL-логи

`psycopg2` не пишет SQL по умолчанию. Чтобы увидеть запросы — добавь принт перед `cur.execute(...)` или используй `set log_statement = 'all'` в Postgres.

### WebSocket

В DevTools → Network → WS — видно подключения и события. На сервере:

```python
# socket_events.py
@socketio.on('*')
def catch_all(event, data):
    logger.info('socket event=%s data=%s', event, data)
```

---

## Часто встречающиеся проблемы

### `DATABASE_URL is required` при старте

Не загрузился `.env`. Проверь:
```bash
py -c "from dotenv import load_dotenv; load_dotenv(); import os; print('DB:', bool(os.environ.get('DATABASE_URL')))"
```

### Двойной запуск сервера

Проверь, что порт 5000 свободен:
```bash
netstat -ano | findstr ":5000"  # Windows
lsof -i :5000                    # macOS/Linux
```

### Service Worker не регистрируется

- HTTPS обязателен (или `http://localhost`).
- Проверь `/sw.js` на 200 и `Content-Type: application/javascript`.
- DevTools → Application → Service Workers → Unregister + перезагрузка.

### Изменения в CSS не подтягиваются

Жёсткий cache. Hard refresh: `Ctrl+Shift+R` (Windows) / `Cmd+Shift+R` (Mac).

### Migration ошибка «column already exists»

`ALTER TABLE ADD COLUMN IF NOT EXISTS` или оборачивай в `DO $$ ... EXCEPTION ... $$;`.

---

## Стандарты кода

### Python

- 4 пробела
- snake_case для функций и переменных
- type hints необязательно, но приветствуются для публичных функций
- параметризованные SQL-запросы только (`%s`, не `f"..."`)

### JS

- 2 пробела
- camelCase
- `const`/`let`, не `var`
- IIFE для изоляции страничных скриптов
- `addEventListener`, не inline `onclick=` (исключения только для коротких вызовов)

### CSS

- 2 пробела
- kebab-case для класс-нэйм
- Префиксы `.bs-*` для стандартных компонентов BidStage
- Префиксы `.lot-*`, `.hall-*`, `.auth-*` для специфичных страниц
- Светлая тема внизу файла, не вперемешку с тёмной
- Mobile в самом конце через `@media (max-width: 767px)`

### Jinja2

- `{% if x %}` без скобок
- `{{ value|filter }}`
- `data-translate` атрибут на тексте, который нужно переводить через `/api/translate`
- `data-i18n="key.path"` для статических переводов из словарей
