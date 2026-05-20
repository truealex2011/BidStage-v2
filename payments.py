import os
import re
import time
import hmac
import base64
import hashlib
import logging
import secrets
import threading
import urllib.parse
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP

import requests

import models
import currency
import socket_events
import notify


logger = logging.getLogger('bidstage.payments')

VK_WALL_GETBYID = 'https://api.vk.com/method/wall.getById'
VK_API_VERSION = '5.131'

STRIPE_API_BASE = 'https://api.stripe.com/v1'
YOOKASSA_API_BASE = 'https://api.yookassa.ru/v3'
IDRAM_REDIRECT_BASE = 'https://banking.idram.am/Payment/GetPayment'

PROVIDER_BY_COUNTRY = {'AM': 'idram', 'RU': 'yookassa', 'OTHER': 'stripe'}
CURRENCY_BY_PROVIDER = {'stripe': 'USD', 'yookassa': 'RUB', 'idram': 'AMD'}

PAYMENT_TTL = timedelta(hours=24)
RELIST_DELAY = timedelta(hours=24)


_relist_lock = threading.Lock()
_relist_jobs = {}


def _now_utc():
    return datetime.now(timezone.utc)


def _round_money(value):
    return Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _public_base_url():
    return os.environ.get('PUBLIC_BASE_URL', '').rstrip('/')


def parse_vk_post_url(share_url):
    if not isinstance(share_url, str):
        return None
    match = re.search(r'wall(-?\d+)_(\d+)', share_url)
    if match:
        return '{}_{}'.format(match.group(1), match.group(2))
    return None


def verify_share(bid_id, share_url):
    if _dev_auto_verify():
        _accept_bid(bid_id)
        return 'verified'
    delays = (1.0, 5.0, 30.0)
    last_error = None
    for attempt, delay in enumerate(delays + (None,)):
        try:
            outcome = _verify_share_attempt(bid_id, share_url)
        except _RetryableError as exc:
            last_error = exc
            if delay is None:
                break
            time.sleep(delay)
            continue
        return outcome
    logger.warning('verify_share exhausted retries bid_id=%s lot_unknown reason=%s', bid_id, last_error)
    _reject_bid(bid_id, 'verification_failed')
    return 'rejected'


def _dev_auto_verify():
    if os.environ.get('VK_AUTO_VERIFY') == '1':
        return True
    return False


class _RetryableError(Exception):
    pass


_BROWSER_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'ru,en-US;q=0.7,en;q=0.3',
}


def _is_supported_share_host(share_url):
    if not isinstance(share_url, str):
        return False
    url = share_url.strip().lower()
    if not (url.startswith('http://') or url.startswith('https://')):
        return False
    allowed = (
        'vk.com', 'm.vk.com',
        'facebook.com', 'm.facebook.com', 'web.facebook.com',
        'twitter.com', 'x.com', 'mobile.twitter.com',
        't.me', 'telegram.me',
        'ok.ru', 'm.ok.ru',
        'instagram.com',
        'linkedin.com',
        'reddit.com',
        'pinterest.com',
    )
    try:
        from urllib.parse import urlparse as _urlparse
        host = (_urlparse(url).hostname or '').lower()
    except Exception:
        return False
    return any(host == h or host.endswith('.' + h) for h in allowed)


def _verify_share_attempt(bid_id, share_url):
    if not _is_supported_share_host(share_url):
        _reject_bid(bid_id, 'invalid_share_url')
        return 'rejected'
    bid_lot = _bid_lot_id(bid_id)
    if bid_lot is None:
        return 'rejected'
    expected_path = '/lot/{}'.format(bid_lot).lower()
    try:
        response = requests.get(share_url, headers=_BROWSER_HEADERS, timeout=12, allow_redirects=True)
    except requests.RequestException as exc:
        raise _RetryableError(str(exc)) from exc
    if response.status_code in (429, 502, 503, 504):
        raise _RetryableError('http_status_{}'.format(response.status_code))
    if response.status_code == 404:
        _reject_bid(bid_id, 'post_not_found')
        return 'rejected'
    if response.status_code >= 400:
        _reject_bid(bid_id, 'http_error_{}'.format(response.status_code))
        return 'rejected'
    body = (response.text or '').lower()
    if expected_path not in body:
        _reject_bid(bid_id, 'link_missing')
        return 'rejected'
    _accept_bid(bid_id)
    return 'verified'


def _bid_lot_id(bid_id):
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT lot_id FROM bids WHERE id = %s', (bid_id,))
            row = cur.fetchone()
            if row is None:
                return None
            return int(row[0])


