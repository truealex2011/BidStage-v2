"""
Сидер аукционов с реальными картинками из интернета (picsum.photos).

Что делает:
1. Скачивает картинки с https://picsum.photos с детерминированными seed'ами
   и сохраняет в static/lot_images/picsum_<n>.jpg
2. Создаёт N лотов в БД с разнообразными названиями/артистами/категориями,
   разными дедлайнами (от 30 минут до 5 дней), типами (tickets/vip/table)
3. Создаёт 8 демо-юзеров если их нет
4. На каждом лоте раскатывает 2-8 верифицированных ставок

Запуск:
    py -3 seed_internet_lots.py                # 12 лотов с картинками + ставки
    py -3 seed_internet_lots.py --count 20     # 20 лотов
    py -3 seed_internet_lots.py --no-bids      # только лоты, без ставок
    py -3 seed_internet_lots.py --keep-existing  # не дублировать если уже есть
"""
import argparse
import os
import random
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from dotenv import load_dotenv
load_dotenv()

import models  # noqa: E402


SELLER_USERNAME = 'demo_anna'
LISTING_FEE = Decimal('0')
FVF_PCT = Decimal('10')


# Пул реалистичных лотов: (title, artist, lot_type, start_price_usd, bid_step_usd, description, concert_offset_days)
LOT_POOL = [
    ('Концерт The Weeknd · Dawn FM Tour', 'The Weeknd',
     'tickets', 220, 15, 'Партер. 2 билета рядом. После-вечеринка.', 38),
    ('Финал Кубка Мира · Стадион Лужники', 'FIFA',
     'tickets', 480, 30, 'Сектор VIP, 5 ряд. Закрытый бар.', 65),
    ('Stand-up Comedy Битва Чемпионов', 'Comedy Wars',
     'tickets', 95, 5, 'Первые 3 ряда. Резиденты + спецгость.', 18),
    ('VIP-ложа на премьеру оперы «Евгений Онегин»', 'Большой театр',
     'vip', 380, 25, 'Ложа на 4 персоны. Шампанское и канапе.', 52),
    ('Концерт Imagine Dragons · Mercury World Tour', 'Imagine Dragons',
     'tickets', 280, 20, 'Танцпол, ближе к сцене. Мерч-пакет.', 44),
    ('Дегустация виски премиум · Whisky Society', 'Whisky Society',
     'table', 175, 12, 'Сет из 12 виски + сомелье. На двоих.', 9),
    ('Хоккей: финал плей-офф КХЛ', 'КХЛ',
     'tickets', 195, 12, 'VIP-сектор у скамейки команд.', 22),
    ('Стол на четверых · Ресторан Twins Garden', 'Twins Garden',
     'table', 320, 18, 'Тастинг-меню от шефов-близнецов Березуцких.', 14),
    ('VIP-проход на Comic Con · все 3 дня', 'Comic Con',
     'vip', 240, 15, 'Без очередей. Закрытые автограф-сессии.', 78),
    ('Концерт Linkin Park Reunion Tour', 'Linkin Park',
     'tickets', 350, 25, 'Партер, 4 ряд. Гость на саундчек.', 95),
    ('Балет «Лебединое озеро» · Мариинский', 'Мариинский театр',
     'tickets', 280, 18, 'Историческая сцена. 3 ряд бенуар.', 67),
    ('Стол с видом · Ресторан Sky Lounge', 'Sky Lounge',
     'table', 145, 10, 'Вид на Москва-Сити. Дегустация коктейлей.', 11),
    ('Концерт Coldplay · Music of the Spheres', 'Coldplay',
     'tickets', 420, 30, 'Партер VIP, браслет проектируется со сцены.', 88),
    ('VIP-ложа на финал Лиги Чемпионов', 'UEFA',
     'vip', 850, 50, 'Ложа на 6 персон. Фуршет, паркинг.', 60),
    ('Вечер русского балета · Кремлёвский дворец', 'Кремлёвский балет',
     'tickets', 165, 12, 'Партер. Премьерный показ.', 41),
    ('Открытие винной выставки · Vinitaly Moscow', 'Vinitaly',
     'vip', 110, 8, 'Свободная дегустация 80+ вин.', 16),
    ('Концерт Metallica · M72 World Tour', 'Metallica',
     'tickets', 390, 25, 'Фан-зона, ближе всего к сцене.', 102),
    ('Гастро-сет · Шеф-стол ресторана White Rabbit', 'White Rabbit',
     'table', 290, 18, '12 курсов от Владимира Мухина.', 25),
    ('Тур по закулисью БДТ · с актёрами', 'БДТ',
     'vip', 95, 8, 'Группа 6 человек. После спектакля.', 33),
    ('Концерт Twenty One Pilots · Clancy Tour', 'Twenty One Pilots',
     'tickets', 260, 18, 'Партер, центр. Закрытый mеet&greet.', 56),
]


