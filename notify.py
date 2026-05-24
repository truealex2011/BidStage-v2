import logging
from datetime import datetime, timezone
from decimal import Decimal

import models
import socket_events


logger = logging.getLogger('bidstage.notify')


BOT_USERNAME = 'bidstage_support'
BOT_DISPLAY_NAME = 'BidStage Поддержка'


_bot_user_id_cache = None


def ensure_notifications_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS notifications ("
            "id BIGSERIAL PRIMARY KEY, "
            "user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, "
            "kind TEXT NOT NULL, "
            "title TEXT NOT NULL, "
            "body TEXT NOT NULL, "
            "lot_id BIGINT REFERENCES lots(id) ON DELETE SET NULL, "
            "payment_id BIGINT, "
            "read_at TIMESTAMPTZ, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications (user_id, read_at, created_at DESC)")
        cur.execute("ALTER TABLE lots ADD COLUMN IF NOT EXISTS payment_window_minutes INTEGER NOT NULL DEFAULT 1440")


def ensure_bot_user(conn):
    global _bot_user_id_cache
    if _bot_user_id_cache is not None:
        return _bot_user_id_cache
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM users WHERE username = %s", (BOT_USERNAME,))
        row = cur.fetchone()
        if row is not None:
            _bot_user_id_cache = int(row[0])
            return _bot_user_id_cache
        bot_vk_id = -777_000_001
        cur.execute(
            "INSERT INTO users (username, email, country, vk_id) "
            "VALUES (%s, %s, %s, %s) RETURNING id",
            (BOT_USERNAME, 'support@bidstage.local', 'OTHER', bot_vk_id),
        )
        _bot_user_id_cache = int(cur.fetchone()[0])
        return _bot_user_id_cache


def get_bot_user_id():
    global _bot_user_id_cache
    if _bot_user_id_cache is not None:
        return _bot_user_id_cache
    with models.get_conn() as conn:
        bot_id = ensure_bot_user(conn)
        conn.commit()
    return bot_id


def is_bot_user(user_id):
    if user_id is None:
        return False
    return int(user_id) == int(get_bot_user_id())


def insert_notification(user_id, kind, title, body, lot_id=None, payment_id=None):
    with models.get_conn() as conn:
        ensure_notifications_table(conn)
        with conn.cursor() as cur:
            # Защита от дублей: если у юзера уже есть НЕпрочитанное уведомление
            # того же типа по тому же лоту за последний час — не плодим новое.
            if lot_id is not None and kind:
                cur.execute(
                    "SELECT id FROM notifications "
                    "WHERE user_id = %s AND kind = %s AND lot_id = %s "
                    "AND read_at IS NULL "
                    "AND created_at >= NOW() - INTERVAL '1 hour' "
                    "ORDER BY created_at DESC LIMIT 1",
                    (int(user_id), kind, int(lot_id)),
                )
                existing = cur.fetchone()
                if existing:
                    conn.commit()
                    return int(existing[0])
            cur.execute(
                "INSERT INTO notifications (user_id, kind, title, body, lot_id, payment_id) "
                "VALUES (%s, %s, %s, %s, %s, %s) RETURNING id, created_at",
                (int(user_id), kind, title, body, lot_id, payment_id),
            )
            row = cur.fetchone()
            notif_id = int(row[0])
            created_at = row[1]
        conn.commit()
    payload = {
        'id': notif_id,
        'kind': kind,
        'title': title,
        'body': body,
        'lot_id': lot_id,
        'payment_id': payment_id,
        'created_at': created_at.isoformat() if created_at else datetime.now(timezone.utc).isoformat(),
        'read': False,
    }
    socket_events.emit_to_user(int(user_id), 'notification_new', payload)
    return notif_id


def send_bot_chat(user_id, lot_id, message):
    if lot_id is None or user_id is None:
        return None
    bot_id = get_bot_user_id()
    if int(user_id) == bot_id:
        return None
    with models.get_conn() as conn:
        models.ensure_chat_table(conn)
        inserted = models.insert_chat_message(conn, int(lot_id), bot_id, int(user_id), message)
        conn.commit()
    payload = {
        'id': inserted['id'],
        'lot_id': int(lot_id),
        'sender_id': bot_id,
        'sender_username': BOT_USERNAME,
        'recipient_id': int(user_id),
        'message': message,
        'created_at': inserted['created_at'].isoformat() if inserted.get('created_at') else '',
    }
    socket_events.emit_to_user(int(user_id), 'chat_message', payload)
    socket_events.emit_to_user(bot_id, 'chat_message', payload)
    return inserted['id']


def notify_event(user_id, kind, title, body, lot_id=None, payment_id=None, send_chat=True):
    if send_chat and lot_id is not None:
        send_bot_chat(user_id, lot_id, '{}\n\n{}'.format(title, body))
    notif_id = insert_notification(user_id, kind, title, body, lot_id=lot_id, payment_id=payment_id)
    return notif_id


def unread_count(user_id):
    with models.get_conn() as conn:
        ensure_notifications_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM notifications WHERE user_id = %s AND read_at IS NULL",
                (int(user_id),),
            )
            n = int(cur.fetchone()[0])
        conn.commit()
    return n


def list_notifications(user_id, limit=50, only_unread=False):
    from psycopg2.extras import RealDictCursor
    with models.get_conn() as conn:
        ensure_notifications_table(conn)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            if only_unread:
                cur.execute(
                    "SELECT id, kind, title, body, lot_id, payment_id, read_at, created_at "
                    "FROM notifications WHERE user_id = %s AND read_at IS NULL "
                    "ORDER BY created_at DESC LIMIT %s",
                    (int(user_id), limit),
                )
            else:
                cur.execute(
                    "SELECT id, kind, title, body, lot_id, payment_id, read_at, created_at "
                    "FROM notifications WHERE user_id = %s "
                    "ORDER BY created_at DESC LIMIT %s",
                    (int(user_id), limit),
                )
            rows = [dict(r) for r in cur.fetchall()]
        conn.commit()
    return rows


def mark_read(user_id, notif_id):
    with models.get_conn() as conn:
        ensure_notifications_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE notifications SET read_at = NOW() "
                "WHERE id = %s AND user_id = %s AND read_at IS NULL",
                (int(notif_id), int(user_id)),
            )
            updated = cur.rowcount
        conn.commit()
    return updated > 0


def mark_all_read(user_id):
    with models.get_conn() as conn:
        ensure_notifications_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE notifications SET read_at = NOW() WHERE user_id = %s AND read_at IS NULL",
                (int(user_id),),
            )
            updated = cur.rowcount
        conn.commit()
    return updated


def chat_unread_total(user_id):
    bot_check_id = get_bot_user_id()
    with models.get_conn() as conn:
        models.ensure_chat_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM lot_chats WHERE recipient_id = %s AND read_at IS NULL",
                (int(user_id),),
            )
            n = int(cur.fetchone()[0])
        conn.commit()
    return n
