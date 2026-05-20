import os
import contextlib
import psycopg2.pool
import psycopg2.extras
from psycopg2.extras import RealDictCursor


_pool = None


def get_pool():
    global _pool
    if _pool is None:
        dsn = os.environ.get('DATABASE_URL')
        if not dsn:
            raise RuntimeError("DATABASE_URL is required")
        _pool = psycopg2.pool.ThreadedConnectionPool(minconn=1, maxconn=20, dsn=dsn)
    return _pool


@contextlib.contextmanager
def get_conn():
    pool = get_pool()
    conn = pool.getconn()
    try:
        yield conn
    except Exception:
        try:
            conn.rollback()
        finally:
            pool.putconn(conn)
        raise
    else:
        pool.putconn(conn)


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT,
    country TEXT NOT NULL CHECK (country IN ('AM','RU','OTHER')),
    vk_id BIGINT UNIQUE NOT NULL,
    vk_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lots (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    description TEXT,
    concert_date TIMESTAMPTZ NOT NULL,
    lot_type TEXT NOT NULL CHECK (lot_type IN ('tickets','vip','table')),
    start_price_usd NUMERIC(12,2) NOT NULL CHECK (start_price_usd > 0),
    bid_step_usd NUMERIC(12,2) NOT NULL CHECK (bid_step_usd > 0),
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active','ended','cancelled')),
    winner_id BIGINT REFERENCES users(id),
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    original_duration_seconds INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS bids (
    id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id),
    amount_usd NUMERIC(12,2) NOT NULL CHECK (amount_usd > 0),
    share_url TEXT NOT NULL,
    share_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    bid_id BIGINT NOT NULL REFERENCES bids(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    amount_usd NUMERIC(12,2) NOT NULL CHECK (amount_usd > 0),
    currency TEXT NOT NULL CHECK (currency IN ('AMD','RUB','USD')),
    provider TEXT NOT NULL CHECK (provider IN ('stripe','yookassa','idram')),
    status TEXT NOT NULL CHECK (status IN ('pending','paid','failed','expired')),
    payment_url TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bids_lot_amount_desc ON bids (lot_id, amount_usd DESC);
CREATE INDEX IF NOT EXISTS idx_bids_user ON bids (user_id);
CREATE INDEX IF NOT EXISTS idx_lots_status_end_time ON lots (status, end_time);
CREATE INDEX IF NOT EXISTS idx_payments_status_expires ON payments (status, expires_at);
"""


def init_schema(conn):
    cur = conn.cursor()
    try:
        cur.execute(SCHEMA_SQL)
        conn.commit()
    finally:
        cur.close()


def get_lot_for_update(conn, lot_id):
    sql = (
        "SELECT id, title, artist, description, concert_date, lot_type, "
        "start_price_usd, bid_step_usd, end_time, status, winner_id, "
        "image_url, created_at, original_duration_seconds, seller_id "
        "FROM lots WHERE id = %s FOR UPDATE"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id,))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def get_lot(conn, lot_id):
    sql = (
        "SELECT id, title, artist, description, concert_date, lot_type, "
        "start_price_usd, bid_step_usd, end_time, status, winner_id, "
        "image_url, created_at, original_duration_seconds, seller_id "
        "FROM lots WHERE id = %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id,))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def insert_bid(conn, lot_id, user_id, amount_usd, share_url):
    sql = (
        "INSERT INTO bids (lot_id, user_id, amount_usd, share_url, share_verified) "
        "VALUES (%s, %s, %s, %s, FALSE) RETURNING id"
    )
    with conn.cursor() as cur:
        cur.execute(sql, (lot_id, user_id, amount_usd, share_url))
        row = cur.fetchone()
        return int(row[0])


def top_verified_bid(conn, lot_id):
    sql = (
        "SELECT id, lot_id, user_id, amount_usd, share_url, created_at "
        "FROM bids "
        "WHERE lot_id = %s AND share_verified = TRUE "
        "ORDER BY amount_usd DESC, id ASC LIMIT 1"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id,))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def next_verified_bid(conn, lot_id, exclude_bid_ids):
    sql = (
        "SELECT id, lot_id, user_id, amount_usd, share_url, created_at "
        "FROM bids "
        "WHERE lot_id = %s AND share_verified = TRUE AND NOT (id = ANY(%s)) "
        "ORDER BY amount_usd DESC, id ASC LIMIT 1"
    )
    excluded = list(exclude_bid_ids) if exclude_bid_ids else []
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id, excluded))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def delete_bid(conn, bid_id):
    sql = "DELETE FROM bids WHERE id = %s"
    with conn.cursor() as cur:
        cur.execute(sql, (bid_id,))


def set_share_verified(conn, bid_id):
    sql = "UPDATE bids SET share_verified = TRUE WHERE id = %s"
    with conn.cursor() as cur:
        cur.execute(sql, (bid_id,))


def update_lot_end_time(conn, lot_id, new_end_time):
    sql = "UPDATE lots SET end_time = %s WHERE id = %s"
    with conn.cursor() as cur:
        cur.execute(sql, (new_end_time, lot_id))


def set_lot_status(conn, lot_id, status, winner_id=None):
    sql = "UPDATE lots SET status = %s, winner_id = %s WHERE id = %s"
    with conn.cursor() as cur:
        cur.execute(sql, (status, winner_id, lot_id))


def expired_active_lots(conn):
    sql = (
        "SELECT id, original_duration_seconds "
        "FROM lots "
        "WHERE status = 'active' AND end_time <= NOW()"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def list_lot_runner_ups(conn, lot_id):
    sql = (
        "SELECT DISTINCT ON (user_id) id, user_id, amount_usd "
        "FROM bids "
        "WHERE lot_id = %s AND share_verified = TRUE "
        "ORDER BY user_id, amount_usd DESC, id ASC"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id,))
        rows = [dict(r) for r in cur.fetchall()]
    rows.sort(key=lambda r: (-float(r['amount_usd']), int(r['id'])))
    return rows


def get_lot_payment_window(conn, lot_id):
    with conn.cursor() as cur:
        cur.execute("SELECT payment_window_minutes FROM lots WHERE id = %s", (lot_id,))
        row = cur.fetchone()
        if row is None:
            return 1440
        return int(row[0])


def get_lot_seller(conn, lot_id):
    with conn.cursor() as cur:
        cur.execute("SELECT seller_id, title FROM lots WHERE id = %s", (lot_id,))
        row = cur.fetchone()
        if row is None:
            return None, None
        return (int(row[0]) if row[0] is not None else None), row[1]


def expired_pending_payments(conn):
    sql = (
        "SELECT p.id AS payment_id, p.bid_id, b.lot_id "
        "FROM payments p "
        "JOIN bids b ON b.id = p.bid_id "
        "WHERE p.status = 'pending' AND p.expires_at <= NOW()"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def insert_payment(conn, bid_id, user_id, amount_usd, currency, provider, status, payment_url, expires_at):
    sql = (
        "INSERT INTO payments (bid_id, user_id, amount_usd, currency, provider, status, payment_url, expires_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id"
    )
    with conn.cursor() as cur:
        cur.execute(
            sql,
            (bid_id, user_id, amount_usd, currency, provider, status, payment_url, expires_at),
        )
        row = cur.fetchone()
        return int(row[0])


def update_payment_status(conn, payment_id, status):
    sql = "UPDATE payments SET status = %s WHERE id = %s"
    with conn.cursor() as cur:
        cur.execute(sql, (status, payment_id))


def get_payment(conn, payment_id):
    sql = (
        "SELECT id, bid_id, user_id, amount_usd, currency, provider, status, "
        "payment_url, expires_at, created_at "
        "FROM payments WHERE id = %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (payment_id,))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def get_recent_verified_bids(conn, lot_id, limit):
    sql = (
        "SELECT b.id, b.lot_id, b.user_id, b.amount_usd, b.share_url, b.created_at, u.username "
        "FROM bids b "
        "JOIN users u ON u.id = b.user_id "
        "WHERE b.lot_id = %s AND b.share_verified = TRUE "
        "ORDER BY b.created_at DESC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (lot_id, limit))
        return [dict(r) for r in cur.fetchall()]


def upsert_user_by_vk(conn, vk_id, username, email, country, vk_token):
    sql = (
        "INSERT INTO users (vk_id, username, email, country, vk_token) "
        "VALUES (%s, %s, %s, %s, %s) "
        "ON CONFLICT (vk_id) DO UPDATE SET "
        "username = EXCLUDED.username, "
        "email = EXCLUDED.email, "
        "vk_token = EXCLUDED.vk_token "
        "RETURNING id"
    )
    with conn.cursor() as cur:
        cur.execute(sql, (vk_id, username, email, country, vk_token))
        row = cur.fetchone()
        return int(row[0])


def duplicate_bid_exists(conn, lot_id, user_id, amount_usd, share_url):
    sql = (
        "SELECT 1 FROM bids "
        "WHERE lot_id = %s AND user_id = %s AND amount_usd = %s AND share_url = %s "
        "LIMIT 1"
    )
    with conn.cursor() as cur:
        cur.execute(sql, (lot_id, user_id, amount_usd, share_url))
        return cur.fetchone() is not None


def get_active_lots_with_top_bid(conn):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status = 'active' AND l.end_time > NOW() + INTERVAL '60 seconds' "
        "GROUP BY l.id "
        "ORDER BY l.end_time ASC"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def search_active_lots(conn, query, limit=30):
    pattern = '%{}%'.format(query.strip())
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status = 'active' AND l.end_time > NOW() + INTERVAL '60 seconds' "
        "AND (l.title ILIKE %s OR l.artist ILIKE %s OR l.description ILIKE %s) "
        "GROUP BY l.id "
        "ORDER BY l.end_time ASC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (pattern, pattern, pattern, limit))
        return [dict(r) for r in cur.fetchall()]


def get_featured_active_lots(conn, limit=12):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "l.featured, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status = 'active' AND l.end_time > NOW() + INTERVAL '60 seconds' "
        "AND l.featured = TRUE "
        "GROUP BY l.id "
        "ORDER BY l.end_time ASC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (limit,))
        return [dict(r) for r in cur.fetchall()]


def all_active_lots_for_search(conn):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status = 'active' AND l.end_time > NOW() "
        "GROUP BY l.id "
        "ORDER BY l.end_time ASC"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def all_lots_for_search(conn):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "GROUP BY l.id "
        "ORDER BY (CASE WHEN l.status = 'active' THEN 0 ELSE 1 END), l.end_time DESC"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql)
        return [dict(r) for r in cur.fetchall()]


def get_ended_lots(conn, limit=60):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status IN ('ended','cancelled') "
        "GROUP BY l.id "
        "ORDER BY l.end_time DESC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (limit,))
        return [dict(r) for r in cur.fetchall()]


def get_upcoming_lots(conn, limit=60):
    sql = (
        "SELECT l.id, l.title, l.artist, l.description, l.concert_date, l.lot_type, "
        "l.start_price_usd, l.bid_step_usd, l.end_time, l.status, l.image_url, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE l.status = 'active' AND l.concert_date > NOW() AND l.end_time > NOW() "
        "GROUP BY l.id "
        "ORDER BY l.concert_date ASC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (limit,))
        return [dict(r) for r in cur.fetchall()]


def quick_search_lots(conn, query, limit=8):
    pattern = '%{}%'.format(query.strip())
    sql = (
        "SELECT l.id, l.title, l.artist, l.lot_type, l.image_url, l.end_time, l.status, "
        "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd "
        "FROM lots l "
        "LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
        "WHERE (l.title ILIKE %s OR l.artist ILIKE %s) "
        "GROUP BY l.id "
        "ORDER BY (CASE WHEN l.status='active' THEN 0 ELSE 1 END), l.end_time DESC LIMIT %s"
    )
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (pattern, pattern, limit))
        return [dict(r) for r in cur.fetchall()]


def get_user(conn, user_id):
    sql = "SELECT id, username, email, country, vk_id FROM users WHERE id = %s"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (user_id,))
        row = cur.fetchone()
        return dict(row) if row is not None else None


def get_max_verified_amount(conn, lot_id):
    sql = "SELECT MAX(amount_usd) FROM bids WHERE lot_id = %s AND share_verified = TRUE"
    with conn.cursor() as cur:
        cur.execute(sql, (lot_id,))
        row = cur.fetchone()
        return row[0] if row is not None else None



def ensure_balance_column(conn):
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS balance_usd NUMERIC(12,2) NOT NULL DEFAULT 0")
        cur.execute("CREATE TABLE IF NOT EXISTS balance_topups (id BIGSERIAL PRIMARY KEY, user_id BIGINT NOT NULL REFERENCES users(id), amount_usd NUMERIC(12,2) NOT NULL CHECK (amount_usd > 0), provider TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('pending','paid','failed')), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_topups_user_created ON balance_topups (user_id, created_at DESC)")


def get_balance(conn, user_id):
    with conn.cursor() as cur:
        cur.execute('SELECT balance_usd FROM users WHERE id = %s', (user_id,))
        row = cur.fetchone()
        return float(row[0]) if row and row[0] is not None else 0.0


def topup_balance(conn, user_id, amount_usd, provider, status):
    with conn.cursor() as cur:
        cur.execute(
            'INSERT INTO balance_topups (user_id, amount_usd, provider, status) VALUES (%s, %s, %s, %s) RETURNING id',
            (user_id, amount_usd, provider, status),
        )
        topup_id = int(cur.fetchone()[0])
        if status == 'paid':
            cur.execute('UPDATE users SET balance_usd = balance_usd + %s WHERE id = %s', (amount_usd, user_id))
        return topup_id


def list_topups(conn, user_id, limit):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT id, amount_usd, provider, status, created_at FROM balance_topups WHERE user_id = %s ORDER BY created_at DESC LIMIT %s',
            (user_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def list_user_bids(conn, user_id, limit):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT b.id, b.amount_usd, b.share_verified, b.created_at, l.id AS lot_id, l.title, l.status AS lot_status, l.end_time '
            'FROM bids b JOIN lots l ON l.id = b.lot_id WHERE b.user_id = %s ORDER BY b.created_at DESC LIMIT %s',
            (user_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def ensure_payment_methods_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS payment_methods ("
            "id BIGSERIAL PRIMARY KEY, "
            "user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
            "provider TEXT NOT NULL CHECK (provider IN ('stripe','yookassa','idram','demo')), "
            "external_id TEXT, "
            "brand TEXT, "
            "last4 TEXT, "
            "exp_month INTEGER, "
            "exp_year INTEGER, "
            "is_default BOOLEAN NOT NULL DEFAULT FALSE, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_pm_user ON payment_methods (user_id, created_at DESC)")


def list_payment_methods(conn, user_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT id, provider, brand, last4, exp_month, exp_year, is_default, created_at '
            'FROM payment_methods WHERE user_id = %s ORDER BY is_default DESC, created_at DESC',
            (user_id,),
        )
        return [dict(r) for r in cur.fetchall()]


def add_payment_method(conn, user_id, provider, external_id, brand, last4, exp_month, exp_year):
    with conn.cursor() as cur:
        cur.execute('SELECT COUNT(*) FROM payment_methods WHERE user_id = %s', (user_id,))
        existing = int(cur.fetchone()[0])
        is_default = existing == 0
        cur.execute(
            'INSERT INTO payment_methods (user_id, provider, external_id, brand, last4, exp_month, exp_year, is_default) '
            'VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id',
            (user_id, provider, external_id, brand, last4, exp_month, exp_year, is_default),
        )
        return int(cur.fetchone()[0])


def delete_payment_method(conn, user_id, method_id):
    with conn.cursor() as cur:
        cur.execute(
            'DELETE FROM payment_methods WHERE id = %s AND user_id = %s RETURNING is_default',
            (method_id, user_id),
        )
        row = cur.fetchone()
        if row is None:
            return False
        was_default = bool(row[0])
        if was_default:
            cur.execute(
                'UPDATE payment_methods SET is_default = TRUE WHERE id = '
                '(SELECT id FROM payment_methods WHERE user_id = %s ORDER BY created_at DESC LIMIT 1)',
                (user_id,),
            )
        return True


def set_default_payment_method(conn, user_id, method_id):
    with conn.cursor() as cur:
        cur.execute('UPDATE payment_methods SET is_default = FALSE WHERE user_id = %s', (user_id,))
        cur.execute(
            'UPDATE payment_methods SET is_default = TRUE WHERE id = %s AND user_id = %s',
            (method_id, user_id),
        )
        return cur.rowcount > 0



def get_default_payment_method(conn, user_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT id, provider, brand, last4, exp_month, exp_year FROM payment_methods WHERE user_id = %s AND is_default = TRUE LIMIT 1',
            (user_id,),
        )
        row = cur.fetchone()
        return dict(row) if row else None


def deduct_balance(conn, user_id, amount_usd):
    with conn.cursor() as cur:
        cur.execute(
            'UPDATE users SET balance_usd = balance_usd - %s WHERE id = %s AND balance_usd >= %s RETURNING balance_usd',
            (amount_usd, user_id, amount_usd),
        )
        row = cur.fetchone()
        return float(row[0]) if row else None


def list_user_payments(conn, user_id, limit):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT p.id, p.amount_usd, p.currency, p.provider, p.status, p.payment_url, p.expires_at, p.created_at, '
            'p.held_in_escrow, p.released_to_seller, p.ticket_delivered, p.ticket_code, p.buyer_confirmed, '
            'b.lot_id, l.title AS lot_title, l.seller_id '
            'FROM payments p JOIN bids b ON b.id = p.bid_id JOIN lots l ON l.id = b.lot_id '
            'WHERE p.user_id = %s ORDER BY p.created_at DESC LIMIT %s',
            (user_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]



def ensure_password_column(conn):
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT")
        cur.execute("ALTER TABLE users ALTER COLUMN vk_id DROP NOT NULL")
        cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_lower ON users (LOWER(username))")
        cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email)) WHERE email IS NOT NULL AND email <> ''")


def find_user_by_username_or_email(conn, identifier):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT id, username, email, country, password_hash FROM users WHERE LOWER(username) = LOWER(%s) OR LOWER(email) = LOWER(%s) LIMIT 1',
            (identifier, identifier),
        )
        row = cur.fetchone()
        return dict(row) if row else None


def create_local_user(conn, username, email, country, password_hash):
    with conn.cursor() as cur:
        cur.execute(
            'INSERT INTO users (username, email, country, password_hash, vk_id) VALUES (%s, %s, %s, %s, NULL) RETURNING id',
            (username, email, country, password_hash),
        )
        return int(cur.fetchone()[0])



def get_lot_live_stats(conn, lot_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT b.user_id, u.username, b.amount_usd, b.created_at '
            'FROM bids b JOIN users u ON u.id = b.user_id '
            'WHERE b.lot_id = %s AND b.share_verified = TRUE '
            'ORDER BY b.amount_usd DESC LIMIT 3',
            (lot_id,),
        )
        top_bidders = [dict(r) for r in cur.fetchall()]
        cur.execute(
            'SELECT DATE_TRUNC(\'hour\', created_at) AS hour, COUNT(*) AS cnt '
            'FROM bids WHERE lot_id = %s '
            'GROUP BY hour ORDER BY hour DESC LIMIT 24',
            (lot_id,),
        )
        hourly = [dict(r) for r in cur.fetchall()]
        cur.execute(
            'SELECT b.user_id, u.username, b.amount_usd, b.created_at, b.share_verified '
            'FROM bids b JOIN users u ON u.id = b.user_id '
            'WHERE b.lot_id = %s '
            'ORDER BY b.created_at DESC LIMIT 30',
            (lot_id,),
        )
        all_bids = [dict(r) for r in cur.fetchall()]
    return {'top_bidders': top_bidders, 'hourly': hourly, 'all_bids': all_bids}



def ensure_watchlist_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS watchlist ("
            "id BIGSERIAL PRIMARY KEY, "
            "user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
            "lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE, "
            "notify_outbid BOOLEAN NOT NULL DEFAULT TRUE, "
            "notify_ending BOOLEAN NOT NULL DEFAULT TRUE, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
            "UNIQUE(user_id, lot_id))"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_watchlist_lot ON watchlist (lot_id)")


def toggle_watchlist(conn, user_id, lot_id, notify_outbid=True, notify_ending=True):
    with conn.cursor() as cur:
        cur.execute('SELECT id FROM watchlist WHERE user_id = %s AND lot_id = %s', (user_id, lot_id))
        row = cur.fetchone()
        if row:
            cur.execute('DELETE FROM watchlist WHERE user_id = %s AND lot_id = %s', (user_id, lot_id))
            return False
        cur.execute(
            'INSERT INTO watchlist (user_id, lot_id, notify_outbid, notify_ending) VALUES (%s, %s, %s, %s)',
            (user_id, lot_id, notify_outbid, notify_ending),
        )
        return True


def is_watching(conn, user_id, lot_id):
    with conn.cursor() as cur:
        cur.execute('SELECT 1 FROM watchlist WHERE user_id = %s AND lot_id = %s', (user_id, lot_id))
        return cur.fetchone() is not None


def get_watchlist_users(conn, lot_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT w.user_id, w.notify_outbid, w.notify_ending FROM watchlist w WHERE w.lot_id = %s',
            (lot_id,),
        )
        return [dict(r) for r in cur.fetchall()]


def get_user_watchlist(conn, user_id, limit=20):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT l.id, l.title, l.artist, l.status, l.end_time, '
            'COALESCE(MAX(b.amount_usd), l.start_price_usd) AS current_price_usd '
            'FROM watchlist w JOIN lots l ON l.id = w.lot_id '
            'LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE '
            'WHERE w.user_id = %s GROUP BY l.id ORDER BY l.end_time ASC LIMIT %s',
            (user_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def get_all_bids_for_lot(conn, lot_id, limit):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT b.id, b.lot_id, b.user_id, b.amount_usd, b.share_url, b.share_verified, b.created_at, u.username '
            'FROM bids b JOIN users u ON u.id = b.user_id '
            'WHERE b.lot_id = %s '
            'ORDER BY b.created_at DESC LIMIT %s',
            (lot_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]



def ensure_seller_columns(conn):
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE lots ADD COLUMN IF NOT EXISTS seller_id BIGINT REFERENCES users(id)")
        cur.execute("ALTER TABLE lots ADD COLUMN IF NOT EXISTS featured BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute("ALTER TABLE lots ADD COLUMN IF NOT EXISTS listing_fee_usd NUMERIC(10,2) NOT NULL DEFAULT 0")
        cur.execute("ALTER TABLE lots ADD COLUMN IF NOT EXISTS final_value_fee_pct NUMERIC(5,2) NOT NULL DEFAULT 10")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lots_seller ON lots (seller_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lots_featured ON lots (featured) WHERE featured = TRUE")


def create_lot(conn, seller_id, title, artist, description, concert_date, lot_type,
               start_price_usd, bid_step_usd, end_time, original_duration_seconds,
               featured, listing_fee_usd, final_value_fee_pct, image_url=None):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO lots (title, artist, description, concert_date, lot_type, "
            "start_price_usd, bid_step_usd, end_time, status, original_duration_seconds, "
            "image_url, seller_id, featured, listing_fee_usd, final_value_fee_pct) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'active',%s,%s,%s,%s,%s,%s) RETURNING id",
            (title, artist, description, concert_date, lot_type,
             start_price_usd, bid_step_usd, end_time, original_duration_seconds,
             image_url, seller_id, featured, listing_fee_usd, final_value_fee_pct),
        )
        return int(cur.fetchone()[0])


def list_seller_lots(conn, seller_id, limit=20):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT id, title, artist, status, end_time, start_price_usd, '
            'COALESCE((SELECT MAX(amount_usd) FROM bids WHERE lot_id=l.id AND share_verified=TRUE), start_price_usd) AS current_price_usd, '
            '(SELECT COUNT(*) FROM bids WHERE lot_id=l.id AND share_verified=TRUE) AS bid_count, '
            'final_value_fee_pct '
            'FROM lots l WHERE seller_id = %s ORDER BY created_at DESC LIMIT %s',
            (seller_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]



def ensure_proxy_bid_columns(conn):
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE bids ADD COLUMN IF NOT EXISTS max_amount_usd NUMERIC(12,2)")
        cur.execute("ALTER TABLE bids ADD COLUMN IF NOT EXISTS is_proxy BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute(
            "CREATE TABLE IF NOT EXISTS proxy_bids ("
            "id BIGSERIAL PRIMARY KEY, "
            "lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE, "
            "user_id BIGINT NOT NULL REFERENCES users(id), "
            "max_amount_usd NUMERIC(12,2) NOT NULL CHECK (max_amount_usd > 0), "
            "share_url TEXT NOT NULL, "
            "active BOOLEAN NOT NULL DEFAULT TRUE, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
            "UNIQUE(lot_id, user_id))"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_proxy_lot_active ON proxy_bids (lot_id, active)")


def ensure_escrow_columns(conn):
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS held_in_escrow BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS released_to_seller BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS ticket_delivered BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS ticket_code TEXT")
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS buyer_confirmed BOOLEAN NOT NULL DEFAULT FALSE")
        cur.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS dispute_open BOOLEAN NOT NULL DEFAULT FALSE")


def ensure_reviews_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS seller_reviews ("
            "id BIGSERIAL PRIMARY KEY, "
            "seller_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
            "buyer_id BIGINT NOT NULL REFERENCES users(id), "
            "lot_id BIGINT NOT NULL REFERENCES lots(id), "
            "payment_id BIGINT REFERENCES payments(id), "
            "rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5), "
            "comment TEXT, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
            "UNIQUE(payment_id, buyer_id))"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_reviews_seller ON seller_reviews (seller_id, created_at DESC)")


def get_seller_stats(conn, seller_id):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*), COALESCE(AVG(rating), 0) "
            "FROM seller_reviews WHERE seller_id = %s",
            (seller_id,),
        )
        row = cur.fetchone()
        review_count = int(row[0]) if row else 0
        avg_rating = float(row[1]) if row else 0.0
        cur.execute(
            "SELECT COUNT(*) FROM lots WHERE seller_id = %s",
            (seller_id,),
        )
        total_lots = int(cur.fetchone()[0])
        cur.execute(
            "SELECT COUNT(*) FROM lots WHERE seller_id = %s AND status = 'ended' AND winner_id IS NOT NULL",
            (seller_id,),
        )
        sold_lots = int(cur.fetchone()[0])
        return {
            'review_count': review_count,
            'avg_rating': round(avg_rating, 2),
            'total_lots': total_lots,
            'sold_lots': sold_lots,
            'success_rate': round(sold_lots / total_lots * 100, 1) if total_lots > 0 else 0,
        }


def get_seller_reviews(conn, seller_id, limit=10):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT r.id, r.rating, r.comment, r.created_at, u.username AS buyer_username, l.title AS lot_title "
            "FROM seller_reviews r "
            "JOIN users u ON u.id = r.buyer_id "
            "JOIN lots l ON l.id = r.lot_id "
            "WHERE r.seller_id = %s ORDER BY r.created_at DESC LIMIT %s",
            (seller_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def insert_review(conn, seller_id, buyer_id, lot_id, payment_id, rating, comment):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO seller_reviews (seller_id, buyer_id, lot_id, payment_id, rating, comment) "
            "VALUES (%s, %s, %s, %s, %s, %s) RETURNING id",
            (seller_id, buyer_id, lot_id, payment_id, rating, comment),
        )
        return int(cur.fetchone()[0])


def upsert_proxy_bid(conn, lot_id, user_id, max_amount_usd, share_url):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO proxy_bids (lot_id, user_id, max_amount_usd, share_url, active) "
            "VALUES (%s, %s, %s, %s, TRUE) "
            "ON CONFLICT (lot_id, user_id) DO UPDATE SET "
            "max_amount_usd = EXCLUDED.max_amount_usd, share_url = EXCLUDED.share_url, active = TRUE "
            "RETURNING id",
            (lot_id, user_id, max_amount_usd, share_url),
        )
        return int(cur.fetchone()[0])


def get_active_proxy_bids(conn, lot_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT pb.id, pb.user_id, pb.max_amount_usd, pb.share_url, u.username "
            "FROM proxy_bids pb JOIN users u ON u.id = pb.user_id "
            "WHERE pb.lot_id = %s AND pb.active = TRUE "
            "ORDER BY pb.max_amount_usd DESC",
            (lot_id,),
        )
        return [dict(r) for r in cur.fetchall()]


def deactivate_proxy_bid(conn, lot_id, user_id):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE proxy_bids SET active = FALSE WHERE lot_id = %s AND user_id = %s",
            (lot_id, user_id),
        )


def confirm_ticket_delivery(conn, payment_id, buyer_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT p.id, p.amount_usd, p.held_in_escrow, p.released_to_seller, "
            "p.ticket_delivered, b.lot_id, l.seller_id, l.final_value_fee_pct, l.title "
            "FROM payments p JOIN bids b ON b.id = p.bid_id JOIN lots l ON l.id = b.lot_id "
            "WHERE p.id = %s AND p.user_id = %s AND p.status = 'paid' AND p.held_in_escrow = TRUE "
            "AND p.released_to_seller = FALSE",
            (payment_id, buyer_id),
        )
        row = cur.fetchone()
        if row is None:
            return None
        if not row['ticket_delivered']:
            return None
        if row['seller_id'] is None:
            return None
        amount = row['amount_usd']
        fee_pct = row['final_value_fee_pct'] or 0
        seller_share = (amount * (100 - fee_pct) / 100)
        cur.execute(
            "UPDATE payments SET buyer_confirmed = TRUE, released_to_seller = TRUE "
            "WHERE id = %s",
            (payment_id,),
        )
        cur.execute(
            "UPDATE users SET balance_usd = balance_usd + %s WHERE id = %s",
            (seller_share, row['seller_id']),
        )
    return {
        'payment_id': payment_id,
        'lot_id': int(row['lot_id']),
        'seller_id': int(row['seller_id']),
        'amount_usd': float(amount),
        'fee_pct': float(fee_pct),
        'seller_credited_usd': float(seller_share),
        'lot_title': row['title'],
    }


def deliver_ticket(conn, payment_id, ticket_code):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE payments SET ticket_delivered = TRUE, ticket_code = %s WHERE id = %s "
            "RETURNING user_id, bid_id",
            (ticket_code, payment_id),
        )
        return cur.fetchone()



def ensure_lot_events_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS lot_events ("
            "id BIGSERIAL PRIMARY KEY, "
            "lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE, "
            "event_type TEXT NOT NULL, "
            "actor_username TEXT, "
            "actor_user_id BIGINT, "
            "amount_usd NUMERIC(12,2), "
            "payload JSONB, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lot_events_lot ON lot_events (lot_id, created_at DESC)")


def insert_lot_event(conn, lot_id, event_type, actor_username=None, actor_user_id=None, amount_usd=None, payload=None):
    import json as _json
    payload_json = _json.dumps(payload) if payload is not None else None
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO lot_events (lot_id, event_type, actor_username, actor_user_id, amount_usd, payload) "
            "VALUES (%s, %s, %s, %s, %s, %s::jsonb) RETURNING id",
            (lot_id, event_type, actor_username, actor_user_id, amount_usd, payload_json),
        )
        return int(cur.fetchone()[0])


def get_lot_events(conn, lot_id, limit=50):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT id, event_type, actor_username, actor_user_id, amount_usd, payload, created_at "
            "FROM lot_events WHERE lot_id = %s ORDER BY created_at DESC LIMIT %s",
            (lot_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]



def get_top_bidders_for_lot(conn, lot_id, limit=5):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            'SELECT b.user_id, u.username, MAX(b.amount_usd) AS max_amount, COUNT(*) AS bid_count '
            'FROM bids b JOIN users u ON u.id = b.user_id '
            'WHERE b.lot_id = %s '
            'GROUP BY b.user_id, u.username '
            'ORDER BY max_amount DESC, bid_count DESC LIMIT %s',
            (lot_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def hall_of_fame(conn):
    from psycopg2.extras import RealDictCursor
    awards = {}
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT l.id, l.title, l.artist, l.lot_type, "
            "COALESCE(MAX(b.amount_usd), l.start_price_usd) AS final_price_usd "
            "FROM lots l LEFT JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
            "WHERE l.status IN ('ended', 'active') "
            "GROUP BY l.id ORDER BY final_price_usd DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['most_expensive'] = dict(row)

        cur.execute(
            "SELECT l.id, l.title, l.artist, COUNT(*) AS bid_count "
            "FROM bids b JOIN lots l ON l.id = b.lot_id "
            "GROUP BY l.id ORDER BY bid_count DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['hardest_battle'] = dict(row)

        cur.execute(
            "SELECT u.id, u.username, COUNT(DISTINCT l.id) AS won_count, "
            "COALESCE(SUM(p.amount_usd), 0) AS total_spent "
            "FROM users u "
            "LEFT JOIN lots l ON l.winner_id = u.id "
            "LEFT JOIN payments p ON p.user_id = u.id AND p.status = 'paid' "
            "GROUP BY u.id, u.username "
            "HAVING COUNT(DISTINCT l.id) > 0 "
            "ORDER BY won_count DESC, total_spent DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['top_buyer'] = dict(row)

        cur.execute(
            "SELECT u.id, u.username, COUNT(*) AS sold_count "
            "FROM lots l JOIN users u ON u.id = l.seller_id "
            "WHERE l.status = 'ended' AND l.winner_id IS NOT NULL "
            "GROUP BY u.id, u.username "
            "ORDER BY sold_count DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['top_seller'] = dict(row)

        cur.execute(
            "SELECT u.id, u.username, COUNT(*) AS bids_total "
            "FROM bids b JOIN users u ON u.id = b.user_id "
            "GROUP BY u.id, u.username "
            "ORDER BY bids_total DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['most_persistent'] = dict(row)

        cur.execute(
            "SELECT l.id, l.title, l.artist, l.lot_type, "
            "MAX(b.amount_usd) - l.start_price_usd AS price_growth, "
            "l.start_price_usd, MAX(b.amount_usd) AS final_price "
            "FROM lots l JOIN bids b ON b.lot_id = l.id AND b.share_verified = TRUE "
            "GROUP BY l.id "
            "ORDER BY price_growth DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row:
            awards['biggest_growth'] = dict(row)

    return awards



def get_seller_escrow_payments(conn, seller_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT p.id, p.amount_usd, p.status, p.held_in_escrow, p.released_to_seller, "
            "p.ticket_delivered, p.ticket_code, p.buyer_confirmed, p.created_at, "
            "b.lot_id, l.title AS lot_title, u.username AS buyer_username, u.id AS buyer_id "
            "FROM payments p "
            "JOIN bids b ON b.id = p.bid_id "
            "JOIN lots l ON l.id = b.lot_id "
            "JOIN users u ON u.id = p.user_id "
            "WHERE l.seller_id = %s AND p.status = 'paid' "
            "ORDER BY p.created_at DESC",
            (seller_id,),
        )
        return [dict(r) for r in cur.fetchall()]


def get_seller_escrow_total(conn, seller_id):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COALESCE(SUM(p.amount_usd * (100 - l.final_value_fee_pct) / 100), 0) "
            "FROM payments p JOIN bids b ON b.id = p.bid_id JOIN lots l ON l.id = b.lot_id "
            "WHERE l.seller_id = %s AND p.status = 'paid' AND p.held_in_escrow = TRUE "
            "AND p.released_to_seller = FALSE",
            (seller_id,),
        )
        row = cur.fetchone()
        return float(row[0]) if row and row[0] is not None else 0.0


def ensure_chat_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS lot_chats ("
            "id BIGSERIAL PRIMARY KEY, "
            "lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE, "
            "sender_id BIGINT NOT NULL REFERENCES users(id), "
            "recipient_id BIGINT NOT NULL REFERENCES users(id), "
            "message TEXT NOT NULL, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
            "read_at TIMESTAMPTZ)"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lot_chat_pair ON lot_chats (lot_id, sender_id, recipient_id, created_at)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_lot_chat_recipient ON lot_chats (recipient_id, read_at)")


def insert_chat_message(conn, lot_id, sender_id, recipient_id, message):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO lot_chats (lot_id, sender_id, recipient_id, message) "
            "VALUES (%s, %s, %s, %s) RETURNING id, created_at",
            (lot_id, sender_id, recipient_id, message),
        )
        row = cur.fetchone()
        return {'id': int(row[0]), 'created_at': row[1]}


def list_chat_messages(conn, lot_id, user_a, user_b, limit=100):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT c.id, c.lot_id, c.sender_id, c.recipient_id, c.message, c.created_at, c.read_at, "
            "u.username AS sender_username "
            "FROM lot_chats c JOIN users u ON u.id = c.sender_id "
            "WHERE c.lot_id = %s "
            "AND ((c.sender_id = %s AND c.recipient_id = %s) "
            "OR (c.sender_id = %s AND c.recipient_id = %s)) "
            "ORDER BY c.created_at ASC LIMIT %s",
            (lot_id, user_a, user_b, user_b, user_a, limit),
        )
        return [dict(r) for r in cur.fetchall()]


def mark_chat_read(conn, lot_id, sender_id, recipient_id):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE lot_chats SET read_at = NOW() "
            "WHERE lot_id = %s AND sender_id = %s AND recipient_id = %s AND read_at IS NULL",
            (lot_id, sender_id, recipient_id),
        )


def ensure_otp_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS bid_otps ("
            "id BIGSERIAL PRIMARY KEY, "
            "user_id BIGINT NOT NULL REFERENCES users(id), "
            "lot_id BIGINT NOT NULL REFERENCES lots(id), "
            "otp_code TEXT NOT NULL, "
            "amount_usd NUMERIC(12,2) NOT NULL, "
            "share_url TEXT NOT NULL, "
            "expires_at TIMESTAMPTZ NOT NULL, "
            "consumed_at TIMESTAMPTZ, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_bid_otps_user ON bid_otps (user_id, lot_id, consumed_at)")


def insert_otp(conn, user_id, lot_id, code, amount_usd, share_url, expires_at):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO bid_otps (user_id, lot_id, otp_code, amount_usd, share_url, expires_at) "
            "VALUES (%s, %s, %s, %s, %s, %s) RETURNING id",
            (user_id, lot_id, code, amount_usd, share_url, expires_at),
        )
        return int(cur.fetchone()[0])


def consume_otp(conn, user_id, lot_id, code):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT id, amount_usd, share_url, expires_at, consumed_at "
            "FROM bid_otps "
            "WHERE user_id = %s AND lot_id = %s AND otp_code = %s "
            "ORDER BY created_at DESC LIMIT 1",
            (user_id, lot_id, code),
        )
        row = cur.fetchone()
        if row is None:
            return None
        if row['consumed_at'] is not None:
            return {'error': 'already_used'}
        from datetime import datetime, timezone
        if row['expires_at'].astimezone(timezone.utc) < datetime.now(timezone.utc):
            return {'error': 'expired'}
        cur.execute("UPDATE bid_otps SET consumed_at = NOW() WHERE id = %s", (row['id'],))
        return {
            'amount_usd': float(row['amount_usd']),
            'share_url': row['share_url'],
        }


def list_user_chats(conn, user_id):
    from psycopg2.extras import RealDictCursor
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            "SELECT DISTINCT ON (lot_id, peer_id) "
            "  lot_id, peer_id, peer_username, lot_title, lot_image_url, "
            "  last_message, last_at, unread "
            "FROM ("
            "  SELECT c.lot_id, "
            "    CASE WHEN c.sender_id = %s THEN c.recipient_id ELSE c.sender_id END AS peer_id, "
            "    u.username AS peer_username, "
            "    l.title AS lot_title, l.image_url AS lot_image_url, "
            "    c.message AS last_message, c.created_at AS last_at, "
            "    (SELECT COUNT(*) FROM lot_chats c2 "
            "       WHERE c2.lot_id = c.lot_id "
            "       AND c2.recipient_id = %s "
            "       AND c2.sender_id = CASE WHEN c.sender_id = %s THEN c.recipient_id ELSE c.sender_id END "
            "       AND c2.read_at IS NULL) AS unread "
            "  FROM lot_chats c "
            "  JOIN lots l ON l.id = c.lot_id "
            "  JOIN users u ON u.id = (CASE WHEN c.sender_id = %s THEN c.recipient_id ELSE c.sender_id END) "
            "  WHERE c.sender_id = %s OR c.recipient_id = %s "
            "  ORDER BY c.lot_id, "
            "    (CASE WHEN c.sender_id = %s THEN c.recipient_id ELSE c.sender_id END), "
            "    c.created_at DESC"
            ") sub "
            "ORDER BY lot_id, peer_id, last_at DESC",
            (user_id, user_id, user_id, user_id, user_id, user_id, user_id),
        )
        rows = [dict(r) for r in cur.fetchall()]
    rows.sort(key=lambda r: r['last_at'], reverse=True)
    return rows