DEMO_USERS = [
    ('anna_concert',   'anna2@bidstage.local',   'RU'),
    ('boris_vip',      'boris2@bidstage.local',  'RU'),
    ('carl_collector', 'carl2@bidstage.local',   'AM'),
    ('diana_loud',     'diana2@bidstage.local',  'RU'),
    ('eric_tickets',   'eric2@bidstage.local',   'AM'),
    ('faina_premier',  'faina2@bidstage.local',  'RU'),
    ('george_bid',     'george2@bidstage.local', 'RU'),
    ('helena_stage',   'helena2@bidstage.local', 'AM'),
]


def ensure_seller(conn):
    with conn.cursor() as cur:
        cur.execute('SELECT id FROM users WHERE LOWER(username) = LOWER(%s) LIMIT 1', (SELLER_USERNAME,))
        row = cur.fetchone()
        if row:
            return int(row[0])
        cur.execute(
            "INSERT INTO users (username, email, country, vk_id) "
            "VALUES (%s, %s, 'RU', %s) RETURNING id",
            (SELLER_USERNAME, SELLER_USERNAME + '@bidstage.local', random.randint(1_000_000_000, 1_999_999_999)),
        )
        return int(cur.fetchone()[0])


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
                (username, email, country, 'demo$disabled'),
            )
            user_ids.append(int(cur.fetchone()[0]))
    return user_ids


def download_image(seed, target_path, width=1200, height=750, retries=3):
    """Скачивает картинку с picsum.photos. Возвращает True если успех."""
    if os.path.exists(target_path) and os.path.getsize(target_path) > 1024:
        return True
    url = 'https://picsum.photos/seed/{}/{}/{}'.format(seed, width, height)
    headers = {'User-Agent': 'BidStageSeed/1.0'}
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
            if len(data) < 1024:
                raise ValueError('image too small')
            with open(target_path, 'wb') as f:
                f.write(data)
            return True
        except (urllib.error.URLError, urllib.error.HTTPError, ValueError, TimeoutError) as e:
            print('  retry {}/{} — {}: {}'.format(attempt + 1, retries, type(e).__name__, e))
            time.sleep(1.5)
    return False


def existing_lot_titles(conn):
    with conn.cursor() as cur:
        cur.execute('SELECT title FROM lots')
        return {row[0] for row in cur.fetchall()}


def seed_lot(conn, seller_id, data, end_offset_hours, image_url):
    title, artist, lot_type, start_usd, step_usd, description, concert_days = data
    end_time = datetime.now(timezone.utc) + timedelta(hours=end_offset_hours)
    concert_date = datetime.now(timezone.utc) + timedelta(days=concert_days)
    duration_seconds = int(end_offset_hours * 3600)

    lot_id = models.create_lot(
        conn, seller_id,
        title, artist, description, concert_date, lot_type,
        Decimal(str(start_usd)), Decimal(str(step_usd)),
        end_time, duration_seconds,
        False, LISTING_FEE, FVF_PCT,
        image_url=image_url,
    )
    return lot_id