def _accept_bid(bid_id):
    lot_id_for_emit = None
    new_top_amount = None
    new_top_username = None
    bidder_user_id = None
    with models.get_conn() as conn:
        models.set_share_verified(conn, bid_id)
        models.ensure_lot_events_table(conn)
        with conn.cursor() as cur:
            cur.execute('SELECT lot_id, user_id, amount_usd FROM bids WHERE id = %s', (bid_id,))
            row = cur.fetchone()
            if row is not None:
                lot_id_v, user_id_v, amount_v = row
                lot_id_for_emit = int(lot_id_v)
                bidder_user_id = int(user_id_v)
                cur.execute('SELECT username FROM users WHERE id = %s', (user_id_v,))
                u = cur.fetchone()
                username = u[0] if u else None
                models.insert_lot_event(conn, lot_id_v, 'share_verified', actor_username=username, actor_user_id=user_id_v, amount_usd=amount_v)
                new_top_amount = float(amount_v)
                new_top_username = username
        conn.commit()
    if lot_id_for_emit is not None:
        socket_events.emit_to_lot(lot_id_for_emit, 'bid_verified', {
            'lot_id': lot_id_for_emit,
            'bid_id': int(bid_id),
            'amount_usd': new_top_amount,
            'username': new_top_username,
        })
        try:
            _trigger_proxy_rebid(lot_id_for_emit, bidder_user_id)
        except Exception as exc:
            logger.exception('proxy_rebid_failed lot_id=%s err=%s', lot_id_for_emit, exc)
    logger.info('share_verified bid_id=%s', bid_id)


def _trigger_proxy_rebid(lot_id, last_bidder_user_id):
    from decimal import Decimal as _D
    with models.get_conn() as conn:
        models.ensure_proxy_bid_columns(conn)
        conn.commit()
        with conn.cursor() as cur:
            cur.execute('SELECT id, status, end_time, bid_step_usd FROM lots WHERE id = %s', (lot_id,))
            row = cur.fetchone()
            if row is None:
                conn.commit()
                return
            _, status, end_time, bid_step_usd = row
            if status != 'active':
                conn.commit()
                return
        max_verified = models.get_max_verified_amount(conn, lot_id)
        if max_verified is None:
            conn.commit()
            return
        current_top = _D(str(max_verified))
        step = _D(str(bid_step_usd))
        proxies = models.get_active_proxy_bids(conn, lot_id)
        logger.info('proxy_rebid_check lot_id=%s current_top=%s proxies=%s last_bidder=%s',
                    lot_id, current_top, [(p['user_id'], p['max_amount_usd']) for p in proxies], last_bidder_user_id)
        candidate = None
        for p in proxies:
            if int(p['user_id']) == int(last_bidder_user_id):
                continue
            pmax = _D(str(p['max_amount_usd']))
            if pmax >= current_top + step:
                if candidate is None or pmax > _D(str(candidate['max_amount_usd'])):
                    candidate = p
        if candidate is None:
            logger.info('proxy_rebid_no_candidate lot_id=%s', lot_id)
            conn.commit()
            return
        target = current_top + step
        balance = models.get_balance(conn, int(candidate['user_id']))
        if balance is not None and _D(str(balance)) < target:
            logger.info('proxy_rebid_insufficient_balance lot_id=%s user=%s balance=%s target=%s',
                        lot_id, candidate['user_id'], balance, target)
            models.deactivate_proxy_bid(conn, lot_id, int(candidate['user_id']))
            conn.commit()
            notify.notify_event(
                int(candidate['user_id']), 'proxy_stopped',
                '⚠️ Автоставка остановлена',
                'Недостаточно средств для следующей ставки ${:.2f} по лоту. Пополните баланс и поставьте ставку вручную.'.format(float(target)),
                lot_id=int(lot_id),
            )
            return
        if models.duplicate_bid_exists(conn, lot_id, int(candidate['user_id']), target, candidate['share_url']):
            conn.commit()
            return
        new_bid_id = models.insert_bid(conn, lot_id, int(candidate['user_id']), target, candidate['share_url'])
        models.insert_lot_event(conn, lot_id, 'new_bid', actor_username=candidate.get('username'), actor_user_id=int(candidate['user_id']), amount_usd=target)
        conn.commit()
        logger.info('proxy_rebid_placed lot_id=%s user=%s amount=%s bid_id=%s',
                    lot_id, candidate['user_id'], target, new_bid_id)
    if new_bid_id is not None:
        socket_events.emit_to_lot(lot_id, 'new_bid', {
            'lot_id': int(lot_id),
            'bid_id': int(new_bid_id),
            'user': candidate.get('username') or 'user',
            'user_id': int(candidate['user_id']),
            'amount_usd': float(target),
            'timestamp': _now_utc().isoformat(),
            'is_proxy': True,
        })
        socket_events.emit_to_user(int(last_bidder_user_id), 'outbid', {
            'lot_id': int(lot_id),
            'new_amount_usd': float(target),
        })
        notify.notify_event(
            int(last_bidder_user_id), 'outbid',
            '⚡ Вашу ставку перебили',
            'По лоту #{} ваша ставка перебита. Новая ставка: {:.2f} USD. Поставьте ставку выше, чтобы вернуть лидерство.'.format(lot_id, float(target)),
            lot_id=int(lot_id),
            send_chat=False,
        )
        schedule_share_verification(new_bid_id, candidate['share_url'])


