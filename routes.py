import json
import logging
import os
import re
import hmac
import hashlib
import secrets
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.parse import urlparse

import psycopg2
from flask import Blueprint, render_template, jsonify, request, redirect, session, abort, current_app, send_from_directory

import models
import currency
import vk_auth
import payments
import socket_events
import translator
import notify
import smart_search


logger = logging.getLogger('bidstage.routes')

bp = Blueprint('main', __name__)


@bp.app_context_processor
def _inject_session_user():
    user_id = session.get('user_id')
    if user_id is None:
        return {'me': None, 'notif_unread': 0, 'chat_unread': 0}
    try:
        with models.get_conn() as conn:
            models.ensure_balance_column(conn)
            user = models.get_user(conn, int(user_id))
            balance = models.get_balance(conn, int(user_id)) if user else 0.0
            conn.commit()
    except Exception:
        return {'me': None, 'notif_unread': 0, 'chat_unread': 0}
    if user is None:
        return {'me': None, 'notif_unread': 0, 'chat_unread': 0}
    try:
        n_unread = notify.unread_count(int(user_id))
    except Exception:
        n_unread = 0
    try:
        c_unread = notify.chat_unread_total(int(user_id))
    except Exception:
        c_unread = 0
    return {
        'me': {'id': int(user['id']), 'username': user.get('username') or 'user', 'country': user.get('country') or 'OTHER', 'balance_usd': balance},
        'notif_unread': n_unread,
        'chat_unread': c_unread,
    }


def _format_concert_date(value):
    if value is None:
        return ''
    if isinstance(value, str):
        return value
    return value.strftime('%d %b %Y · %H:%M')


def _amd_from_usd(amount_usd):
    try:
        rates, _ = currency.get_rates()
    except currency.RatesUnavailableError:
        rates = {'AMD': 390.0}
    rate = rates.get('AMD', 390.0)
    amount = Decimal(str(amount_usd)) * Decimal(str(rate))
    return int(amount.quantize(Decimal('1')))


def _end_offset_seconds(end_time):
    if end_time is None:
        return 0
    now = datetime.now(timezone.utc)
    delta = end_time - now
    return max(0, int(delta.total_seconds()))


def _bid_count(conn, lot_id):
    with conn.cursor() as cur:
        cur.execute(
            'SELECT COUNT(*) FROM bids WHERE lot_id = %s AND share_verified = TRUE',
            (lot_id,),
        )
        row = cur.fetchone()
        return int(row[0]) if row else 0


def _build_lot_view(conn, raw_lot):
    bid_count = _bid_count(conn, raw_lot['id'])
    end_offset = _end_offset_seconds(raw_lot['end_time'])
    current_price_usd_value = float(raw_lot.get('current_price_usd') or raw_lot.get('start_price_usd') or 0)
    current_price_amd = _amd_from_usd(current_price_usd_value)
    step_amd = _amd_from_usd(raw_lot['bid_step_usd'])
    # end_ts_ms: основной путь — UNIX-ms из end_time; если по какой-то причине пусто
    # (битая запись/search-роу без поля), делаем фолбэк через текущее время + offset.
    end_ts_ms = 0
    end_time = raw_lot.get('end_time')
    if end_time is not None:
        try:
            end_ts_ms = int(end_time.timestamp() * 1000)
        except Exception:
            end_ts_ms = 0
    if end_ts_ms <= 0 and end_offset > 0:
        end_ts_ms = int(datetime.now(timezone.utc).timestamp() * 1000) + end_offset * 1000
    return {
        'id': int(raw_lot['id']),
        'title': raw_lot['title'],
        'artist': raw_lot['artist'],
        'description': raw_lot.get('description') or '',
        'lot_type': raw_lot['lot_type'],
        'status': raw_lot['status'],
        'start_price_usd': float(raw_lot['start_price_usd']),
        'bid_step_usd': float(raw_lot['bid_step_usd']),
        'concert_date_display': _format_concert_date(raw_lot['concert_date']),
        'current_price_amd': current_price_amd,
        'current_price_usd_value': current_price_usd_value,
        'end_offset_seconds': end_offset,
        'end_ts_ms': end_ts_ms,
        'end_time_ms': end_ts_ms,
        'step_amd': step_amd,
        'bid_count': bid_count,
        'image_url': raw_lot.get('image_url'),
        'layout': 's',
    }