def seed_bids_for_lot(conn, lot_id, lot_data, user_ids, seller_id, count):
    bidders = [uid for uid in user_ids if uid != seller_id]
    if len(bidders) < 2:
        return 0
    chosen = random.sample(bidders, min(count, len(bidders)))
    _, _, _, start_usd, step_usd, _, _ = lot_data
    price = Decimal(str(start_usd))
    step = Decimal(str(step_usd))
    now = datetime.now(timezone.utc)
    earliest = now - timedelta(hours=random.uniform(1.5, 6))
    placed = 0
    with conn.cursor() as cur:
        for i, uid in enumerate(chosen):
            multiplier = random.choice([1, 1, 1, 2, 3])
            price = price + step * Decimal(multiplier)
            ts = earliest + (now - earliest) * ((i + 1) / (len(chosen) + 1))
            share_url = 'https://vk.com/wall-{}_{}'.format(lot_id, 1000 + i)
            cur.execute(
                'INSERT INTO bids (lot_id, user_id, amount_usd, share_url, share_verified, created_at) '
                'VALUES (%s, %s, %s, %s, TRUE, %s)',
                (lot_id, uid, price, share_url, ts),
            )
            placed += 1
    return placed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--count', type=int, default=12, help='сколько лотов создать (max = размер пула)')
    parser.add_argument('--no-bids', action='store_true', help='не раскатывать ставки на лоты')
    parser.add_argument('--keep-existing', action='store_true', help='пропустить лоты с уже существующими названиями')
    parser.add_argument('--seed', type=int, default=None, help='зерно для random (по умолчанию — текущее время)')
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    images_dir = os.path.join(os.path.dirname(__file__), 'static', 'lot_images')
    os.makedirs(images_dir, exist_ok=True)

    print('=' * 64)
    print('BidStage · seed lots from internet (picsum.photos)')
    print('=' * 64)

    pool = LOT_POOL[:]
    random.shuffle(pool)
    pool = pool[:args.count]

    with models.get_conn() as conn:
        models.init_schema(conn)
        models.ensure_balance_column(conn)
        models.ensure_password_column(conn)
        seller_id = ensure_seller(conn)
        print('Seller: {} (id={})'.format(SELLER_USERNAME, seller_id))
        user_ids = ensure_demo_users(conn) if not args.no_bids else []
        if user_ids:
            print('Demo users: {}'.format(len(user_ids)))

        existing_titles = existing_lot_titles(conn) if args.keep_existing else set()

        # Распределение дедлайнов: 1 «горящий» (30-60 мин), пара «скоро» (4-12ч),
        # остальные размазаны от 1 до 5 дней
        offsets_pool = (
            [random.uniform(0.5, 1.0)] +
            [random.uniform(4, 12) for _ in range(min(2, len(pool) - 1))] +
            [random.uniform(24, 120) for _ in range(max(0, len(pool) - 3))]
        )
        random.shuffle(offsets_pool)
        if len(offsets_pool) < len(pool):
            offsets_pool += [random.uniform(24, 120) for _ in range(len(pool) - len(offsets_pool))]

        created = 0
        skipped = 0
        for idx, lot_data in enumerate(pool):
            title = lot_data[0]
            if args.keep_existing and title in existing_titles:
                print('  skip (exists): {}'.format(title[:50]))
                skipped += 1
                continue

            seed_str = 'bidstage-{}'.format(abs(hash(title)) % 100000)
            filename = 'picsum_{}.jpg'.format(seed_str.replace('-', '_'))
            target_path = os.path.join(images_dir, filename)

            print('  [{}/{}] {}'.format(idx + 1, len(pool), title[:50]))
            ok = download_image(seed_str, target_path)
            if not ok:
                print('    image FAILED — лот не создан')
                continue

            image_url = '/static/lot_images/{}'.format(filename)
            end_hours = offsets_pool[idx]
            lot_id = seed_lot(conn, seller_id, lot_data, end_hours, image_url)
            created += 1
            print('    lot #{} · ends in {:.1f}h · {}'.format(lot_id, end_hours, image_url))

            if not args.no_bids and user_ids:
                bid_count = random.randint(2, 8)
                placed = seed_bids_for_lot(conn, lot_id, lot_data, user_ids, seller_id, bid_count)
                print('    +{} bids'.format(placed))

        conn.commit()

    print()
    print('=' * 64)
    print('Done. Created: {}. Skipped: {}.'.format(created, skipped))
    print('Images saved to: {}'.format(images_dir))
    print('Открой http://127.0.0.1:5000/ — лоты с картинками в каталоге.')


if __name__ == '__main__':
    main()