def _reject_bid(bid_id, reason):
    reason_messages = {
        'link_missing': 'В посте по вашей ссылке не найдено упоминание этого лота. Опубликуйте пост, в тексте которого есть ссылка на /lot/{lot_id}, и сделайте ставку заново.',
        'post_not_found': 'Пост по вашей ссылке не найден или удалён. Опубликуйте пост заново и сделайте ставку.',
        'invalid_share_url': 'Ссылка не является постом из соцсети. Поддерживаются: VK, Facebook, Twitter/X, Telegram, OK, Reddit и др.',
        'wall_closed': 'Стена/группа закрыта. Опубликуйте пост в открытом профиле или паблике.',
        'verification_failed': 'Не удалось проверить ваш пост. Возможно, соцсеть временно недоступна. Попробуйте сделать ставку ещё раз через минуту.',
    }
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT id, lot_id, user_id, amount_usd FROM bids WHERE id = %s', (bid_id,))
            row = cur.fetchone()
            if row is None:
                conn.commit()
                logger.info('share_rejected_no_bid bid_id=%s reason=%s', bid_id, reason)
                return
            _, lot_id, user_id, amount_val = row
            cur.execute('SELECT username FROM users WHERE id = %s', (user_id,))
            u = cur.fetchone()
            username = u[0] if u else None
            cur.execute('SELECT title FROM lots WHERE id = %s', (lot_id,))
            t = cur.fetchone()
            lot_title = t[0] if t else ''
            top = models.top_verified_bid(conn, lot_id)
            was_top = top is not None and int(top['id']) == int(bid_id)
            models.delete_bid(conn, bid_id)
            models.ensure_lot_events_table(conn)
            models.insert_lot_event(conn, lot_id, 'bid_cancelled', actor_username=username, actor_user_id=user_id, amount_usd=amount_val, payload={'reason': reason})
            conn.commit()
            socket_events.emit_to_user(user_id, 'bid_cancelled', {
                'bid_id': int(bid_id),
                'lot_id': int(lot_id),
                'reason': reason,
            })
            if was_top:
                next_top = models.top_verified_bid(conn, lot_id)
                if next_top is not None:
                    socket_events.emit_to_lot(lot_id, 'new_top_bid', {
                        'lot_id': int(lot_id),
                        'bid_id': int(next_top['id']),
                        'amount_usd': float(next_top['amount_usd']),
                    })
    explanation = reason_messages.get(reason, 'Причина: {}'.format(reason)).replace('{lot_id}', str(lot_id))
    notify.notify_event(
        int(user_id), 'bid_rejected',
        '❌ Ставка ${:.2f} отклонена'.format(float(amount_val)),
        'Лот «{}»\n\n{}\n\nСтавка не учтена. Деньги не списаны. Сделайте новую ставку, опубликовав пост со ссылкой на лот.'.format(lot_title, explanation),
        lot_id=int(lot_id),
    )
    logger.info('share_rejected bid_id=%s reason=%s', bid_id, reason)


def _generate_ticket_code():
    raw = secrets.token_bytes(20)
    return base64.b32encode(raw).decode('ascii').rstrip('=')[:32]


def _amount_in_currency(amount_usd, target_currency):
    if target_currency == 'USD':
        return _round_money(amount_usd), 'USD'
    try:
        rates, _ = currency.get_rates()
    except currency.RatesUnavailableError:
        rates = {'USD': 1.0, 'AMD': 390.0, 'RUB': 90.0}
    rate = rates.get(target_currency, 1.0)
    return _round_money(Decimal(str(amount_usd)) * Decimal(str(rate))), target_currency


