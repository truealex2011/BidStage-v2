"""Сид: 35 разнообразных лотов от разных продавцов.

- Длительность лота: 18-72 часа (рандом).
- Половина — featured=TRUE.
- Распределение продавцов: каждый лот случайному demo-юзеру.
- Картинки не указываются (image_url = NULL) — продавец зальёт через UI.

Запуск:
    py seed_demo_lots.py
"""
import os
import sys
import random
import hashlib
from decimal import Decimal
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

load_dotenv()

import models  # noqa: E402


DEMO_USERS = [
    {'username': 'demo_anna', 'email': 'anna@bidstage.demo', 'country': 'AM'},
    {'username': 'demo_boris', 'email': 'boris@bidstage.demo', 'country': 'RU'},
    {'username': 'demo_carl', 'email': 'carl@bidstage.demo', 'country': 'OTHER'},
    {'username': 'demo_diana', 'email': 'diana@bidstage.demo', 'country': 'RU'},
    {'username': 'demo_elena', 'email': 'elena@bidstage.demo', 'country': 'AM'},
    {'username': 'demo_felix', 'email': 'felix@bidstage.demo', 'country': 'OTHER'},
    {'username': 'demo_gleb', 'email': 'gleb@bidstage.demo', 'country': 'RU'},
    {'username': 'demo_helen', 'email': 'helen@bidstage.demo', 'country': 'AM'},
]