def _assign_catalog_layout(lots):
    """Bento-раскладка со случайным распределением размеров.
    XL и L раскладываются по разным частям списка, чтобы не стояли рядом.
    Сам порядок лотов в списке тоже перемешивается случайно.
    """
    if not lots:
        return lots
    if len(lots) < 4:
        for l in lots:
            l['layout'] = 's'
        return lots

    import random as _rnd
    rng = _rnd.Random()

    def _has_image(l):
        return bool(l.get('image_url'))

    # Сначала перемешиваем сам список — порядок в DOM будет случайным
    rng.shuffle(lots)

    layout_map = {}
    n = len(lots)

    # Раздаём базовые размеры: 25% m, 55% s, 20% xs
    for l in lots:
        r = rng.random()
        if r < 0.25:
            layout_map[l['id']] = 'm'
        elif r < 0.80:
            layout_map[l['id']] = 's'
        else:
            layout_map[l['id']] = 'xs'

    # XL и L идут только лотам с картинкой и далеко друг от друга
    with_image_indices = [i for i, l in enumerate(lots) if _has_image(l)]
    if with_image_indices:
        # XL — случайный лот с картинкой из ПЕРВОЙ ТРЕТИ списка
        third = max(1, n // 3)
        xl_pool = [i for i in with_image_indices if i < third] or with_image_indices
        xl_idx = rng.choice(xl_pool)
        layout_map[lots[xl_idx]['id']] = 'xl'

        # L — случайный лот с картинкой из ПОСЛЕДНЕЙ ТРЕТИ (далеко от XL)
        l_pool = [i for i in with_image_indices if i >= 2 * third and i != xl_idx]
        if not l_pool:
            # fallback: любой с дистанцией от XL хотя бы 4
            l_pool = [i for i in with_image_indices if abs(i - xl_idx) >= 4]
        if not l_pool:
            l_pool = [i for i in with_image_indices if i != xl_idx]
        if l_pool:
            l_idx = rng.choice(l_pool)
            layout_map[lots[l_idx]['id']] = 'l'

    for l in lots:
        l['layout'] = layout_map.get(l['id'], 's')
    return lots


def _build_category_counts(lots):
    """Подсчитывает сколько лотов в каждой категории (для табов)."""
    counts = {'all': len(lots), 'tickets': 0, 'vip': 0, 'table': 0, 'hot': 0}
    for l in lots:
        t = l.get('lot_type') or 'tickets'
        if t in counts:
            counts[t] += 1
        if (l.get('end_offset_seconds') or 0) < 3600 and l.get('status') == 'active':
            counts['hot'] += 1
    return counts


@bp.route('/sw.js')
def service_worker():
    """Service Worker должен подаваться с корня, чтобы scope был / """
    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    response = send_from_directory(static_dir, 'sw.js', mimetype='application/javascript')
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Service-Worker-Allowed'] = '/'
    return response


@bp.route('/lot-image/<path:filename>')
def lot_image(filename):
    """Отдача загруженных картинок лотов из persistent volume /data/lot_images/.
    Если файл не найден там — fallback в static/lot_images/."""
    persist = os.path.join('/data', 'lot_images')
    if os.path.isfile(os.path.join(persist, filename)):
        return send_from_directory(persist, filename)
    fallback = os.path.join(os.path.dirname(__file__), 'static', 'lot_images')
    return send_from_directory(fallback, filename)


@bp.route('/manifest.webmanifest')
def manifest():
    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    return send_from_directory(static_dir, 'manifest.webmanifest', mimetype='application/manifest+json')


@bp.route('/offline')
def offline_page():
    """Страница для отображения когда сеть недоступна (резерв)."""
    return render_template('offline.html')


@bp.route('/api/push/vapid-public-key')
def api_push_vapid_public_key():
    """Публичный ключ VAPID для подписки клиента (если задан в env)."""
    return jsonify({'key': os.environ.get('VAPID_PUBLIC_KEY', '')})


@bp.route('/api/push/subscribe', methods=['POST'])
def api_push_subscribe():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    endpoint = (data.get('endpoint') or '').strip()
    keys = data.get('keys') or {}
    p256dh = (keys.get('p256dh') or '').strip()
    auth = (keys.get('auth') or '').strip()
    if not endpoint or not p256dh or not auth:
        return jsonify({'error': 'missing_fields'}), 400
    user_agent = request.headers.get('User-Agent', '')[:500]
    with models.get_conn() as conn:
        models.ensure_push_subscriptions_table(conn)
        models.push_subscribe(conn, int(user_id), endpoint, p256dh, auth, user_agent)
        conn.commit()
    return jsonify({'ok': True})


@bp.route('/api/push/unsubscribe', methods=['POST'])
def api_push_unsubscribe():
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    endpoint = (data.get('endpoint') or '').strip()
    if not endpoint:
        return jsonify({'error': 'missing_endpoint'}), 400
    with models.get_conn() as conn:
        models.ensure_push_subscriptions_table(conn)
        models.push_unsubscribe(conn, endpoint)
        conn.commit()
    return jsonify({'ok': True})


@bp.route('/')
def index():
    q = (request.args.get('q') or '').strip()
    with models.get_conn() as conn:
        if q:
            all_lots = models.all_lots_for_search(conn)
            ranked = smart_search.smart_search(all_lots, q, limit=60)
            if not ranked:
                ranked = models.search_active_lots(conn, q, limit=60)
            raw_lots = ranked
        else:
            raw_lots = models.get_active_lots_with_top_bid(conn)
        featured_raw = models.get_featured_active_lots(conn, limit=12)
        lots = [_build_lot_view(conn, l) for l in raw_lots]
        featured_lots = [_build_lot_view(conn, l) for l in featured_raw]
        critical = sum(1 for l in lots if l['end_offset_seconds'] < 600)
        total_volume_usd = sum(l['current_price_amd'] for l in lots)
        # Доп метрики для hero-стрипы
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM bids WHERE share_verified = TRUE AND created_at >= NOW() - INTERVAL '24 hours'")
            bids_today_row = cur.fetchone()
            bids_today = int(bids_today_row[0]) if bids_today_row else 0
            cur.execute("SELECT COUNT(DISTINCT user_id) FROM bids WHERE share_verified = TRUE AND created_at >= NOW() - INTERVAL '24 hours'")
            bidders_row = cur.fetchone()
            bidders_today = int(bidders_row[0]) if bidders_row else 0
        conn.commit()
    stats = {
        'active_lots': '{:02d}'.format(len(lots)),
        'total_volume': '{:,}'.format(total_volume_usd),
        'critical_timers': '{:02d}'.format(critical),
        'bids_today': bids_today,
        'bidders_today': bidders_today,
    }
    _assign_catalog_layout(lots)
    category_counts = _build_category_counts(lots)
    return render_template('index.html', lots=lots, featured_lots=featured_lots, stats=stats, search_query=q, category_counts=category_counts)


@bp.route('/api/lots')
def api_lots_by_status():
    status = (request.args.get('status') or 'active').strip().lower()
    with models.get_conn() as conn:
        if status == 'ended':
            raw = models.get_ended_lots(conn, limit=60)
        elif status == 'upcoming':
            raw = models.get_upcoming_lots(conn, limit=60)
        else:
            raw = models.get_active_lots_with_top_bid(conn)
        lots = [_build_lot_view(conn, l) for l in raw]
        conn.commit()
    out = []
    for l in lots:
        out.append({
            'id': int(l['id']),
            'title': l['title'],
            'artist': l['artist'],
            'lot_type': l.get('lot_type'),
            'image_url': l.get('image_url'),
            'status': l['status'],
            'current_price_usd_value': float(l.get('current_price_usd_value') or 0),
            'current_price_amd': int(l.get('current_price_amd') or 0),
            'end_offset_seconds': int(l.get('end_offset_seconds') or 0),
            'end_ts_ms': int(l.get('end_ts_ms') or 0),
            'step_amd': int(l.get('step_amd') or 0),
            'end_time_display': l.get('end_time_display') or '',
        })
    return jsonify({'status': status, 'lots': out})


@bp.route('/api/search')
def api_search():
    q = (request.args.get('q') or '').strip()
    cat = (request.args.get('cat') or '').strip().lower()
    status = (request.args.get('status') or '').strip().lower()
    try:
        max_price = float(request.args.get('max_price') or 0) or None
    except (TypeError, ValueError):
        max_price = None
    try:
        min_price = float(request.args.get('min_price') or 0) or None
    except (TypeError, ValueError):
        min_price = None
    has_filters = bool(cat or status or max_price or min_price)
    if len(q) < 2 and not has_filters:
        return jsonify({'results': []})
    with models.get_conn() as conn:
        all_lots = models.all_lots_for_search(conn)
        conn.commit()
    if len(q) >= 2:
        ranked = smart_search.smart_search(all_lots, q, limit=60)
        if not ranked:
            with models.get_conn() as conn:
                rows = models.quick_search_lots(conn, q, limit=60)
                conn.commit()
            ranked = rows
    else:
        ranked = list(all_lots)
    # Применяем фильтры пост-фактум, чтобы не ломать smart_search
    def keep(r):
        if cat and cat != 'all':
            if cat == 'hot':
                end_t = r.get('end_time')
                if end_t is None:
                    return False
                offset = (end_t - datetime.now(timezone.utc)).total_seconds()
                if offset >= 3600 or r.get('status') != 'active':
                    return False
            elif (r.get('lot_type') or '').lower() != cat:
                return False
        if status and (r.get('status') or '').lower() != status:
            return False
        try:
            price = float(r.get('current_price_usd') or 0)
        except (TypeError, ValueError):
            price = 0.0
        if max_price is not None and price > max_price:
            return False
        if min_price is not None and price < min_price:
            return False
        return True
    ranked = [r for r in ranked if keep(r)][:24]
    out = []
    for r in ranked:
        out.append({
            'id': int(r['id']),
            'title': r['title'],
            'artist': r['artist'],
            'lot_type': r['lot_type'],
            'image_url': r.get('image_url'),
            'status': r['status'],
            'end_time_display': r['end_time'].strftime('%d.%m %H:%M') if r.get('end_time') else '',
            'current_price_usd': '{:.0f}'.format(float(r['current_price_usd'])),
            'url': '/lot/{}'.format(int(r['id'])),
        })
    return jsonify({'results': out, 'query': q, 'filters': {'cat': cat, 'status': status, 'max_price': max_price, 'min_price': min_price}})


@bp.route('/lot/<int:lot_id>')
def lot_detail(lot_id):
    user_id = session.get('user_id')
    with models.get_conn() as conn:
        raw = models.get_lot(conn, lot_id)
        if raw is None:
            conn.commit()
            abort(404)
        max_amount = models.get_max_verified_amount(conn, lot_id)
        raw['current_price_usd'] = max_amount if max_amount is not None else raw['start_price_usd']
        view = _build_lot_view(conn, raw)
        bids_raw = models.get_all_bids_for_lot(conn, lot_id, 30)
        with conn.cursor() as cur:
            cur.execute('SELECT COUNT(*) FROM bids WHERE lot_id = %s', (lot_id,))
            total_bids = int(cur.fetchone()[0])
            cur.execute('SELECT COUNT(DISTINCT user_id) FROM bids WHERE lot_id = %s AND share_verified = TRUE', (lot_id,))
            unique_bidders = int(cur.fetchone()[0])
            cur.execute('SELECT MIN(amount_usd) FROM bids WHERE lot_id = %s AND share_verified = TRUE', (lot_id,))
            first_amount_row = cur.fetchone()
            first_verified = float(first_amount_row[0]) if first_amount_row and first_amount_row[0] is not None else None
        live_stats = models.get_lot_live_stats(conn, lot_id)
        models.ensure_watchlist_table(conn)
        is_watching = models.is_watching(conn, user_id, lot_id) if user_id else False
        conn.commit()
    current_usd = float(raw['current_price_usd'] or raw['start_price_usd'])
    start_usd = float(raw['start_price_usd'])
    step_usd = float(raw['bid_step_usd'])
    next_min_usd = current_usd + step_usd if max_amount is not None else start_usd
    growth_pct = ((current_usd - start_usd) / start_usd * 100.0) if start_usd > 0 else 0.0
    view['start_price_usd_display'] = '{:.2f}'.format(start_usd)
    view['current_price_usd_display'] = '{:.2f}'.format(current_usd)
    view['next_min_usd_display'] = '{:.2f}'.format(next_min_usd)
    view['step_usd_display'] = '{:.2f}'.format(step_usd)
    view['growth_pct'] = '{:.1f}'.format(growth_pct)
    view['next_min_amd'] = _amd_from_usd(next_min_usd)
    view['start_price_amd'] = _amd_from_usd(start_usd)
    view['total_bids'] = total_bids
    view['unique_bidders'] = unique_bidders
    view['concert_iso'] = raw['concert_date'].isoformat() if raw.get('concert_date') else ''
    view['end_time_display'] = raw['end_time'].strftime('%d.%m.%Y · %H:%M UTC') if raw.get('end_time') else ''
    view['original_duration_hours'] = round((raw.get('original_duration_seconds') or 0) / 3600, 1)
    view['end_time_ms'] = int(raw['end_time'].timestamp() * 1000) if raw.get('end_time') else 0
    view['original_duration_ms'] = int((raw.get('original_duration_seconds') or 0)) * 1000
    top_bidders_raw = models.get_top_bidders_for_lot(conn, lot_id, 5) if False else None
    top_bidders = []
    if True:
        with models.get_conn() as conn2:
            top5 = models.get_top_bidders_for_lot(conn2, lot_id, 5)
            conn2.commit()
        for i, b in enumerate(top5):
            top_bidders.append({
                'rank': i + 1,
                'username': b['username'],
                'amount_usd': '{:.2f}'.format(float(b['max_amount'])),
                'amount_amd': _amd_from_usd(float(b['max_amount'])),
                'bid_count': int(b['bid_count']),
            })
    hourly_max = max((int(h['cnt']) for h in live_stats['hourly']), default=1)
    hourly = []
    for h in live_stats['hourly']:
        cnt = int(h['cnt'])
        hourly.append({
            'hour': h['hour'].strftime('%H:00') if h.get('hour') else '',
            'count': cnt,
            'pct': round(cnt / hourly_max * 100),
        })
    bids = []
    for b in bids_raw:
        if not b.get('share_verified'):
            continue
        bids.append({
            'id': int(b['id']),
            'username': b.get('username') or 'anon',
            'amount_usd': '{:.2f}'.format(float(b['amount_usd'])),
            'amount_amd': _amd_from_usd(float(b['amount_usd'])),
            'verified': bool(b['share_verified']),
            'created_at_display': b['created_at'].strftime('%d.%m.%Y · %H:%M') if b.get('created_at') else '',
        })
    auto_verify = os.environ.get('VK_AUTO_VERIFY') == '1' or (not os.environ.get('VK_CLIENT_ID') and not os.environ.get('VK_SERVICE_TOKEN'))
    seller_username = None
    seller_stats = None
    if raw.get('seller_id'):
        with models.get_conn() as conn3:
            models.ensure_reviews_table(conn3)
            with conn3.cursor() as cur3:
                cur3.execute('SELECT username FROM users WHERE id = %s', (int(raw['seller_id']),))
                row = cur3.fetchone()
                if row:
                    seller_username = row[0]
            seller_stats = models.get_seller_stats(conn3, int(raw['seller_id']))
            conn3.commit()
    view['seller_id'] = int(raw['seller_id']) if raw.get('seller_id') else None
    view['seller_username'] = seller_username
    view['seller_stats'] = seller_stats
    similar_lots = []
    with models.get_conn() as conn4:
        with conn4.cursor() as cur4:
            cur4.execute(
                "SELECT id, title, artist, lot_type, end_time, "
                "COALESCE((SELECT MAX(b.amount_usd) FROM bids b WHERE b.lot_id=l.id AND b.share_verified=TRUE), l.start_price_usd) AS current_price_usd "
                "FROM lots l WHERE l.status='active' AND l.id != %s ORDER BY l.end_time ASC LIMIT 3",
                (lot_id,),
            )
            for r in cur4.fetchall():
                similar_lots.append({
                    'id': int(r[0]), 'title': r[1], 'artist': r[2],
                    'lot_type': r[3],
                    'end_time_display': r[4].strftime('%d.%m %H:%M') if r[4] else '',
                    'current_price_usd': '{:.0f}'.format(float(r[5])),
                })
        conn4.commit()
    is_owner = bool(user_id and view.get('seller_id') and int(view['seller_id']) == int(user_id))
    return render_template('lot.html', lot=view, bids=bids, first_verified_usd=first_verified, top_bidders=top_bidders, hourly=hourly, is_watching=is_watching, dev_auto_verify=auto_verify, similar_lots=similar_lots, is_owner=is_owner)


LISTING_FEE_USD = Decimal('5.00')
FEATURED_FEE_USD = Decimal('10.00')
FINAL_VALUE_FEE_PCT = Decimal('10.00')


@bp.route('/sell')
def sell_page():
    user_id = session.get('user_id')
    if user_id is None:
        return redirect('/auth/login')
    with models.get_conn() as conn:
        models.ensure_seller_columns(conn)
        models.ensure_balance_column(conn)
        models.ensure_escrow_columns(conn)
        balance = models.get_balance(conn, user_id)
        my_lots = models.list_seller_lots(conn, user_id, 20)
        escrow_payments = models.get_seller_escrow_payments(conn, user_id)
        escrow_total = models.get_seller_escrow_total(conn, user_id)
        conn.commit()
    formatted = []
    for l in my_lots:
        formatted.append({
            'id': l['id'],
            'title': l['title'],
            'artist': l['artist'],
            'status': l['status'],
            'bid_count': int(l['bid_count']),
            'current_price_usd': '{:.2f}'.format(float(l['current_price_usd'])),
            'start_price_usd': '{:.2f}'.format(float(l['start_price_usd'])),
            'fee_pct': '{:.0f}'.format(float(l['final_value_fee_pct'])),
            'end_time_display': l['end_time'].strftime('%d.%m %H:%M') if l.get('end_time') else '',
        })
    return render_template('sell.html',
        balance=balance,
        escrow_total=escrow_total,
        my_lots=formatted,
        listing_fee=float(LISTING_FEE_USD),
        featured_fee=float(FEATURED_FEE_USD),
        final_value_fee_pct=float(FINAL_VALUE_FEE_PCT),
        escrow_payments=[{
            'id': ep['id'],
            'lot_id': ep['lot_id'],
            'lot_title': ep['lot_title'],
            'buyer_username': ep['buyer_username'],
            'buyer_id': ep['buyer_id'],
            'amount_usd': '{:.2f}'.format(float(ep['amount_usd'])),
            'held_in_escrow': bool(ep.get('held_in_escrow')),
            'released_to_seller': bool(ep.get('released_to_seller')),
            'ticket_delivered': bool(ep.get('ticket_delivered')),
            'ticket_code': ep.get('ticket_code'),
            'buyer_confirmed': bool(ep.get('buyer_confirmed')),
        } for ep in escrow_payments],
    )


@bp.route('/api/lots/create', methods=['POST'])
def api_create_lot():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if notify.is_bot_user(user_id):
        return jsonify({'error': 'bot_cannot_create_lot'}), 403
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    title = (data.get('title') or '').strip()
    artist = (data.get('artist') or '').strip()
    description = (data.get('description') or '').strip()
    lot_type = (data.get('lot_type') or '').strip()
    concert_date_str = (data.get('concert_date') or '').strip()
    duration_hours = data.get('duration_hours')
    duration_minutes = data.get('duration_minutes')
    featured = bool(data.get('featured'))
    if not title or len(title) < 3 or len(title) > 200:
        return jsonify({'error': 'invalid_title'}), 400
    if not artist or len(artist) < 2 or len(artist) > 200:
        return jsonify({'error': 'invalid_artist'}), 400
    if lot_type not in ('tickets', 'vip', 'table'):
        return jsonify({'error': 'invalid_lot_type'}), 400
    try:
        start_price_usd = Decimal(str(data.get('start_price_usd')))
        bid_step_usd = Decimal(str(data.get('bid_step_usd')))
    except (InvalidOperation, TypeError):
        return jsonify({'error': 'invalid_amount'}), 400
    if start_price_usd <= 0 or start_price_usd > Decimal('1000000'):
        return jsonify({'error': 'invalid_start_price'}), 400
    if bid_step_usd <= 0 or bid_step_usd > start_price_usd:
        return jsonify({'error': 'invalid_step'}), 400
    try:
        duration_h = int(duration_hours) if duration_hours is not None else 0
    except (TypeError, ValueError):
        return jsonify({'error': 'invalid_duration'}), 400
    try:
        duration_m = int(duration_minutes) if duration_minutes is not None else 0
    except (TypeError, ValueError):
        return jsonify({'error': 'invalid_duration'}), 400
    if duration_h < 0 or duration_h > 720 or duration_m < 0 or duration_m > 59:
        return jsonify({'error': 'invalid_duration'}), 400
    duration_total_seconds = duration_h * 3600 + duration_m * 60
    if duration_total_seconds < 5 * 60:
        return jsonify({'error': 'invalid_duration', 'message': 'Минимум 5 минут'}), 400
    if duration_total_seconds > 720 * 3600:
        return jsonify({'error': 'invalid_duration', 'message': 'Максимум 720 часов'}), 400
    payment_window_h = data.get('payment_window_hours')
    payment_window_m = data.get('payment_window_minutes')
    try:
        pw_h = int(payment_window_h) if payment_window_h is not None and str(payment_window_h).strip() != '' else 24
        pw_m = int(payment_window_m) if payment_window_m is not None and str(payment_window_m).strip() != '' else 0
    except (TypeError, ValueError):
        return jsonify({'error': 'invalid_payment_window', 'message': 'Введите время оплаты числом'}), 400
    if pw_h < 0 or pw_m < 0 or pw_m > 59:
        return jsonify({'error': 'invalid_payment_window', 'message': 'Минуты от 0 до 59'}), 400
    payment_window_total_min = pw_h * 60 + pw_m
    if payment_window_total_min < 5:
        return jsonify({'error': 'invalid_payment_window', 'message': 'Минимум 5 минут на оплату'}), 400
    if payment_window_total_min > 30 * 24 * 60:
        return jsonify({'error': 'invalid_payment_window', 'message': 'Максимум 30 суток на оплату'}), 400
    try:
        from datetime import datetime as _dt
        concert_date = _dt.fromisoformat(concert_date_str.replace('Z', '+00:00'))
        if concert_date.tzinfo is None:
            concert_date = concert_date.replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return jsonify({'error': 'invalid_concert_date'}), 400
    if concert_date <= datetime.now(timezone.utc):
        return jsonify({'error': 'concert_date_in_past'}), 400
    total_fee = LISTING_FEE_USD + (FEATURED_FEE_USD if featured else Decimal('0'))
    with models.get_conn() as conn:
        models.ensure_seller_columns(conn)
        models.ensure_balance_column(conn)
        balance = Decimal(str(models.get_balance(conn, user_id)))
        if balance < total_fee:
            conn.commit()
            return jsonify({
                'error': 'insufficient_balance',
                'required_usd': float(total_fee),
                'balance_usd': float(balance),
            }), 402
        new_balance = models.deduct_balance(conn, user_id, total_fee)
        if new_balance is None:
            conn.commit()
            return jsonify({'error': 'insufficient_balance'}), 402
        end_time = datetime.now(timezone.utc) + __import__('datetime').timedelta(seconds=duration_total_seconds)
        lot_id = models.create_lot(
            conn, user_id, title, artist, description, concert_date, lot_type,
            start_price_usd, bid_step_usd, end_time, duration_total_seconds,
            featured, total_fee, FINAL_VALUE_FEE_PCT,
        )
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE lots SET payment_window_minutes = %s WHERE id = %s",
                (int(payment_window_total_min), int(lot_id)),
            )
        conn.commit()
    return jsonify({
        'lot_id': lot_id,
        'listing_fee_usd': float(total_fee),
        'balance_usd': float(new_balance),
        'redirect': '/lot/{}'.format(lot_id),
    }), 201