def create_payment(bid_id, user_id, amount_usd, country, payment_window_minutes=None):
    provider = PROVIDER_BY_COUNTRY.get(country, 'stripe')
    target_currency = CURRENCY_BY_PROVIDER[provider]
    amount_target, _ = _amount_in_currency(amount_usd, target_currency)
    if payment_window_minutes is not None and payment_window_minutes > 0:
        ttl = timedelta(minutes=int(payment_window_minutes))
    else:
        ttl = PAYMENT_TTL
    expires_at = _now_utc() + ttl
    try:
        if provider == 'stripe':
            payment_url = _stripe_create_payment(bid_id, amount_target)
        elif provider == 'yookassa':
            payment_url = _yookassa_create_payment(bid_id, amount_target)
        elif provider == 'idram':
            payment_url = _idram_create_payment(bid_id, amount_target)
        else:
            payment_url = None
    except Exception as exc:
        logger.exception('payment_provider_error bid_id=%s provider=%s err=%s', bid_id, provider, exc)
        payment_url = None
    with models.get_conn() as conn:
        payment_id = models.insert_payment(
            conn, bid_id, user_id, _round_money(amount_usd),
            target_currency, provider, 'pending', payment_url, expires_at,
        )
        conn.commit()
    return {
        'payment_id': int(payment_id),
        'provider': provider,
        'currency': target_currency,
        'amount': float(amount_target),
        'payment_url': payment_url,
        'expires_at': expires_at.isoformat(),
        'window_minutes': int(ttl.total_seconds() // 60),
    }


def _stripe_create_payment(bid_id, amount_decimal):
    secret_key = os.environ.get('STRIPE_SECRET_KEY', '')
    if not secret_key:
        return None
    minor = int((amount_decimal * Decimal('100')).quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    data = {
        'amount': minor,
        'currency': 'usd',
        'metadata[bid_id]': str(bid_id),
        'automatic_payment_methods[enabled]': 'true',
    }
    response = requests.post(
        '{}/payment_intents'.format(STRIPE_API_BASE),
        data=data,
        auth=(secret_key, ''),
        timeout=15,
    )
    response.raise_for_status()
    payload = response.json()
    return payload.get('client_secret')


def _yookassa_create_payment(bid_id, amount_decimal):
    shop_id = os.environ.get('YOOKASSA_SHOP_ID', '')
    secret_key = os.environ.get('YOOKASSA_SECRET_KEY', '')
    if not shop_id or not secret_key:
        return None
    return_url = '{}/payments/return'.format(_public_base_url())
    body = {
        'amount': {'value': '{:.2f}'.format(amount_decimal), 'currency': 'RUB'},
        'capture': True,
        'confirmation': {'type': 'redirect', 'return_url': return_url},
        'description': 'BidStage bid {}'.format(bid_id),
        'metadata': {'bid_id': str(bid_id)},
    }
    headers = {
        'Idempotence-Key': secrets.token_hex(16),
        'Content-Type': 'application/json',
    }
    response = requests.post(
        '{}/payments'.format(YOOKASSA_API_BASE),
        json=body,
        auth=(shop_id, secret_key),
        headers=headers,
        timeout=15,
    )
    response.raise_for_status()
    payload = response.json()
    confirmation = payload.get('confirmation') or {}
    return confirmation.get('confirmation_url')


def _idram_create_payment(bid_id, amount_decimal):
    merchant_id = os.environ.get('IDRAM_MERCHANT_ID', '')
    secret = os.environ.get('IDRAM_SECRET', '')
    if not merchant_id or not secret:
        return None
    bill_no = 'BS{}'.format(bid_id)
    amount_str = '{:.2f}'.format(amount_decimal)
    payload = '{}:{}:{}'.format(bill_no, amount_str, merchant_id)
    signature = hmac.new(secret.encode('utf-8'), payload.encode('utf-8'), hashlib.sha256).hexdigest()
    params = {
        'EDP_LANGUAGE': 'EN',
        'EDP_REC_ACCOUNT': merchant_id,
        'EDP_DESCRIPTION': 'BidStage bid {}'.format(bid_id),
        'EDP_AMOUNT': amount_str,
        'EDP_BILL_NO': bill_no,
        'EDP_SIG': signature,
    }
    return '{}?{}'.format(IDRAM_REDIRECT_BASE, urllib.parse.urlencode(params))


def stripe_verify_signature(payload_bytes, signature_header):
    secret = os.environ.get('STRIPE_WEBHOOK_SECRET', '')
    if not secret or not signature_header:
        return False
    parts = dict(p.split('=', 1) for p in signature_header.split(',') if '=' in p)
    timestamp = parts.get('t')
    received = parts.get('v1')
    if not timestamp or not received:
        return False
    signed_payload = '{}.{}'.format(timestamp, payload_bytes.decode('utf-8') if isinstance(payload_bytes, bytes) else payload_bytes)
    expected = hmac.new(secret.encode('utf-8'), signed_payload.encode('utf-8'), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, received)


def yookassa_verify_signature(payload_dict):
    return isinstance(payload_dict, dict) and payload_dict.get('type') == 'notification'


def idram_verify_signature(form_dict):
    secret = os.environ.get('IDRAM_SECRET', '')
    if not secret:
        return False
    bill_no = form_dict.get('EDP_BILL_NO', '')
    amount = form_dict.get('EDP_AMOUNT', '')
    received = form_dict.get('EDP_SIG', '')
    merchant = os.environ.get('IDRAM_MERCHANT_ID', '')
    payload = '{}:{}:{}'.format(bill_no, amount, merchant)
    expected = hmac.new(secret.encode('utf-8'), payload.encode('utf-8'), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, received)


def mark_payment_paid(payment_id):
    with models.get_conn() as conn:
        models.ensure_escrow_columns(conn)
        payment = models.get_payment(conn, payment_id)
        if payment is None:
            conn.commit()
            return None
        if payment['status'] == 'paid':
            conn.commit()
            return payment
        models.update_payment_status(conn, payment_id, 'paid')
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE payments SET held_in_escrow = TRUE WHERE id = %s",
                (payment_id,),
            )
            cur.execute(
                'SELECT b.lot_id, b.user_id, l.title, l.seller_id, b.amount_usd '
                'FROM payments p JOIN bids b ON b.id = p.bid_id JOIN lots l ON l.id = b.lot_id '
                'WHERE p.id = %s',
                (payment_id,),
            )
            ctx_row = cur.fetchone()
            ctx_lot_id = int(ctx_row[0]) if ctx_row else None
            ctx_buyer_id = int(ctx_row[1]) if ctx_row else None
            ctx_lot_title = ctx_row[2] if ctx_row else ''
            ctx_seller_id = int(ctx_row[3]) if ctx_row and ctx_row[3] is not None else None
            ctx_amount = float(ctx_row[4]) if ctx_row else 0.0
            ctx_buyer_username = None
            if ctx_buyer_id is not None:
                cur.execute('SELECT username FROM users WHERE id = %s', (ctx_buyer_id,))
                u = cur.fetchone()
                if u:
                    ctx_buyer_username = u[0]
        conn.commit()
        ticket_code = _generate_ticket_code()
        socket_events.emit_to_user(payment['user_id'], 'payment_completed', {
            'payment_id': int(payment_id),
            'ticket_code': ticket_code,
            'escrow': True,
        })
        if ctx_buyer_id is not None and ctx_lot_id is not None:
            notify.notify_event(
                ctx_buyer_id, 'payment_paid',
                '✅ Оплата принята по лоту «{}»'.format(ctx_lot_title or ''),
                'Сумма ${:.2f} отправлена в эскроу. Ожидайте, пока продавец отправит билет, затем подтвердите получение в профиле.'.format(ctx_amount),
                lot_id=ctx_lot_id, payment_id=int(payment_id),
            )
        if ctx_seller_id is not None and ctx_lot_id is not None:
            notify.notify_event(
                ctx_seller_id, 'buyer_paid',
                '💸 Покупатель оплатил лот «{}»'.format(ctx_lot_title or ''),
                'Покупатель {} оплатил ${:.2f}.\n\n'
                'Деньги в эскроу — пока не у вас. Что делать:\n'
                '1. Откройте «Продать → Мои аукционы» (правый верхний угол)\n'
                '2. Найдите блок «🔒 Эскроу»\n'
                '3. Введите код билета и нажмите «Билет отправлен»\n\n'
                'После того как покупатель подтвердит получение — '
                'деньги поступят на ваш баланс.'.format(ctx_buyer_username or '', ctx_amount),
                lot_id=ctx_lot_id, payment_id=int(payment_id),
            )
        logger.info('payment_paid_to_escrow payment_id=%s ticket=%s', payment_id, ticket_code)
        return {**payment, 'ticket_code': ticket_code}


def find_payment_by_bid(bid_id):
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT id FROM payments WHERE bid_id = %s ORDER BY created_at DESC LIMIT 1',
                (bid_id,),
            )
            row = cur.fetchone()
            return int(row[0]) if row else None


