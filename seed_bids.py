"""
Сидер демо-ставок для презентации BidStage v2.

Что делает:
  1. Создаёт 6 демо-пользователей с реалистичными именами (если их ещё нет)
  2. Берёт N последних активных лотов (по умолчанию 5)
  3. На каждом лоте раскатывает 3-7 верифицированных ставок от случайных юзеров
     с шагом, равным или больше bid_step (как в реальном аукционе)
  4. Distinct user_id на каждом лоте, ставки по возрастанию по времени
  5. Для одного из лотов искусственно укорачивает end_time до 25-45 минут
     ("горящий лот" для FOMO-эффекта)

Запуск:
    py -3 seed_bids.py            # 5 лотов, 3-7 ставок каждый
    py -3 seed_bids.py --lots 3   # ограничить число лотов
"""
import argparse
import os
import random
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from dotenv import load_dotenv
load_dotenv()

import models  # noqa: E402


DEMO_USERS = [
    ('anna_concert',   'anna@bidstage.local',   'RU'),
    ('boris_vip',      'boris@bidstage.local',  'RU'),
    ('carl_collector', 'carl@bidstage.local',   'AM'),
    ('diana_loud',     'diana@bidstage.local',  'RU'),
    ('eric_tickets',   'eric@bidstage.local',   'AM'),
    ('faina_premier',  'faina@bidstage.local',  'RU'),
    ('george_bid',     'george@bidstage.local', 'RU'),
    ('helena_stage',   'helena@bidstage.local', 'AM'),
]

DEMO_PASSWORD_HASH = 'demo$disabled'  # пользователи только для шапки/имён, логин невозможен


def ensure_demo_users(conn):
    user_ids = []
    with conn.cursor() as cur:
        for username, email, country in DEMO_USERS:
            cur.execute('SELECT id FROM users WHERE LOWER(username) = LOWER(%s) LIMIT 1', (username,))
            row = cur.fetchone()
            if row:
                user_ids.append(int(row[0]))
                continue
            cur.execute(
                'INSERT INTO users (username, email, country, password_hash, vk_id) '
                'VALUES (%s, %s, %s, %s, NULL) RETURNING id',
                (username, email, country, DEMO_PASSWORD_HASH),
            )
            user_ids.append(int(cur.fetchone()[0]))
    return user_ids


def get_target_lots(conn, limit):
    """Берём активные лоты с минимальным числом ставок — там и будем накатывать."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT l.id, l.start_price_usd, l.bid_step_usd, l.end_time, l.seller_id, "
            "       (SELECT COUNT(*) FROM bids b WHERE b.lot_id = l.id) AS bid_cnt "
            "FROM lots l "
            "WHERE l.status = 'active' AND l.end_time > NOW() + INTERVAL '60 seconds' "
            "ORDER BY bid_cnt ASC, l.id DESC "
            "LIMIT %s",
            (limit,),
        )
        return [
            {
                'id': int(r[0]),
                'start_price_usd': Decimal(str(r[1])),
                'bid_step_usd': Decimal(str(r[2])),
                'end_time': r[3],
                'seller_id': int(r[4]) if r[4] is not None else None,
                'bid_count': int(r[5]),
            }
            for r in cur.fetchall()
        ]


def seed_bids_for_lot(conn, lot, user_ids, count):
    """Накатываем `count` верифицированных ставок снизу вверх с шагом bid_step (иногда удвоенным)."""
    bidders = [uid for uid in user_ids if uid != lot['seller_id']]
    if len(bidders) < 2:
        return 0
    chosen = random.sample(bidders, min(count, len(bidders)))
    price = lot['start_price_usd']
    step = lot['bid_step_usd']
    now = datetime.now(timezone.utc)
    earliest = now - timedelta(hours=random.uniform(1.5, 6))
    placed = 0
    with conn.cursor() as cur:
        for i, uid in enumerate(chosen):
            multiplier = random.choice([1, 1, 1, 2, 3])
            price = price + step * Decimal(multiplier)
            ts = earliest + (now - earliest) * ((i + 1) / (len(chosen) + 1))
            share_url = 'https://vk.com/wall-{}_{}'.format(lot['id'], 1000 + i)
            cur.execute(
                'INSERT INTO bids (lot_id, user_id, amount_usd, share_url, share_verified, created_at) '
                'VALUES (%s, %s, %s, %s, TRUE, %s) RETURNING id',
                (lot['id'], uid, price, share_url, ts),
            )
            cur.fetchone()
            placed += 1
    return placed


def make_lot_burning(conn, lot_id):
    """Укорачивает end_time до 25-45 минут, чтобы был горящий лот в каталоге."""
    new_end = datetime.now(timezone.utc) + timedelta(minutes=random.randint(25, 45))
    with conn.cursor() as cur:
        cur.execute('UPDATE lots SET end_time = %s WHERE id = %s', (new_end, lot_id))
    return new_end


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lots', type=int, default=5, help='сколько лотов заполнять ставками')
    parser.add_argument('--seed', type=int, default=42, help='зерно random')
    args = parser.parse_args()
    random.seed(args.seed)

    print('Seeding demo bids...')
    print('=' * 60)

    with models.get_conn() as conn:
        models.init_schema(conn)
        models.ensure_balance_column(conn)
        models.ensure_password_column(conn)
        user_ids = ensure_demo_users(conn)
        print('Demo users: {} (ids={})'.format(len(user_ids), user_ids))

        lots = get_target_lots(conn, limit=args.lots)
        if not lots:
            print('Нет активных лотов. Сначала прогоните: py -3 seed_lots.py')
            return

        total_bids = 0
        for idx, lot in enumerate(lots):
            count = random.randint(3, 7)
            placed = seed_bids_for_lot(conn, lot, user_ids, count)
            total_bids += placed
            print('  lot #{:>3}  +{} bids  (было {})'.format(lot['id'], placed, lot['bid_count']))

        # Один лот делаем "горящим" для FOMO в каталоге
        if lots:
            burning_lot = lots[0]
            new_end = make_lot_burning(conn, burning_lot['id'])
            print('  burning lot: #{} → end at {} ({}m)'.format(
                burning_lot['id'],
                new_end.strftime('%H:%M UTC'),
                int((new_end - datetime.now(timezone.utc)).total_seconds() / 60),
            ))

        conn.commit()

    print()
    print('=' * 60)
    print('Done. {} bids inserted across {} lots.'.format(total_bids, len(lots)))
    print('Открой главную — у лотов теперь живая активность.')


if __name__ == '__main__':
    main()