@bp.route('/hall-of-fame')
def hall_of_fame_page():
    with models.get_conn() as conn:
        awards = models.hall_of_fame(conn)
        conn.commit()
    return render_template('hall_of_fame.html', awards=awards)


@bp.route('/how-it-works')
def how_it_works():
    return render_template('how_it_works.html')


@bp.route('/chats')
def chats_page():
    user_id = session.get('user_id')
    if user_id is None:
        return redirect('/auth/login')
    bot_id = notify.get_bot_user_id()
    with models.get_conn() as conn:
        models.ensure_chat_table(conn)
        chats = models.list_user_chats(conn, int(user_id))
        conn.commit()
    formatted = []
    for c in chats:
        is_bot = int(c['peer_id']) == int(bot_id)
        formatted.append({
            'lot_id': int(c['lot_id']),
            'peer_id': int(c['peer_id']),
            'peer_username': notify.BOT_DISPLAY_NAME if is_bot else c['peer_username'],
            'lot_title': c['lot_title'],
            'lot_image_url': c.get('lot_image_url'),
            'last_message': c['last_message'][:120],
            'last_at_display': c['last_at'].strftime('%d.%m %H:%M') if c.get('last_at') else '',
            'unread': int(c.get('unread') or 0),
            'is_bot': is_bot,
        })
    formatted.sort(key=lambda c: (not c['is_bot'], 0))
    return render_template('chats.html', chats=formatted, bot_user_id=bot_id, bot_display_name=notify.BOT_DISPLAY_NAME)


@bp.route('/notifications')
def notifications_page():
    user_id = session.get('user_id')
    if user_id is None:
        return redirect('/auth/login')
    items = notify.list_notifications(int(user_id), limit=200)
    formatted = []
    for n in items:
        formatted.append({
            'id': int(n['id']),
            'kind': n['kind'],
            'title': n['title'],
            'body': n['body'],
            'lot_id': int(n['lot_id']) if n.get('lot_id') else None,
            'payment_id': int(n['payment_id']) if n.get('payment_id') else None,
            'created_at_display': n['created_at'].strftime('%d.%m %H:%M') if n.get('created_at') else '',
            'read': n.get('read_at') is not None,
        })
    return render_template('notifications.html', notifications=formatted)


@bp.route('/api/notifications')
def api_notifications():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    only_unread = request.args.get('unread') == '1'
    limit = min(200, max(1, int(request.args.get('limit', 50) or 50)))
    items = notify.list_notifications(int(user_id), limit=limit, only_unread=only_unread)
    out = []
    for n in items:
        out.append({
            'id': int(n['id']),
            'kind': n['kind'],
            'title': n['title'],
            'body': n['body'],
            'lot_id': int(n['lot_id']) if n.get('lot_id') else None,
            'payment_id': int(n['payment_id']) if n.get('payment_id') else None,
            'created_at': n['created_at'].isoformat() if n.get('created_at') else '',
            'read': n.get('read_at') is not None,
        })
    return jsonify({'notifications': out, 'unread': notify.unread_count(int(user_id))})