def schedule_relist(scheduler, lot_id, original_duration_seconds):
    if scheduler is None:
        return
    run_at = _now_utc() + RELIST_DELAY
    job_id = 'relist_lot_{}'.format(lot_id)
    with _relist_lock:
        _relist_jobs[lot_id] = original_duration_seconds
    scheduler.add_job(
        _relist_job,
        trigger='date',
        run_date=run_at,
        args=[lot_id, original_duration_seconds],
        id=job_id,
        replace_existing=True,
    )
    logger.info('relist_scheduled lot_id=%s at=%s', lot_id, run_at.isoformat())


def _relist_job(lot_id, original_duration_seconds):
    new_end_time = _now_utc() + timedelta(seconds=int(original_duration_seconds))
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE lots SET status = 'active', winner_id = NULL, end_time = %s WHERE id = %s",
                (new_end_time, lot_id),
            )
        conn.commit()
    logger.info('relisted lot_id=%s new_end_time=%s', lot_id, new_end_time.isoformat())


def end_expired_lots(scheduler=None):
    with models.get_conn() as conn:
        lots = models.expired_active_lots(conn)
        conn.commit()
    for lot in lots:
        _end_single_lot(lot['id'], int(lot['original_duration_seconds']), scheduler)


def _format_window_minutes(minutes):
    minutes = int(minutes)
    if minutes < 60:
        return '{} мин'.format(minutes)
    hours = minutes // 60
    rem = minutes % 60
    if rem == 0:
        return '{} ч'.format(hours)
    return '{} ч {} мин'.format(hours, rem)


