"""
Сидер реалистичных аукционов для презентации.

Создаёт две группы:
  • SHORT — заканчиваются через 14-15 часов (горящие)
  • LONG  — заканчиваются через 36-72 часа (свежие)

Картинки — заранее выбранные имена в static/lot_images/.
Просто положите туда файл с указанным именем — он подцепится автоматически.

Запуск:
    py -3 seed_lots.py
"""
import os
import random
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from dotenv import load_dotenv
load_dotenv()

import models  # noqa: E402


# === НАСТРОЙКИ ===
SELLER_USERNAME = 'demo_anna'   # от чьего имени публикуем
LISTING_FEE = Decimal('0')       # сидер не списывает деньги
FVF_PCT = Decimal('10')


# === ДАННЫЕ ЛОТОВ ===
# Структура: title, artist, lot_type, start_price_usd, bid_step_usd, image_filename, description, concert_offset_days

SHORT = [
    # Заканчиваются через 14-15 часов
    ('Концерт Imagine Dragons · Москва', 'Imagine Dragons',
     'tickets', 180, 10, 'imagine_dragons.jpg',
     'Партер. 2 билета рядом. Концерт в Олимпийском.', 35),

    ('VIP-ложа на финал Лиги Чемпионов', 'UEFA',
     'vip', 850, 50, 'champions_league.jpg',
     'VIP-ложа на 4 персоны. Включён фуршет, паркинг.', 60),

    ('Stand-up Comedy Club · Москва', 'Comedy Club',
     'tickets', 70, 5, 'comedy_club.jpg',
     'Первые ряды. Резиденты Comedy Club. Шоу 18+.', 21),

    ('Метро 2033 · The ROXY Theatre', 'Артемий Лебедев',
     'tickets', 120, 10, 'metro_2033.jpg',
     'Премьерный показ. 5 ряд центр.', 28),
]

LONG = [
    # Заканчиваются через 36-72 часа
    ('Финал Что? Где? Когда? · Останкино', 'Первый канал',
     'vip', 350, 20, 'chgk_final.jpg',
     'VIP-стол. Зимняя серия игр.', 55),

    ('Концерт Linkin Park Tribute', 'Tribute LP',
     'tickets', 95, 5, 'linkin_park_tribute.jpg',
     'Партер, фан-зона у сцены.', 42),

    ('Балет «Лебединое озеро» · Большой театр', 'Большой театр',
     'tickets', 240, 15, 'swan_lake.jpg',
     'Историческая сцена. 7 ряд партер.', 70),

    ('Хоккей: СКА — ЦСКА · Ледовый', 'КХЛ',
     'tickets', 130, 10, 'hockey_ska.jpg',
     'Места возле скамейки команд.', 18),

    ('Стол на двоих · ресторан White Rabbit', 'White Rabbit',
     'table', 200, 15, 'white_rabbit.jpg',
     'Окно с видом на Москву. Дегустационное меню.', 12),

    ('VIP-проход на Comic Con Moscow', 'Comic Con',
     'vip', 160, 10, 'comic_con.jpg',
     'Все 3 дня. Без очереди. Закрытые автограф-сессии.', 90),

    ('Концерт The Hatters · Adrenaline', 'The Hatters',
     'tickets', 80, 5, 'the_hatters.jpg',
     'Танцпол. Закрытая встреча после концерта.', 33),

    ('Билет на премьеру Marvel · IMAX Каро', 'IMAX',
     'tickets', 60, 5, 'marvel_imax.jpg',
     'IMAX 3D, премьерный показ в полночь.', 8),

    ('Дегустация виски · Whisky Rooms', 'Whisky Rooms',
     'table', 150, 10, 'whisky_rooms.jpg',
     'Сет из 8 виски. Сомелье. На двоих.', 14),

    ('Открытие сезона Большого театра · ВИП', 'Большой театр',
     'vip', 600, 30, 'bolshoi_opening.jpg',
     'VIP-фойе, шампанское, 4 ряд бенуар.', 45),
]


def get_or_create_seller(conn):
    with conn.cursor() as cur:
        cur.execute('SELECT id, username FROM users WHERE username = %s', (SELLER_USERNAME,))
        row = cur.fetchone()
        if row:
            return int(row[0])
        # Создадим dev-юзера
        cur.execute(
            "INSERT INTO users (username, email, country, vk_id) "
            "VALUES (%s, %s, 'RU', %s) RETURNING id",
            (SELLER_USERNAME, SELLER_USERNAME + '@bidstage.local', random.randint(1_000_000_000, 1_999_999_999)),
        )
        return int(cur.fetchone()[0])


def seed_lot(conn, seller_id, data, end_offset_hours):
    title, artist, lot_type, start_usd, step_usd, image_filename, description, concert_days = data
    end_time = datetime.now(timezone.utc) + timedelta(hours=end_offset_hours)
    concert_date = datetime.now(timezone.utc) + timedelta(days=concert_days)
    duration_seconds = int(end_offset_hours * 3600)
    image_url = '/static/lot_images/{}'.format(image_filename)

    lot_id = models.create_lot(
        conn, seller_id,
        title, artist, description, concert_date, lot_type,
        Decimal(str(start_usd)), Decimal(str(step_usd)),
        end_time, duration_seconds,
        False, LISTING_FEE, FVF_PCT,
        image_url=image_url,
    )
    return lot_id, image_filename


def main():
    images_dir = os.path.join(os.path.dirname(__file__), 'static', 'lot_images')
    os.makedirs(images_dir, exist_ok=True)

    print('Seeding auctions...')
    print('=' * 60)
    created = []

    with models.get_conn() as conn:
        seller_id = get_or_create_seller(conn)
        print('Seller: {} (id={})'.format(SELLER_USERNAME, seller_id))
        print()

        # Горящие 14-15 часов
        print('SHORT (заканчиваются через 14-15 часов):')
        for d in SHORT:
            hrs = random.uniform(14, 15)
            lot_id, fn = seed_lot(conn, seller_id, d, hrs)
            print('  #{:>3}  {:<45}  → static/lot_images/{}'.format(lot_id, d[0][:45], fn))
            created.append((lot_id, fn))

        print()
        print('LONG (заканчиваются через 36-72 часа):')
        for d in LONG:
            hrs = random.uniform(36, 72)
            lot_id, fn = seed_lot(conn, seller_id, d, hrs)
            print('  #{:>3}  {:<45}  → static/lot_images/{}'.format(lot_id, d[0][:45], fn))
            created.append((lot_id, fn))

        conn.commit()

    print()
    print('=' * 60)
    print('Done. {} lots created.'.format(len(created)))
    print()
    print('Положите картинки сюда: {}'.format(images_dir))
    print('Имена файлов перечислены выше после стрелки →')
    print()
    print('Лоты без файла картинки покажут градиентную заглушку с иконкой 🎫.')


if __name__ == '__main__':
    main()