@bp.route('/api/notifications/<int:notif_id>/read', methods=['POST'])
def api_notification_read(notif_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    ok = notify.mark_read(int(user_id), int(notif_id))
    return jsonify({'ok': ok, 'unread': notify.unread_count(int(user_id))})


@bp.route('/api/notifications/read-all', methods=['POST'])
def api_notifications_read_all():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    n = notify.mark_all_read(int(user_id))
    return jsonify({'updated': n, 'unread': 0})


@bp.route('/api/chat/unread')
def api_chat_unread():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    return jsonify({'unread': notify.chat_unread_total(int(user_id))})


@bp.route('/api/online')
def api_online():
    from socket_events import online_count
    return jsonify({'count': online_count()})


@bp.route('/api/lot/<int:lot_id>/viewers')
def api_lot_viewers(lot_id):
    from socket_events import lot_viewers_count
    return jsonify({'lot_id': lot_id, 'count': lot_viewers_count(lot_id)})


@bp.route('/api/lot/<int:lot_id>/proxy-bid', methods=['POST'])
def api_proxy_bid(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    try:
        max_amount = Decimal(str(data.get('max_amount_usd')))
    except (InvalidOperation, TypeError):
        return jsonify({'error': 'invalid_payload'}), 400
    share_url = data.get('share_url') or ''
    if not _is_valid_share_url(share_url):
        return jsonify({'error': 'invalid_share_url'}), 400
    if max_amount <= 0:
        return jsonify({'error': 'invalid_amount'}), 400
    with models.get_conn() as conn:
        models.ensure_proxy_bid_columns(conn)
        models.ensure_balance_column(conn)
        balance = models.get_balance(conn, user_id)
        lot = models.get_lot(conn, lot_id)
        if lot is None:
            conn.commit()
            return jsonify({'error': 'lot_not_found'}), 404
        if lot['status'] != 'active':
            conn.commit()
            return jsonify({'error': 'lot_not_active'}), 409
        max_verified = models.get_max_verified_amount(conn, lot_id)
        current_max = Decimal(str(max_verified)) if max_verified is not None else Decimal(str(lot['start_price_usd']))
        step = Decimal(str(lot['bid_step_usd']))
        if max_amount < current_max + step:
            conn.commit()
            return jsonify({
                'error': 'max_too_low',
                'minimum_usd': float(current_max + step),
            }), 400
        models.upsert_proxy_bid(conn, lot_id, user_id, max_amount, share_url)
        target_amount = current_max + step if max_verified is not None else current_max
        if balance is not None and Decimal(str(balance)) < target_amount:
            conn.commit()
            return jsonify({
                'error': 'insufficient_balance',
                'message': 'Недостаточно средств для первой ставки ${:.2f}. Пополните баланс.'.format(float(target_amount)),
                'balance_usd': float(balance),
                'required_usd': float(target_amount),
            }), 402
        if not models.duplicate_bid_exists(conn, lot_id, user_id, target_amount, share_url):
            bid_id = models.insert_bid(conn, lot_id, user_id, target_amount, share_url)
        else:
            bid_id = None
        conn.commit()
    if bid_id is not None:
        payments.schedule_share_verification(bid_id, share_url)
        socket_events.emit_to_lot(lot_id, 'new_bid', {
            'lot_id': lot_id,
            'bid_id': bid_id,
            'user': session.get('username') or 'user',
            'user_id': user_id,
            'amount_usd': float(target_amount),
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'is_proxy': True,
        })
    return jsonify({
        'proxy_active': True,
        'max_amount_usd': float(max_amount),
        'current_amount_usd': float(target_amount),
        'bid_id': bid_id,
    }), 201


@bp.route('/api/payment/<int:payment_id>/confirm-delivery', methods=['POST'])
def api_confirm_delivery(payment_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_escrow_columns(conn)
        result = models.confirm_ticket_delivery(conn, payment_id, user_id)
        if result is None:
            conn.commit()
            return jsonify({'error': 'cannot_confirm', 'reason': 'Билет ещё не отправлен или сделка уже закрыта'}), 400
        models.ensure_lot_events_table(conn)
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (user_id,))
            buyer_row = cur.fetchone()
            buyer_username = buyer_row[0] if buyer_row else None
        models.insert_lot_event(
            conn, result['lot_id'], 'escrow_released',
            actor_username=buyer_username, actor_user_id=user_id,
            amount_usd=result['seller_credited_usd'],
            payload={'fee_pct': result['fee_pct'], 'gross_usd': result['amount_usd']},
        )
        conn.commit()
    socket_events.emit_to_user(result['seller_id'], 'escrow_released', {
        'payment_id': payment_id,
        'lot_id': result['lot_id'],
        'lot_title': result['lot_title'],
        'amount_usd': result['seller_credited_usd'],
        'fee_pct': result['fee_pct'],
        'gross_usd': result['amount_usd'],
        'buyer_username': buyer_username,
    })
    notify.notify_event(
        int(result['seller_id']), 'seller_payment_received',
        '💰 Сделка по лоту «{}» закрыта'.format(result.get('lot_title') or ''),
        'Покупатель {} подтвердил получение. На ваш баланс зачислено ${:.2f} (за вычетом комиссии {:.0f}%).'.format(
            buyer_username or '', float(result['seller_credited_usd']), float(result['fee_pct']),
        ),
        lot_id=int(result['lot_id']), payment_id=int(payment_id),
    )
    notify.notify_event(
        int(user_id), 'buyer_confirmed',
        '✅ Получение подтверждено по лоту «{}»'.format(result.get('lot_title') or ''),
        'Спасибо! Сделка успешно закрыта. Не забудьте оставить отзыв о продавце в его профиле.',
        lot_id=int(result['lot_id']), payment_id=int(payment_id),
    )
    return jsonify({
        'released': True,
        'seller_credited_usd': result['seller_credited_usd'],
        'fee_pct': result['fee_pct'],
    })


@bp.route('/api/payment/<int:payment_id>/deliver-ticket', methods=['POST'])
def api_deliver_ticket(payment_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    ticket_code = (data.get('ticket_code') or '').strip()
    if len(ticket_code) < 4 or len(ticket_code) > 200:
        return jsonify({'error': 'invalid_ticket_code'}), 400
    buyer_id = None
    lot_id = None
    lot_title = None
    with models.get_conn() as conn:
        models.ensure_escrow_columns(conn)
        with conn.cursor() as cur:
            cur.execute(
                'SELECT p.id, p.user_id, l.seller_id, l.id, l.title FROM payments p '
                'JOIN bids b ON b.id = p.bid_id JOIN lots l ON l.id = b.lot_id '
                'WHERE p.id = %s',
                (payment_id,),
            )
            row = cur.fetchone()
            if row is None or row[2] is None or int(row[2]) != int(user_id):
                conn.commit()
                return jsonify({'error': 'forbidden'}), 403
            buyer_id = int(row[1])
            lot_id = int(row[3])
            lot_title = row[4]
        models.deliver_ticket(conn, payment_id, ticket_code)
        models.ensure_lot_events_table(conn)
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (user_id,))
            seller_row = cur.fetchone()
            seller_username = seller_row[0] if seller_row else None
        models.insert_lot_event(
            conn, lot_id, 'ticket_delivered',
            actor_username=seller_username, actor_user_id=user_id,
            payload={'payment_id': payment_id},
        )
        conn.commit()
    if buyer_id is not None:
        socket_events.emit_to_user(buyer_id, 'ticket_delivered', {
            'payment_id': payment_id,
            'lot_id': lot_id,
            'lot_title': lot_title,
            'ticket_code': ticket_code,
        })
        notify.notify_event(
            buyer_id, 'ticket_delivered',
            '🎫 Продавец отправил билет по лоту «{}»'.format(lot_title or ''),
            'Билет: {}\n\nПроверьте билет, подтвердите получение в профиле — после этого деньги поступят продавцу.'.format(ticket_code),
            lot_id=int(lot_id), payment_id=int(payment_id),
        )
    return jsonify({'delivered': True, 'ticket_code': ticket_code})


@bp.route('/api/seller/<int:seller_id>/review', methods=['POST'])
def api_seller_review(seller_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    try:
        rating = int(data.get('rating'))
        payment_id = int(data.get('payment_id'))
    except (TypeError, ValueError):
        return jsonify({'error': 'invalid_payload'}), 400
    if rating < 1 or rating > 5:
        return jsonify({'error': 'invalid_rating'}), 400
    comment = (data.get('comment') or '').strip()[:1000]
    with models.get_conn() as conn:
        models.ensure_reviews_table(conn)
        with conn.cursor() as cur:
            cur.execute(
                'SELECT b.lot_id FROM payments p JOIN bids b ON b.id = p.bid_id '
                'WHERE p.id = %s AND p.user_id = %s AND p.status = %s',
                (payment_id, user_id, 'paid'),
            )
            row = cur.fetchone()
            if row is None:
                conn.commit()
                return jsonify({'error': 'no_paid_payment'}), 400
            lot_id = int(row[0])
        try:
            review_id = models.insert_review(conn, seller_id, user_id, lot_id, payment_id, rating, comment)
            conn.commit()
        except psycopg2.errors.UniqueViolation:
            conn.rollback()
            return jsonify({'error': 'already_reviewed'}), 409
    return jsonify({'review_id': review_id, 'rating': rating}), 201


@bp.route('/seller/<int:seller_id>')
def seller_profile(seller_id):
    with models.get_conn() as conn:
        models.ensure_seller_columns(conn)
        models.ensure_reviews_table(conn)
        seller = models.get_user(conn, seller_id)
        if seller is None:
            conn.commit()
            abort(404)
        stats = models.get_seller_stats(conn, seller_id)
        reviews_raw = models.get_seller_reviews(conn, seller_id, 20)
        seller_lots = models.list_seller_lots(conn, seller_id, 20)
        conn.commit()
    reviews = [{
        'rating': r['rating'],
        'comment': r['comment'] or '',
        'buyer_username': r['buyer_username'],
        'lot_title': r['lot_title'],
        'created_at_display': r['created_at'].strftime('%d.%m.%Y') if r.get('created_at') else '',
    } for r in reviews_raw]
    lots = [{
        'id': l['id'],
        'title': l['title'],
        'artist': l['artist'],
        'status': l['status'],
        'current_price_usd': '{:.2f}'.format(float(l['current_price_usd'])),
        'bid_count': int(l['bid_count']),
        'end_time_display': l['end_time'].strftime('%d.%m %H:%M') if l.get('end_time') else '',
    } for l in seller_lots]
    return render_template('seller.html', seller=seller, stats=stats, reviews=reviews, lots=lots)


@bp.route('/api/lot/<int:lot_id>/watch', methods=['POST'])
def api_lot_watch(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_watchlist_table(conn)
        watching = models.toggle_watchlist(conn, user_id, lot_id)
        conn.commit()
    return jsonify({'watching': watching, 'lot_id': lot_id})


@bp.route('/api/lot/<int:lot_id>/watch', methods=['GET'])
def api_lot_watch_status(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'watching': False})
    with models.get_conn() as conn:
        models.ensure_watchlist_table(conn)
        watching = models.is_watching(conn, user_id, lot_id)
        conn.commit()
    return jsonify({'watching': watching})


@bp.route('/api/lot/<int:lot_id>/live')
def api_lot_live(lot_id):
    with models.get_conn() as conn:
        raw = models.get_lot(conn, lot_id)
        if raw is None:
            conn.commit()
            return jsonify({'error': 'not_found'}), 404
        stats = models.get_lot_live_stats(conn, lot_id)
        models.ensure_lot_events_table(conn)
        events_raw = models.get_lot_events(conn, lot_id, 50)
        conn.commit()
    top = []
    for b in stats['top_bidders']:
        top.append({
            'username': b['username'],
            'amount_usd': float(b['amount_usd']),
            'created_at': b['created_at'].isoformat() if b.get('created_at') else '',
        })
    events = []
    for ev in events_raw:
        events.append({
            'id': int(ev['id']),
            'event_type': ev['event_type'],
            'actor_username': ev.get('actor_username'),
            'amount_usd': float(ev['amount_usd']) if ev.get('amount_usd') is not None else None,
            'payload': ev.get('payload'),
            'created_at': ev['created_at'].isoformat() if ev.get('created_at') else '',
            'created_at_display': ev['created_at'].strftime('%H:%M:%S') if ev.get('created_at') else '',
        })
    hourly = []
    for h in stats['hourly']:
        hourly.append({
            'hour': h['hour'].strftime('%H:00') if h.get('hour') else '',
            'count': int(h['cnt']),
        })
    from socket_events import online_count
    return jsonify({
        'online': online_count(),
        'top_bidders': top,
        'events': events,
        'hourly': hourly,
    })


@bp.route('/api/translate', methods=['POST'])
def api_translate():
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    target = (data.get('lang') or '').lower()
    if target not in ('ru', 'en', 'hy'):
        return jsonify({'error': 'unsupported_lang'}), 400
    items = data.get('items') or []
    if not isinstance(items, list) or len(items) > 50:
        return jsonify({'error': 'invalid_items'}), 400
    out = []
    for it in items:
        if not isinstance(it, str):
            out.append(it)
            continue
        if len(it) > 500:
            out.append(it)
            continue
        out.append(translator.translate(it, target))
    return jsonify({'lang': target, 'items': out})


@bp.route('/api/lot/<int:lot_id>/chat', methods=['GET'])
def api_lot_chat_history(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_chat_table(conn)
        models.ensure_seller_columns(conn)
        lot = models.get_lot(conn, lot_id)
        if lot is None:
            conn.commit()
            return jsonify({'error': 'lot_not_found'}), 404
        seller_id = lot.get('seller_id')
        if seller_id is None:
            conn.commit()
            return jsonify({'messages': [], 'seller_id': None, 'seller_username': None})
        peer_qs = request.args.get('peer')
        partner_id = None
        if peer_qs:
            try:
                partner_id = int(peer_qs)
            except (TypeError, ValueError):
                partner_id = None
        if partner_id is None:
            partner_id = int(seller_id) if int(user_id) != int(seller_id) else None
        if partner_id is None:
            conn.commit()
            return jsonify({'messages': [], 'seller_id': int(seller_id)})
        msgs = models.list_chat_messages(conn, lot_id, int(user_id), partner_id, 100)
        models.mark_chat_read(conn, lot_id, partner_id, int(user_id))
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (int(seller_id),))
            row = cur.fetchone()
            seller_username = row[0] if row else None
        conn.commit()
    return jsonify({
        'seller_id': int(seller_id),
        'seller_username': seller_username,
        'partner_id': partner_id,
        'messages': [{
            'id': m['id'],
            'sender_id': int(m['sender_id']),
            'sender_username': m.get('sender_username'),
            'recipient_id': int(m['recipient_id']),
            'message': m['message'],
            'created_at': m['created_at'].isoformat() if m.get('created_at') else '',
            'read': m['read_at'] is not None,
        } for m in msgs],
    })


@bp.route('/api/lot/<int:lot_id>/chat', methods=['POST'])
def api_lot_chat_send(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    if not message or len(message) > 2000:
        return jsonify({'error': 'invalid_message', 'message': 'Сообщение от 1 до 2000 символов'}), 400
    with models.get_conn() as conn:
        models.ensure_chat_table(conn)
        models.ensure_seller_columns(conn)
        lot = models.get_lot(conn, lot_id)
        if lot is None or lot.get('seller_id') is None:
            conn.commit()
            return jsonify({'error': 'lot_or_seller_missing'}), 404
        seller_id = int(lot['seller_id'])
        if int(user_id) == seller_id:
            try:
                recipient_id = int(data.get('recipient_id'))
            except (TypeError, ValueError):
                conn.commit()
                return jsonify({'error': 'recipient_required'}), 400
        else:
            recipient_id = seller_id
        if notify.is_bot_user(recipient_id):
            conn.commit()
            return jsonify({'error': 'bot_recipient', 'message': 'Это служебный аккаунт, ему нельзя отвечать'}), 400
        inserted = models.insert_chat_message(conn, lot_id, int(user_id), recipient_id, message)
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (int(user_id),))
            row = cur.fetchone()
            sender_username = row[0] if row else None
            cur.execute('SELECT title FROM lots WHERE id = %s', (lot_id,))
            lot_title_row = cur.fetchone()
            lot_title_for_notif = lot_title_row[0] if lot_title_row else ''
        conn.commit()
    payload = {
        'id': inserted['id'],
        'lot_id': lot_id,
        'sender_id': int(user_id),
        'sender_username': sender_username,
        'recipient_id': recipient_id,
        'message': message,
        'created_at': inserted['created_at'].isoformat() if inserted.get('created_at') else '',
    }
    socket_events.emit_to_user(recipient_id, 'chat_message', payload)
    socket_events.emit_to_user(int(user_id), 'chat_message', payload)
    if not notify.is_bot_user(recipient_id) and int(recipient_id) != int(user_id):
        preview = message if len(message) <= 140 else message[:140] + '…'
        notify.insert_notification(
            int(recipient_id),
            'chat_message',
            '✉️ Новое сообщение от {}'.format(sender_username or 'пользователя'),
            'Лот «{}»\n\n{}'.format(lot_title_for_notif or '', preview),
            lot_id=int(lot_id),
        )
    return jsonify({'ok': True, 'message': payload}), 201


@bp.route('/api/lot/<int:lot_id>/image', methods=['POST'])
def api_lot_upload_image(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_seller_columns(conn)
        conn.commit()
    with models.get_conn() as conn:
        lot = models.get_lot(conn, lot_id)
        if lot is None:
            conn.commit()
            return jsonify({'error': 'lot_not_found'}), 404
        seller_id = lot.get('seller_id')
        if seller_id is None or int(seller_id) != int(user_id):
            conn.commit()
            return jsonify({'error': 'forbidden', 'message': 'Только продавец может загружать картинку'}), 403
        conn.commit()
    if 'image' not in request.files:
        return jsonify({'error': 'no_file', 'message': 'Прикрепите файл'}), 400
    file = request.files['image']
    filename = (file.filename or '').lower()
    allowed = ('.jpg', '.jpeg', '.png', '.webp', '.gif')
    if not any(filename.endswith(ext) for ext in allowed):
        return jsonify({'error': 'bad_format', 'message': 'Допустимы JPG, PNG, WebP, GIF'}), 400
    file.stream.seek(0, 2)
    size = file.stream.tell()
    file.stream.seek(0)
    if size > 6 * 1024 * 1024:
        return jsonify({'error': 'too_large', 'message': 'Максимум 6 МБ'}), 400
    # Сохраняем в /data (persistent volume Amvera) если он доступен,
    # иначе в static/lot_images (локально). Отдаём через /lot-image/<filename>.
    persist_root = '/data' if os.path.isdir('/data') and os.access('/data', os.W_OK) else None
    if persist_root:
        upload_dir = os.path.join(persist_root, 'lot_images')
    else:
        upload_dir = os.path.join(os.path.dirname(__file__), 'static', 'lot_images')
    if not os.path.isdir(upload_dir):
        os.makedirs(upload_dir, exist_ok=True)
    ext = '.' + filename.rsplit('.', 1)[-1]
    safe_name = 'lot_{}_{}{}'.format(lot_id, secrets.token_hex(6), ext)
    save_path = os.path.join(upload_dir, safe_name)
    file.save(save_path)
    if persist_root:
        public_url = '/lot-image/{}'.format(safe_name)
    else:
        public_url = '/static/lot_images/{}'.format(safe_name)
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('UPDATE lots SET image_url = %s WHERE id = %s', (public_url, lot_id))
        conn.commit()
    return jsonify({'ok': True, 'image_url': public_url})


@bp.route('/lot-image/<path:filename>')
def serve_lot_image(filename):
    """Отдаём картинки лотов из персистентного хранилища /data/lot_images.
    Если /data недоступен (локально) — пробуем static/lot_images."""
    persist_dir = '/data/lot_images'
    if os.path.isdir(persist_dir):
        try:
            return send_from_directory(persist_dir, filename, max_age=3600)
        except Exception:
            pass
    fallback = os.path.join(os.path.dirname(__file__), 'static', 'lot_images')
    return send_from_directory(fallback, filename, max_age=3600)


@bp.route('/api/rates')
def api_rates():
    try:
        rates, fetched_iso = currency.get_rates()
    except currency.RatesUnavailableError:
        return jsonify({'error': 'rates_unavailable'}), 503
    response = {
        'AMD': rates['AMD'],
        'RUB': rates['RUB'],
        'USD': 1.0,
        'fetched_at': fetched_iso,
    }
    return jsonify(response)


def _is_valid_share_url(value):
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        parsed = urlparse(value.strip())
    except ValueError:
        return False
    if parsed.scheme not in ('https', 'http') or not parsed.netloc:
        return False
    if os.environ.get('VK_AUTO_VERIFY') == '1':
        return True
    host = parsed.netloc.lower().split(':')[0]
    if host.startswith('www.'):
        host = host[4:]
    allowed = (
        'vk.com', 'm.vk.com',
        'facebook.com', 'fb.com', 'm.facebook.com', 'web.facebook.com',
        'twitter.com', 'x.com', 'mobile.twitter.com',
        't.me', 'telegram.me',
        'ok.ru', 'm.ok.ru',
        'instagram.com',
        'linkedin.com',
        'reddit.com',
        'pinterest.com',
    )
    return any(host == h or host.endswith('.' + h) for h in allowed)


def _is_valid_https_url(value, host_suffix=None):
    if not isinstance(value, str) or not value:
        return False
    try:
        parsed = urlparse(value)
    except ValueError:
        return False
    if parsed.scheme != 'https' or not parsed.netloc:
        return False
    if host_suffix is not None:
        host = parsed.netloc.lower().split(':')[0]
        if not (host == host_suffix or host.endswith('.' + host_suffix)):
            return False
    return True


@bp.route('/api/bid', methods=['POST'])
def api_bid():
    if 'user_id' not in session:
        return jsonify({'error': 'unauthorized'}), 401
    if notify.is_bot_user(session.get('user_id')):
        return jsonify({'error': 'bot_cannot_bid'}), 403
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    try:
        data = request.get_json(force=False, silent=False)
    except Exception:
        return jsonify({'error': 'invalid_payload'}), 400
    if not isinstance(data, dict):
        return jsonify({'error': 'invalid_payload'}), 400
    lot_id = data.get('lot_id')
    amount_raw = data.get('amount_usd')
    share_url = data.get('share_url')
    otp_code = (data.get('otp_code') or '').strip()
    if not isinstance(lot_id, int) or lot_id <= 0:
        return jsonify({'error': 'invalid_payload'}), 400
    try:
        amount_usd = Decimal(str(amount_raw))
    except (InvalidOperation, TypeError):
        return jsonify({'error': 'invalid_payload'}), 400
    if amount_usd <= 0:
        return jsonify({'error': 'invalid_payload'}), 400
    if not _is_valid_share_url(share_url):
        return jsonify({'error': 'invalid_share_url', 'hint': 'Вставьте ссылку на пост из VK, Facebook, Instagram или другой соцсети'}), 400
    user_id = int(session['user_id'])
    require_otp = os.environ.get('BID_OTP_DISABLED') != '1'
    if require_otp and not otp_code:
        from datetime import timedelta as _td
        code = '{:06d}'.format(secrets.randbelow(1000000))
        expires = datetime.now(timezone.utc) + _td(minutes=5)
        with models.get_conn() as conn:
            models.ensure_otp_table(conn)
            models.insert_otp(conn, user_id, int(lot_id), code, amount_usd, share_url, expires)
            conn.commit()
        logger.info('bid_otp_generated user_id=%s lot_id=%s code=%s', user_id, lot_id, code)
        return jsonify({
            'otp_required': True,
            'message': 'Введите код подтверждения для завершения ставки',
            'demo_code': code,
            'expires_in_seconds': 300,
        }), 202
    if require_otp:
        with models.get_conn() as conn:
            models.ensure_otp_table(conn)
            consumed = models.consume_otp(conn, user_id, int(lot_id), otp_code)
            conn.commit()
        if consumed is None:
            return jsonify({'error': 'invalid_otp', 'message': 'Неверный код подтверждения'}), 400
        if isinstance(consumed, dict) and consumed.get('error') == 'expired':
            return jsonify({'error': 'otp_expired', 'message': 'Срок действия кода истёк, запросите новый'}), 400
        if isinstance(consumed, dict) and consumed.get('error') == 'already_used':
            return jsonify({'error': 'otp_used', 'message': 'Этот код уже использован'}), 400
        if abs(float(consumed['amount_usd']) - float(amount_usd)) > 0.01 or consumed['share_url'] != share_url:
            return jsonify({'error': 'otp_mismatch', 'message': 'Код не подходит к этим данным ставки'}), 400
    try:
        result = _execute_bid_transaction(lot_id, user_id, amount_usd, share_url)
    except _BidValidationError as exc:
        return jsonify(exc.body), exc.status
    except (psycopg2.errors.SerializationFailure, psycopg2.errors.DeadlockDetected, psycopg2.OperationalError):
        return jsonify({'error': 'transient_db_error'}), 503
    bid_id = result['bid_id']
    payments.schedule_share_verification(bid_id, share_url)
    with models.get_conn() as conn:
        models.ensure_lot_events_table(conn)
        models.insert_lot_event(conn, lot_id, 'new_bid', actor_username=result['username'], actor_user_id=user_id, amount_usd=amount_usd)
        if result.get('extended'):
            models.insert_lot_event(conn, lot_id, 'timer_extended', payload={'extension_seconds': 180, 'new_end_time': result['new_end_time'].isoformat()})
        conn.commit()
    socket_events.emit_to_lot(lot_id, 'new_bid', {
        'lot_id': lot_id,
        'bid_id': bid_id,
        'user': result['username'],
        'user_id': user_id,
        'amount_usd': float(amount_usd),
        'timestamp': datetime.now(timezone.utc).isoformat(),
    })
    if result.get('previous_top_user_id') and result['previous_top_user_id'] != user_id:
        socket_events.emit_to_user(result['previous_top_user_id'], 'outbid', {
            'lot_id': lot_id,
            'new_amount_usd': float(amount_usd),
        })
        notify.notify_event(
            int(result['previous_top_user_id']), 'outbid',
            '⚡ Вашу ставку перебили',
            'По лоту #{} ваша ставка перебита. Новая ставка: {:.2f} USD. Поставьте ставку выше, чтобы вернуть лидерство.'.format(lot_id, float(amount_usd)),
            lot_id=int(lot_id),
            send_chat=False,
        )
    if result.get('extended'):
        socket_events.emit_to_lot(lot_id, 'timer_extended', {
            'lot_id': lot_id,
            'new_end_time': result['new_end_time'].isoformat(),
            'extension_seconds': 180,
        })
    return jsonify({'bid_id': bid_id, 'amount_usd': float(amount_usd), 'share_verified': False}), 201


class _BidValidationError(Exception):
    def __init__(self, status, body):
        super().__init__(body)
        self.status = status
        self.body = body


def _execute_bid_transaction(lot_id, user_id, amount_usd, share_url):
    from datetime import timedelta
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT id, status, end_time, start_price_usd, bid_step_usd, seller_id FROM lots WHERE id = %s FOR UPDATE',
                (lot_id,),
            )
            row = cur.fetchone()
            if row is None:
                conn.commit()
                raise _BidValidationError(404, {'error': 'lot_not_found'})
            _, lot_status, end_time, start_price_usd, bid_step_usd, seller_id = row
            if seller_id is not None and int(seller_id) == int(user_id):
                conn.commit()
                raise _BidValidationError(403, {'error': 'own_lot', 'message': 'Нельзя ставить ставку на собственный лот'})
            if lot_status != 'active':
                conn.commit()
                raise _BidValidationError(409, {'error': 'lot_not_active'})
            cur.execute('SELECT NOW()')
            now_db = cur.fetchone()[0]
            if end_time <= now_db:
                conn.commit()
                raise _BidValidationError(409, {'error': 'lot_ended'})
            if models.duplicate_bid_exists(conn, lot_id, user_id, amount_usd, share_url):
                conn.commit()
                raise _BidValidationError(409, {'error': 'duplicate_bid'})
            cur.execute(
                'SELECT id, user_id, amount_usd FROM bids WHERE lot_id = %s AND share_verified = TRUE ORDER BY amount_usd DESC, id ASC LIMIT 1',
                (lot_id,),
            )
            top_row = cur.fetchone()
            previous_top_user_id = None
            if top_row is None:
                minimum = Decimal(str(start_price_usd))
            else:
                previous_top_user_id = int(top_row[1])
                minimum = Decimal(str(top_row[2])) + Decimal(str(bid_step_usd))
            if amount_usd < minimum:
                conn.commit()
                raise _BidValidationError(400, {'error': 'amount_too_low', 'minimum_usd': float(minimum)})
            # Balance check — пользователь не должен ставить больше, чем у него на балансе
            try:
                models.ensure_balance_column(conn)
                balance = models.get_balance(conn, user_id)
            except Exception:
                balance = None
            if balance is not None and Decimal(str(balance)) < Decimal(str(amount_usd)):
                conn.commit()
                raise _BidValidationError(402, {
                    'error': 'insufficient_balance',
                    'message': 'Недостаточно средств для ставки ${:.2f}. На балансе ${:.2f}. Пополните баланс перед ставкой.'.format(float(amount_usd), float(balance)),
                    'balance_usd': float(balance),
                    'required_usd': float(amount_usd),
                })
            new_bid_id = models.insert_bid(conn, lot_id, user_id, amount_usd, share_url)
            extended = False
            new_end_time = end_time
            seconds_remaining = (end_time - now_db).total_seconds()
            if seconds_remaining < 180:
                cur.execute("UPDATE lots SET end_time = NOW() + INTERVAL '180 seconds' WHERE id = %s RETURNING end_time", (lot_id,))
                new_end_time = cur.fetchone()[0]
                extended = True
            cur.execute('SELECT username FROM users WHERE id = %s', (user_id,))
            user_row = cur.fetchone()
            username = user_row[0] if user_row else 'anon'
            conn.commit()
            return {
                'bid_id': int(new_bid_id),
                'username': username,
                'previous_top_user_id': previous_top_user_id,
                'extended': extended,
                'new_end_time': new_end_time,
            }


@bp.route('/auth/vk')
def auth_vk():
    if not os.environ.get('VK_CLIENT_ID') or not os.environ.get('VK_CLIENT_SECRET'):
        return redirect('/auth/login')
    return redirect(vk_auth.build_authorize_url())


def _hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 200000)
    return 'pbkdf2$200000$' + salt.hex() + '$' + digest.hex()


def _verify_password(password, stored):
    if not stored or not isinstance(stored, str):
        return False
    parts = stored.split('$')
    if len(parts) != 4 or parts[0] != 'pbkdf2':
        return False
    try:
        iterations = int(parts[1])
        salt = bytes.fromhex(parts[2])
        expected = bytes.fromhex(parts[3])
    except ValueError:
        return False
    digest = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)
    return hmac.compare_digest(digest, expected)


_USERNAME_RE = re.compile(r'^[a-zA-Z0-9_.\-]{3,32}$')
_EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


@bp.route('/auth/login', methods=['GET'])
def auth_login_page():
    return render_template('auth_login.html')


@bp.route('/auth/register', methods=['GET'])
def auth_register_page():
    return render_template('auth_register.html')


@bp.route('/api/auth/register', methods=['POST'])
def api_auth_register():
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''
    country = (data.get('country') or 'OTHER').upper()
    if not _USERNAME_RE.match(username):
        return jsonify({'error': 'invalid_username'}), 400
    if email and not _EMAIL_RE.match(email):
        return jsonify({'error': 'invalid_email'}), 400
    if len(password) < 8 or len(password) > 200:
        return jsonify({'error': 'weak_password'}), 400
    if country not in ('AM', 'RU', 'OTHER'):
        country = 'OTHER'
    with models.get_conn() as conn:
        models.ensure_password_column(conn)
        existing = models.find_user_by_username_or_email(conn, username)
        if existing:
            conn.commit()
            return jsonify({'error': 'username_taken'}), 409
        if email:
            existing_email = models.find_user_by_username_or_email(conn, email)
            if existing_email:
                conn.commit()
                return jsonify({'error': 'email_taken'}), 409
        password_hash = _hash_password(password)
        user_id = models.create_local_user(conn, username, email or None, country, password_hash)
        conn.commit()
    session.clear()
    session['user_id'] = user_id
    session['country'] = country
    return jsonify({'user_id': user_id, 'redirect': '/'}), 201


@bp.route('/api/auth/login', methods=['POST'])
def api_auth_login():
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    identifier = (data.get('identifier') or data.get('username') or data.get('email') or '').strip()
    password = data.get('password') or ''
    if not identifier or not password:
        return jsonify({'error': 'invalid_credentials'}), 400
    with models.get_conn() as conn:
        models.ensure_password_column(conn)
        user = models.find_user_by_username_or_email(conn, identifier)
        conn.commit()
    if user is None or not _verify_password(password, user.get('password_hash') or ''):
        return jsonify({'error': 'invalid_credentials'}), 401
    session.clear()
    session['user_id'] = int(user['id'])
    session['country'] = user.get('country') or 'OTHER'
    return jsonify({'user_id': int(user['id']), 'redirect': '/'}), 200


@bp.route('/auth/dev')
def auth_dev():
    return render_template('dev_login.html', users=_dev_users())


@bp.route('/auth/dev/login', methods=['POST'])
def auth_dev_login():
    if not request.is_json:
        username = request.form.get('username')
    else:
        data = request.get_json(silent=True) or {}
        username = data.get('username')
    if not username or not isinstance(username, str):
        return jsonify({'error': 'invalid_payload'}), 400
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT id, country FROM users WHERE username = %s LIMIT 1', (username,))
            row = cur.fetchone()
            if row is None:
                conn.commit()
                return jsonify({'error': 'user_not_found'}), 404
            user_id, country = int(row[0]), row[1]
        conn.commit()
    session.clear()
    session['user_id'] = user_id
    session['country'] = country
    return redirect('/')


def _dev_users():
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT id, username, country FROM users ORDER BY id LIMIT 20')
            rows = cur.fetchall()
        conn.commit()
    return [{'id': r[0], 'username': r[1], 'country': r[2]} for r in rows]


@bp.route('/auth/vk/callback')
def auth_vk_callback():
    code = request.args.get('code')
    if not code:
        return render_template('error.html', message='Missing OAuth code') if _has_error_template() else ('Missing OAuth code', 400)
    try:
        token_data = vk_auth.exchange_code(code)
        profile = vk_auth.get_profile(token_data['access_token'], token_data['user_id'])
    except vk_auth.VKAuthError as exc:
        logger.warning('vk_auth_failed: %s', exc)
        return ('VK authentication failed: {}'.format(exc), 400)
    country = vk_auth.country_from_vk(profile.get('country_id'))
    with models.get_conn() as conn:
        user_id = models.upsert_user_by_vk(
            conn,
            vk_id=int(profile['vk_id']),
            username=profile['username'],
            email=token_data.get('email'),
            country=country,
            vk_token=token_data['access_token'],
        )
        conn.commit()
    session.clear()
    session['user_id'] = int(user_id)
    session['vk_id'] = int(profile['vk_id'])
    session['country'] = country
    return redirect('/')


@bp.route('/auth/logout', methods=['POST'])
def auth_logout():
    session.clear()
    return ('', 204)


@bp.route('/me')
def profile():
    user_id = session.get('user_id')
    if user_id is None:
        return redirect('/auth/vk')
    with models.get_conn() as conn:
        models.ensure_balance_column(conn)
        models.ensure_payment_methods_table(conn)
        models.ensure_watchlist_table(conn)
        conn.commit()
        user = models.get_user(conn, user_id)
        if user is None:
            session.clear()
            conn.commit()
            return redirect('/auth/vk')
        balance = models.get_balance(conn, user_id)
        topups = models.list_topups(conn, user_id, 10)
        my_bids = models.list_user_bids(conn, user_id, 10)
        cards = models.list_payment_methods(conn, user_id)
        all_payments = models.list_user_payments(conn, user_id, 20)
        watchlist_raw = models.get_user_watchlist(conn, user_id, 10)
        conn.commit()
    pending_payments = [p for p in all_payments if p['status'] == 'pending']
    return render_template(
        'profile.html',
        user=user,
        balance=balance,
        cards=[{
            'id': c['id'],
            'provider': c['provider'],
            'brand': c['brand'] or 'card',
            'last4': c['last4'] or '••••',
            'exp_month': c['exp_month'],
            'exp_year': c['exp_year'],
            'is_default': bool(c['is_default']),
        } for c in cards],
        pending_payments=[{
            'id': p['id'],
            'lot_id': p['lot_id'],
            'lot_title': p['lot_title'],
            'amount_usd': '{:.2f}'.format(float(p['amount_usd'])),
            'amount_usd_raw': float(p['amount_usd']),
            'currency': p['currency'],
            'provider': p['provider'],
            'expires_at_display': p['expires_at'].strftime('%d.%m.%Y %H:%M') if p.get('expires_at') else '',
        } for p in pending_payments],
        all_payments=[{
            'id': p['id'],
            'lot_id': p['lot_id'],
            'lot_title': p['lot_title'],
            'amount_usd': '{:.2f}'.format(float(p['amount_usd'])),
            'currency': p['currency'],
            'provider': p['provider'],
            'status': p['status'],
            'held_in_escrow': bool(p.get('held_in_escrow')),
            'released_to_seller': bool(p.get('released_to_seller')),
            'ticket_delivered': bool(p.get('ticket_delivered')),
            'ticket_code': p.get('ticket_code'),
            'buyer_confirmed': bool(p.get('buyer_confirmed')),
            'created_at_display': p['created_at'].strftime('%d.%m.%Y %H:%M') if p.get('created_at') else '',
        } for p in all_payments],
        topups=[{
            'id': t['id'],
            'amount_usd': '{:.2f}'.format(float(t['amount_usd'])),
            'provider': t['provider'],
            'status': t['status'],
            'created_at_display': t['created_at'].strftime('%d.%m.%Y %H:%M') if t.get('created_at') else '',
        } for t in topups],
        my_bids=[{
            'id': b['id'],
            'lot_id': b['lot_id'],
            'lot_title': b['title'],
            'amount_usd': '{:.2f}'.format(float(b['amount_usd'])),
            'verified': bool(b['share_verified']),
            'lot_status': b['lot_status'],
            'created_at_display': b['created_at'].strftime('%d.%m.%Y %H:%M') if b.get('created_at') else '',
        } for b in my_bids],
        watchlist=[{
            'id': w['id'],
            'title': w['title'],
            'artist': w['artist'],
            'status': w['status'],
            'current_price_usd': '{:.2f}'.format(float(w['current_price_usd'])),
            'end_time_display': w['end_time'].strftime('%d.%m · %H:%M') if w.get('end_time') else '',
        } for w in watchlist_raw],
    )


@bp.route('/api/balance/topup', methods=['POST'])
def api_balance_topup():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    try:
        amount = Decimal(str(data.get('amount_usd')))
    except (InvalidOperation, TypeError):
        return jsonify({'error': 'invalid_payload'}), 400
    if amount <= 0 or amount > Decimal('1000000'):
        return jsonify({'error': 'invalid_amount', 'message': 'Сумма должна быть от $0.01 до $1 000 000'}), 400
    provider = (data.get('provider') or 'demo').lower()
    if provider not in ('demo', 'stripe', 'yookassa', 'idram', 'card'):
        return jsonify({'error': 'invalid_provider', 'message': 'Выберите провайдер: демо, карта, Stripe, YooKassa или IDram'}), 400
    if provider == 'card':
        with models.get_conn() as conn:
            models.ensure_payment_methods_table(conn)
            method = models.get_default_payment_method(conn, user_id)
            conn.commit()
        if method is None:
            return jsonify({'error': 'no_default_card', 'message': 'Сначала привяжите карту в разделе «Платёжные методы»'}), 400
        provider = method['provider']
        status = 'paid'
    elif provider == 'demo':
        status = 'paid'
    else:
        provider_keys = {
            'stripe': os.environ.get('STRIPE_SECRET_KEY'),
            'yookassa': os.environ.get('YOOKASSA_SECRET_KEY'),
            'idram': os.environ.get('IDRAM_SECRET'),
        }
        if not provider_keys.get(provider):
            provider = 'demo'
            status = 'paid'
        else:
            status = 'pending'
    with models.get_conn() as conn:
        models.ensure_balance_column(conn)
        topup_id = models.topup_balance(conn, user_id, amount, provider, status)
        new_balance = models.get_balance(conn, user_id)
        conn.commit()
    response = {
        'topup_id': topup_id,
        'status': status,
        'balance_usd': new_balance,
        'provider': provider,
    }
    if status == 'pending':
        response['message'] = 'Ожидаем подтверждения от ' + provider + '. Деньги поступят после оплаты.'
    else:
        response['message'] = 'Зачислено $' + format(float(amount), '.2f')
    return jsonify(response), 201


@bp.route('/api/payments/<int:payment_id>/pay-with-card', methods=['POST'])
def api_pay_with_card(payment_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_payment_methods_table(conn)
        payment = models.get_payment(conn, payment_id)
        if payment is None:
            conn.commit()
            return jsonify({'error': 'not_found'}), 404
        if int(payment['user_id']) != int(user_id):
            conn.commit()
            return jsonify({'error': 'forbidden'}), 403
        if payment['status'] != 'pending':
            conn.commit()
            return jsonify({'error': 'payment_not_pending', 'status': payment['status']}), 409
        method = models.get_default_payment_method(conn, user_id)
        if method is None:
            conn.commit()
            return jsonify({'error': 'no_default_card'}), 400
        conn.commit()
    result = payments.mark_payment_paid(payment_id)
    if result is None:
        return jsonify({'error': 'payment_not_found'}), 404
    return jsonify({
        'payment_id': payment_id,
        'status': 'paid',
        'ticket_code': result.get('ticket_code'),
        'card': {'brand': method['brand'], 'last4': method['last4']},
    }), 200


@bp.route('/api/payments/<int:payment_id>/pay-with-balance', methods=['POST'])
def api_pay_with_balance(payment_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_balance_column(conn)
        payment = models.get_payment(conn, payment_id)
        if payment is None:
            conn.commit()
            return jsonify({'error': 'not_found'}), 404
        if int(payment['user_id']) != int(user_id):
            conn.commit()
            return jsonify({'error': 'forbidden'}), 403
        if payment['status'] != 'pending':
            conn.commit()
            return jsonify({'error': 'payment_not_pending', 'status': payment['status']}), 409
        amount = Decimal(str(payment['amount_usd']))
        new_balance = models.deduct_balance(conn, user_id, amount)
        if new_balance is None:
            conn.commit()
            return jsonify({'error': 'insufficient_balance', 'balance_usd': models.get_balance(conn, user_id), 'amount_usd': float(amount)}), 402
        conn.commit()
    result = payments.mark_payment_paid(payment_id)
    if result is None:
        return jsonify({'error': 'payment_not_found'}), 404
    return jsonify({
        'payment_id': payment_id,
        'status': 'paid',
        'ticket_code': result.get('ticket_code'),
        'balance_usd': new_balance,
    }), 200


@bp.route('/api/dev/win-now/<int:lot_id>', methods=['POST'])
def api_dev_win_now(lot_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        lot = models.get_lot(conn, lot_id)
        if lot is None:
            conn.commit()
            return jsonify({'error': 'lot_not_found'}), 404
        if lot['status'] != 'active':
            conn.commit()
            return jsonify({'error': 'lot_not_active'}), 409
        amount = Decimal(str(lot['start_price_usd']))
        bid_id = models.insert_bid(conn, lot_id, user_id, amount, 'https://vk.com/wall-1_1')
        models.set_share_verified(conn, bid_id)
        models.set_lot_status(conn, lot_id, 'ended', user_id)
        conn.commit()
        user = models.get_user(conn, user_id)
        country = (user or {}).get('country') or 'OTHER'
        conn.commit()
    payment = payments.create_payment(bid_id, user_id, amount, country)
    return jsonify({
        'lot_id': lot_id,
        'bid_id': bid_id,
        'payment_id': payment['payment_id'],
        'amount_usd': float(amount),
        'redirect': '/me',
    }), 200


@bp.route('/api/cards', methods=['GET'])
def api_cards_list():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_payment_methods_table(conn)
        methods = models.list_payment_methods(conn, user_id)
        conn.commit()
    return jsonify({'cards': [
        {
            'id': m['id'],
            'provider': m['provider'],
            'brand': m['brand'] or 'card',
            'last4': m['last4'] or '••••',
            'exp_month': m['exp_month'],
            'exp_year': m['exp_year'],
            'is_default': bool(m['is_default']),
        } for m in methods
    ]})


def _detect_card_brand(number_clean):
    if not number_clean:
        return 'card'
    if number_clean.startswith('4'):
        return 'visa'
    if number_clean[:2] in ('22', '23', '24', '25', '26', '27') or number_clean[:2] in ('51', '52', '53', '54', '55'):
        return 'mc'
    if number_clean.startswith('34') or number_clean.startswith('37'):
        return 'amex'
    if number_clean.startswith('2200') or number_clean.startswith('2201') or number_clean.startswith('2202') or number_clean.startswith('2203') or number_clean.startswith('2204'):
        return 'mir'
    return 'card'


def _luhn_check(number):
    digits = [int(c) for c in number if c.isdigit()]
    if len(digits) < 12:
        return False
    checksum = 0
    parity = len(digits) % 2
    for i, d in enumerate(digits):
        if i % 2 == parity:
            d *= 2
            if d > 9:
                d -= 9
        checksum += d
    return checksum % 10 == 0


@bp.route('/api/cards', methods=['POST'])
def api_cards_add():
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    data = request.get_json(silent=True) or {}
    number_raw = (data.get('number') or '').replace(' ', '').replace('-', '')
    holder = (data.get('holder') or '').strip()
    exp = (data.get('expiry') or '').strip()
    cvc = (data.get('cvc') or '').strip()
    if not (number_raw.isdigit() and 12 <= len(number_raw) <= 19):
        return jsonify({'error': 'invalid_number'}), 400
    if not _luhn_check(number_raw):
        return jsonify({'error': 'invalid_number_checksum'}), 400
    if not holder or len(holder) < 2:
        return jsonify({'error': 'invalid_holder'}), 400
    if '/' not in exp:
        return jsonify({'error': 'invalid_expiry'}), 400
    try:
        mm_str, yy_str = exp.split('/', 1)
        exp_month = int(mm_str.strip())
        yy_clean = yy_str.strip()
        exp_year = int(yy_clean) if len(yy_clean) == 4 else 2000 + int(yy_clean)
    except (ValueError, IndexError):
        return jsonify({'error': 'invalid_expiry'}), 400
    if not (1 <= exp_month <= 12 and 2024 <= exp_year <= 2050):
        return jsonify({'error': 'invalid_expiry'}), 400
    if not (cvc.isdigit() and 3 <= len(cvc) <= 4):
        return jsonify({'error': 'invalid_cvc'}), 400
    brand = _detect_card_brand(number_raw)
    last4 = number_raw[-4:]
    country = (session.get('country') or 'OTHER').upper()
    provider_map = {'AM': 'idram', 'RU': 'yookassa'}
    provider = provider_map.get(country, 'stripe')
    external_id = 'tok_local_{}_{}'.format(provider, last4)
    if provider == 'stripe' and os.environ.get('STRIPE_SECRET_KEY'):
        try:
            external_id = _stripe_create_setup_intent_token(number_raw, exp_month, exp_year, cvc)
        except Exception as exc:
            logger.warning('stripe_card_attach_failed: %s', exc)
            external_id = 'tok_local_stripe_{}'.format(last4)
    with models.get_conn() as conn:
        models.ensure_payment_methods_table(conn)
        method_id = models.add_payment_method(conn, user_id, provider, external_id, brand, last4, exp_month, exp_year)
        conn.commit()
    return jsonify({
        'id': method_id,
        'provider': provider,
        'brand': brand,
        'last4': last4,
        'exp_month': exp_month,
        'exp_year': exp_year,
    }), 201


def _stripe_create_setup_intent_token(number, exp_month, exp_year, cvc):
    import requests as _requests
    secret = os.environ.get('STRIPE_SECRET_KEY')
    if not secret:
        raise RuntimeError('stripe_not_configured')
    response = _requests.post(
        'https://api.stripe.com/v1/setup_intents',
        data={'usage': 'off_session', 'payment_method_types[]': 'card'},
        auth=(secret, ''),
        timeout=15,
    )
    response.raise_for_status()
    data = response.json()
    return data.get('id', 'seti_unknown')


@bp.route('/api/cards/<int:card_id>', methods=['DELETE'])
def api_cards_delete(card_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_payment_methods_table(conn)
        ok = models.delete_payment_method(conn, user_id, card_id)
        conn.commit()
    if not ok:
        return jsonify({'error': 'not_found'}), 404
    return ('', 204)


@bp.route('/api/cards/<int:card_id>/default', methods=['POST'])
def api_cards_default(card_id):
    user_id = session.get('user_id')
    if user_id is None:
        return jsonify({'error': 'unauthorized'}), 401
    with models.get_conn() as conn:
        models.ensure_payment_methods_table(conn)
        ok = models.set_default_payment_method(conn, user_id, card_id)
        conn.commit()
    if not ok:
        return jsonify({'error': 'not_found'}), 404
    return jsonify({'ok': True})


def _has_error_template():
    return False


@bp.route('/webhook/stripe', methods=['POST'])
def webhook_stripe():
    payload_bytes = request.get_data()
    signature = request.headers.get('Stripe-Signature', '')
    if not payments.stripe_verify_signature(payload_bytes, signature):
        return jsonify({'error': 'invalid_signature'}), 400
    try:
        event = json.loads(payload_bytes.decode('utf-8'))
    except (ValueError, UnicodeDecodeError):
        return jsonify({'error': 'invalid_payload'}), 400
    if event.get('type') != 'payment_intent.succeeded':
        return jsonify({'received': True}), 200
    intent = event.get('data', {}).get('object', {})
    metadata = intent.get('metadata') or {}
    bid_id = metadata.get('bid_id')
    if bid_id is None:
        return jsonify({'received': True}), 200
    payment_id = payments.find_payment_by_bid(int(bid_id))
    if payment_id is not None:
        payments.mark_payment_paid(payment_id)
    return jsonify({'received': True}), 200


@bp.route('/webhook/yookassa', methods=['POST'])
def webhook_yookassa():
    if not request.is_json:
        return jsonify({'error': 'invalid_payload'}), 400
    payload = request.get_json(silent=True)
    if not payments.yookassa_verify_signature(payload):
        return jsonify({'error': 'invalid_signature'}), 400
    if payload.get('event') != 'payment.succeeded':
        return jsonify({'received': True}), 200
    metadata = (payload.get('object') or {}).get('metadata') or {}
    bid_id = metadata.get('bid_id')
    if bid_id is None:
        return jsonify({'received': True}), 200
    payment_id = payments.find_payment_by_bid(int(bid_id))
    if payment_id is not None:
        payments.mark_payment_paid(payment_id)
    return jsonify({'received': True}), 200


@bp.route('/webhook/idram', methods=['POST'])
def webhook_idram():
    form = request.form.to_dict()
    if not form:
        try:
            form = request.get_json(silent=True) or {}
        except Exception:
            form = {}
    if not payments.idram_verify_signature(form):
        return jsonify({'error': 'invalid_signature'}), 400
    bill_no = form.get('EDP_BILL_NO', '')
    if not bill_no.startswith('BS'):
        return jsonify({'received': True}), 200
    try:
        bid_id = int(bill_no[2:])
    except ValueError:
        return jsonify({'received': True}), 200
    payment_id = payments.find_payment_by_bid(bid_id)
    if payment_id is not None:
        payments.mark_payment_paid(payment_id)
    return ('OK', 200)


@bp.errorhandler(404)
def _not_found(e):
    if request.path.startswith('/api/') or request.path.startswith('/webhook/'):
        return jsonify({'error': 'not_found'}), 404
    return ('Not Found', 404)