LOTS = [
    # КОНЦЕРТЫ
    ('Concert · Imagine Dragons · Mercury Tour', 'Imagine Dragons',
     'Партер фан-зона у сцены. Ряд 3, секция А. Концерт в Crocus City Hall.', 'tickets', 120, 10),
    ('Concert · The Weeknd · After Hours Til Dawn', 'The Weeknd',
     'VIP-партер. Доступ за 30 мин до открытия. Ряд 1, центр.', 'tickets', 250, 15),
    ('Concert · Linkin Park · Reunion Tour', 'Linkin Park',
     'Ранний вход, фан-зона А1. Олимпийский, Москва.', 'tickets', 180, 10),
    ('Concert · Coldplay · Music of the Spheres', 'Coldplay',
     'Танцпол, ближе к подиуму B-stage. Lights браслет в подарок.', 'tickets', 200, 15),
    ('Concert · Twenty One Pilots · Clancy Tour', 'Twenty One Pilots',
     'Партер, секция стандарт. ВТБ Арена.', 'tickets', 90, 5),
    ('Концерт Metallica · M72 World Tour', 'Metallica',
     'Sound Stage Pit, фан-зона у сцены. Включена футболка.', 'tickets', 220, 15),
    ('Concert · Taylor Swift · The Eras Tour', 'Taylor Swift',
     'VIP-пакет, ряд 5, секция 102. Доступ к меню Friendship Bracelets.', 'tickets', 400, 25),
    ('Концерт The Hatters · Adrenaline Tour', 'The Hatters',
     'Танцпол. Ranspb Hall. Включена флэшка с автографом.', 'tickets', 40, 3),

    # СПОРТ
    ('Хоккей · СКА — ЦСКА · Решающий матч', 'Ледовый дворец',
     'Сектор A12, ряд 5. Полуфинал плей-офф КХЛ.', 'tickets', 80, 5),
    ('UFC Fight Night · Главный бой', 'T-Mobile Arena',
     'Ringside, ряд 2. Доступ к after-party.', 'tickets', 1500, 50),
    ('Финал Лиги чемпионов · Real vs Bayern', 'Estadio Bernabéu',
     'Сектор 305, ряд 12. Билет именной с QR.', 'tickets', 600, 40),
    ('Tennis · Roland Garros · Полуфинал женщин', 'Court Philippe-Chatrier',
     'Категория 1, ряд 8. С шампанским в перерыве.', 'tickets', 350, 20),
    ('Формула-1 · Гран-при Монако · Hospitality', 'Circuit de Monaco',
     'Hospitality Suite, поворот Casino. Завтрак шампанским.', 'tickets', 2200, 100),

    # РЕСТОРАНЫ И ГАСТРО
    ('Стол на двоих · White Rabbit Moscow', 'White Rabbit',
     'Окно с видом на Кремль. Сет-меню от шефа Мухина. Бутылка вина.', 'table', 200, 15),
    ('Гастро-сет · Twins Garden · 2 ★ Michelin', 'Twins Garden',
     '12 курсов от братьев Березуцких. Винное сопровождение.', 'table', 350, 20),
    ('Дегустация виски · Whisky Society', 'Whisky Society',
     '8 редких сортов 18-25 лет. Сомелье-комментатор. На двоих.', 'table', 150, 10),
    ('Шеф-стол · Madame Wong', 'Madame Wong',
     'Тет-а-тет с шефом, омакасе из 14 курсов. На двоих.', 'table', 280, 20),
    ('Ужин-свидание · Sky Lounge', 'Sky Lounge',
     'Терраса с панорамой. Сет на 5 курсов с парингом. Розы в подарок.', 'table', 180, 15),

    # VIP И КЛУБЫ
    ('VIP-ложа · Большой театр · Лебединое озеро', 'Большой театр',
     'Бенуар №3 на 4 персоны. Шампанское в антракте.', 'vip', 800, 50),
    ('VIP-проход · Comic Con Moscow · Все 3 дня', 'Comic Con',
     'Skip-the-line, эксклюзивный мерч-набор, доступ к закрытой панели.', 'vip', 250, 15),
    ('VIP-табл · Soho Rooms', 'Soho Rooms',
     'Stage table на 6 персон. 2 бутылки шампанского + шоты.', 'vip', 500, 30),
    ('Backstage-пасс · Concert Aftershow', 'Imagine Dragons',
     'Встреча с группой, фото, автограф на твоём билете. До 30 минут.', 'vip', 1200, 100),
    ('VIP-ложа · Кремлёвский Дворец · Евгений Онегин', 'Кремлёвский балет',
     'Президентская ложа, ряд А, на 6 персон. Сопровождение администратора.', 'vip', 900, 50),

    # ТЕАТРЫ И ШОУ
    ('Балет «Лебединое озеро» · Мариинский театр', 'Мариинский театр',
     'Партер, ряд 3, центр. Постановка с прима-балериной.', 'tickets', 280, 15),
    ('Премьера Marvel · IMAX Каро 11 · Полночь', 'IMAX',
     '2 билета на полуночный показ + попкорн-комбо + футболка с символикой.', 'tickets', 80, 5),
    ('Stand-up · Comedy Battle · Финал', 'Comedy Wars',
     'VIP-зона, столы первого ряда. С нетворкингом после шоу.', 'tickets', 150, 10),
    ('Опера · Met Live in HD · Турандот', 'Метрополитен опера',
     'Прямая трансляция из Метрополитен-оперы. На двоих.', 'tickets', 40, 3),

    # ЭКСКЛЮЗИВ И ОПЫТЫ
    ('Полёт на воздушном шаре над Каппадокией', 'Cappadocia Balloons',
     '1 час полёта на рассвете на двоих. Шампанское после посадки.', 'vip', 300, 20),
    ('Прогулка на яхте · Финский залив', 'Яхт-клуб «Геркулес»',
     '3 часа на парусной яхте 12 м. До 6 человек. Шкипер + закуски.', 'vip', 400, 30),
    ('Спа-уик-енд · Four Seasons Лиговский', 'Four Seasons',
     '2 ночи в люксе для двоих. Спа-программа 4 часа.', 'vip', 600, 40),
    ('Гастротур по Грузии · 3 дня', 'Wine Caucasus',
     'Перелёт не включён. Винодельня, ужин у шефа, экскурсия. На двоих.', 'vip', 450, 25),
    ('Урок гольфа с тренером', 'Скай-Парк Гольф',
     '2 часа индивидуального урока. Включён прокат и ланч.', 'table', 120, 10),

    # БЫСТРЫЕ (всё равно не меньше 18 часов как ты просил, но цена низкая)
    ('Концерт сегодня вечером · The Hatters', 'The Hatters',
     'Концерт в маленьком зале. Стэндинг. Включена флэшка.', 'tickets', 25, 2),
    ('Завтра матч ЦСКА — Спартак · трибуна А', 'РЖД Арена',
     'Сектор A28, ряд 12. Открытая трибуна. Хот-дог в подарок.', 'tickets', 35, 3),
    ('Stand-up Артур Чапарян · сегодня в 21:00', 'Comedy Club',
     'Главный зал, столики первого ряда. Закуски + 1 коктейль.', 'tickets', 20, 2),
]