def _end_single_lot(lot_id, original_duration_seconds, scheduler):
    with models.get_conn() as conn:
        lot = models.get_lot_for_update(conn, lot_id)
        if lot is None or lot['status'] != 'active':
            conn.commit()
            return
        top = models.top_verified_bid(conn, lot_id)
        if top is None:
            models.set_lot_status(conn, lot_id, 'cancelled', None)
            no_winner_seller_id, no_winner_title = models.get_lot_seller(conn, lot_id)
            conn.commit()
            schedule_relist(scheduler, lot_id, original_duration_seconds)
            if no_winner_seller_id is not None:
                notify.notify_event(
                    int(no_winner_seller_id), 'auction_no_winner',
                    '😔 Лот «{}» закрыт без победителя'.format(no_winner_title or ''),
                    'На лот не было ни одной подтверждённой ставки. Лот будет автоматически перевыставлен через 24 часа с тем же таймером.',
                    lot_id=int(lot_id),
                )
            return
        models.set_lot_status(conn, lot_id, 'ended', int(top['user_id']))
        ranked = models.list_lot_runner_ups(conn, lot_id)
        payment_window = models.get_lot_payment_window(conn, lot_id)
        seller_id, lot_title = models.get_lot_seller(conn, lot_id)
        conn.commit()
    user_country = _get_user_country(int(top['user_id']))
    payment = create_payment(int(top['id']), int(top['user_id']), top['amount_usd'], user_country, payment_window_minutes=payment_window)
    with models.get_conn() as conn:
        models.ensure_lot_events_table(conn)
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (int(top['user_id']),))
            u = cur.fetchone()
            winner_username = u[0] if u else None
        models.insert_lot_event(conn, lot_id, 'auction_ended', actor_username=winner_username, actor_user_id=int(top['user_id']), amount_usd=top['amount_usd'])
        conn.commit()
    socket_events.emit_to_lot(lot_id, 'auction_ended', {
        'lot_id': int(lot_id),
        'winner_id': int(top['user_id']),
        'amount_usd': float(top['amount_usd']),
        'payment_url': payment.get('payment_url'),
    })
    socket_events.emit_to_user(int(top['user_id']), 'payment_due', {
        'lot_id': int(lot_id),
        'payment_id': payment['payment_id'],
        'amount_usd': float(top['amount_usd']),
        'currency': payment['currency'],
        'amount': payment['amount'],
        'payment_url': payment.get('payment_url'),
        'expires_at': payment['expires_at'],
    })
    win_title = '🏆 Вы победили в аукционе «{}»!'.format(lot_title or '')
    win_body = (
        'Поздравляем! Ваша ставка ${:.2f} стала выигрышной.\n\n'
        'Что делать сейчас:\n'
        '1. Перейдите в раздел «Профиль» (правый верхний угол)\n'
        '2. Найдите блок «Эскроу и платежи»\n'
        '3. Нажмите «Оплатить картой» или «Списать с баланса»\n\n'
        '⏱ Срок оплаты: {}.\n'
        'Если не успеете — лот автоматически перейдёт следующему биддеру.\n\n'
        'После оплаты деньги уйдут в эскроу. Продавец отправит билет, '
        'вы получите уведомление и подтвердите получение — только после этого '
        'продавец получит деньги.'
    ).format(float(top['amount_usd']), _format_window_minutes(payment['window_minutes']))
    notify.notify_event(int(top['user_id']), 'auction_won', win_title, win_body, lot_id=int(lot_id), payment_id=payment['payment_id'])
    for idx, r in enumerate(ranked):
        if int(r['user_id']) == int(top['user_id']):
            continue
        place = idx + 1
        wait_minutes = (place - 1) * payment_window
        wait_str = _format_window_minutes(wait_minutes) if wait_minutes > 0 else 'до окончания периода оплаты'
        title = '🥈 Аукцион «{}» завершён. Вы заняли {}-е место'.format(lot_title or '', place)
        body = (
            'Победитель — пользователь {}, ставка ${:.2f}. '
            'Если вышестоящие участники не оплатят свои выигрыши, лот может перейти к вам. '
            'Ожидаемое время до вашей очереди: {}. Мы пришлём уведомление, как только это произойдёт.'
        ).format(winner_username or '', float(top['amount_usd']), wait_str)
        notify.notify_event(int(r['user_id']), 'auction_runner_up', title, body, lot_id=int(lot_id))
    if seller_id is not None:
        s_title = '🎉 Ваш лот «{}» продан'.format(lot_title or '')
        s_body = (
            'Победитель: {}. Сумма выигрыша: ${:.2f}. '
            'Покупатель должен оплатить в течение {}. Мы сообщим, как только оплата поступит.'
        ).format(winner_username or '', float(top['amount_usd']), _format_window_minutes(payment['window_minutes']))
        notify.notify_event(seller_id, 'lot_sold_pending_payment', s_title, s_body, lot_id=int(lot_id))
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE proxy_bids SET active = FALSE WHERE lot_id = %s", (lot_id,))
        conn.commit()