def _get_or_create_user(conn, user):
    with conn.cursor() as cur:
        cur.execute('SELECT id FROM users WHERE username = %s', (user['username'],))
        row = cur.fetchone()
        if row:
            return int(row[0])
        # Создаём пользователя с фейковым password_hash и пополненным балансом
        password_hash = hashlib.sha256(('demo_password_' + user['username']).encode()).hexdigest()
        cur.execute(
            "INSERT INTO users (username, email, password_hash, country, balance_usd) "
            "VALUES (%s, %s, %s, %s, %s) RETURNING id",
            (user['username'], user['email'], password_hash, user['country'], Decimal('5000.00')),
        )
        return int(cur.fetchone()[0])


def main():
    parser_seed = int(sys.argv[1]) if len(sys.argv) > 1 else 42
    random.seed(parser_seed)

    with models.get_conn() as conn:
        # Гарантируем что колонки seller_id, featured, listing_fee_usd, final_value_fee_pct существуют
        models.ensure_seller_columns(conn)
        conn.commit()

        # 1. Создаём пользователей
        user_ids = []
        for u in DEMO_USERS:
            uid = _get_or_create_user(conn, u)
            user_ids.append(uid)
            print('user', u['username'], '=> id', uid)
        conn.commit()

        # 2. Случайно перемешиваем индексы пользователей чтобы продавцы шли вперемешку
        seller_pool = []
        for _ in range(len(LOTS) // len(user_ids) + 2):
            shuf = list(user_ids)
            random.shuffle(shuf)
            seller_pool.extend(shuf)

        # 3. Половина — featured
        n = len(LOTS)
        featured_idx = set(random.sample(range(n), n // 2))

        now = datetime.now(timezone.utc)
        for i, (title, artist, desc, lot_type, start_price, step) in enumerate(LOTS):
            seller_id = seller_pool[i]
            duration_hours = random.randint(18, 72)
            end_time = now + timedelta(hours=duration_hours)
            concert_date = now + timedelta(days=random.randint(7, 60))
            duration_seconds = duration_hours * 3600
            featured = i in featured_idx
            listing_fee = Decimal('5.00') + (Decimal('10.00') if featured else Decimal('0'))
            lot_id = models.create_lot(
                conn,
                seller_id=seller_id,
                title=title,
                artist=artist,
                description=desc,
                concert_date=concert_date,
                lot_type=lot_type,
                start_price_usd=Decimal(start_price),
                bid_step_usd=Decimal(step),
                end_time=end_time,
                original_duration_seconds=duration_seconds,
                featured=featured,
                listing_fee_usd=listing_fee,
                final_value_fee_pct=Decimal('10.00'),
                image_url=None,
            )
            tag = ' [FEATURED]' if featured else ''
            print(f'  lot {lot_id:3d}: {title[:45]:45s} seller={seller_id} {duration_hours}h{tag}')
        conn.commit()

    print()
    print(f'Done. {len(LOTS)} лотов созданы. Половина ({n//2}) в карусели «Топ».')
    print('Картинки залей вручную через UI на странице каждого лота (только продавец может загружать).')


if __name__ == '__main__':
    main()