def _get_user_country(user_id):
    with models.get_conn() as conn:
        user = models.get_user(conn, user_id)
        conn.commit()
        if user is None:
            return 'OTHER'
        return user.get('country') or 'OTHER'


def cascade_expired_payments(scheduler=None):
    with models.get_conn() as conn:
        rows = models.expired_pending_payments(conn)
        conn.commit()
    for row in rows:
        _cascade_single(row['payment_id'], row['bid_id'], row['lot_id'], scheduler)


def _cascade_single(payment_id, bid_id, lot_id, scheduler):
    failed_user_id = None
    failed_username = None
    failed_amount = None
    with models.get_conn() as conn:
        models.update_payment_status(conn, payment_id, 'expired')
        with conn.cursor() as cur:
            cur.execute(
                'SELECT b.user_id, b.amount_usd, u.username '
                'FROM bids b JOIN users u ON u.id = b.user_id WHERE b.id = %s',
                (bid_id,),
            )
            row = cur.fetchone()
            if row is not None:
                failed_user_id = int(row[0])
                failed_amount = float(row[1])
                failed_username = row[2]
        excluded = _bids_with_payments(conn, lot_id)
        next_bid = models.next_verified_bid(conn, lot_id, excluded)
        ranked = models.list_lot_runner_ups(conn, lot_id)
        payment_window = models.get_lot_payment_window(conn, lot_id)
        seller_id, lot_title = models.get_lot_seller(conn, lot_id)
        conn.commit()
    if failed_user_id is not None:
        notify.notify_event(
            failed_user_id, 'payment_expired',
            '⏱️ Срок оплаты по лоту «{}» истёк'.format(lot_title or ''),
            'Вы не оплатили свою ставку ${:.2f} в отведённое время. Лот передан следующему участнику.'.format(failed_amount or 0.0),
            lot_id=int(lot_id), payment_id=int(payment_id),
        )
    if next_bid is None:
        with models.get_conn() as conn:
            lot = models.get_lot(conn, lot_id)
            if lot is not None:
                models.set_lot_status(conn, lot_id, 'cancelled', None)
            conn.commit()
        if lot is not None:
            schedule_relist(scheduler, lot_id, int(lot['original_duration_seconds']))
        if seller_id is not None:
            notify.notify_event(
                seller_id, 'lot_relisted',
                'Лот «{}» снят с аукциона'.format(lot_title or ''),
                'Никто из участников не оплатил выигрыш. Лот будет перевыставлен через 24 часа.',
                lot_id=int(lot_id),
            )
        # Уведомить всех остальных участников каскада что аукцион окончательно закрыт
        try:
            seen = set()
            if seller_id is not None:
                seen.add(int(seller_id))
            if failed_user_id is not None:
                seen.add(int(failed_user_id))
            for r in (ranked or []):
                uid = int(r.get('user_id') or 0)
                if not uid or uid in seen:
                    continue
                seen.add(uid)
                notify.notify_event(
                    uid, 'lot_cascade_closed',
                    'Аукцион «{}» окончательно закрыт'.format(lot_title or ''),
                    'Никто из участников каскада не оплатил выигрыш. Лот будет перевыставлен через 24 часа — следите за уведомлениями.',
                    lot_id=int(lot_id),
                )
        except Exception:
            pass
        return
    user_country = _get_user_country(int(next_bid['user_id']))
    payment = create_payment(int(next_bid['id']), int(next_bid['user_id']), next_bid['amount_usd'], user_country, payment_window_minutes=payment_window)
    with models.get_conn() as conn:
        models.set_lot_status(conn, lot_id, 'ended', int(next_bid['user_id']))
        conn.commit()
    socket_events.emit_to_user(int(next_bid['user_id']), 'payment_due', {
        'lot_id': int(lot_id),
        'payment_id': payment['payment_id'],
        'amount_usd': float(next_bid['amount_usd']),
        'currency': payment['currency'],
        'amount': payment['amount'],
        'payment_url': payment.get('payment_url'),
        'expires_at': payment['expires_at'],
    })
    new_winner_username = None
    with models.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT username FROM users WHERE id = %s', (int(next_bid['user_id']),))
            u = cur.fetchone()
            new_winner_username = u[0] if u else None
        conn.commit()
    title = '🏆 Лот «{}» переходит к вам!'.format(lot_title or '')
    body = (
        'Победитель не оплатил вовремя, и по правилам каскада лот теперь ваш.\n\n'
        'Сумма к оплате: ${:.2f}\n\n'
        'Что делать:\n'
        '1. Откройте «Профиль» в правом верхнем углу\n'
        '2. В блоке «Эскроу и платежи» нажмите «Оплатить картой» или «Списать с баланса»\n\n'
        '⏱ У вас есть {} на оплату. Если не успеете — лот достанется следующему биддеру.\n\n'
        'После оплаты деньги уйдут в эскроу до подтверждения получения билета.'
    ).format(float(next_bid['amount_usd']), _format_window_minutes(payment['window_minutes']))
    notify.notify_event(int(next_bid['user_id']), 'cascade_advanced', title, body, lot_id=int(lot_id), payment_id=payment['payment_id'])
    new_winner_id = int(next_bid['user_id'])
    new_winner_position = None
    for idx, r in enumerate(ranked):
        if int(r['user_id']) == new_winner_id:
            new_winner_position = idx
            break
    for idx, r in enumerate(ranked):
        uid = int(r['user_id'])
        if uid == new_winner_id or uid == failed_user_id:
            continue
        if new_winner_position is not None and idx <= new_winner_position:
            continue
        place_now = idx - (new_winner_position or 0)
        wait_minutes = max(0, (place_now - 1) * payment_window)
        wait_str = _format_window_minutes(wait_minutes) if wait_minutes > 0 else 'до окончания текущего периода оплаты'
        info_title = 'Каскад по лоту «{}»: пользователь {} не оплатил'.format(lot_title or '', failed_username or '')
        info_body = (
            'Лот перешёл к {}. Если он также не оплатит, '
            'возможно лот достанется вам. Ожидаемое время до вашей очереди: {}.'
        ).format(new_winner_username or '', wait_str)
        notify.notify_event(uid, 'cascade_advanced', info_title, info_body, lot_id=int(lot_id))
    if seller_id is not None:
        notify.notify_event(
            seller_id, 'cascade_advanced',
            'Лот «{}»: новый победитель'.format(lot_title or ''),
            'Предыдущий победитель не оплатил. Теперь лот за {} по ставке ${:.2f}.'.format(new_winner_username or '', float(next_bid['amount_usd'])),
            lot_id=int(lot_id),
        )


def _bids_with_payments(conn, lot_id):
    with conn.cursor() as cur:
        cur.execute(
            'SELECT DISTINCT bid_id FROM payments WHERE bid_id IN (SELECT id FROM bids WHERE lot_id = %s)',
            (lot_id,),
        )
        rows = cur.fetchall()
        return [int(r[0]) for r in rows] or [0]


def schedule_share_verification(bid_id, share_url):
    delay_seconds = 2.0 if _dev_auto_verify() else 60.0
    timer = threading.Timer(delay_seconds, verify_share, args=(bid_id, share_url))
    timer.daemon = True
    timer.start()
    return timer
