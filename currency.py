import os
import time
import threading
from datetime import datetime, timezone
import requests


class RatesUnavailableError(Exception):
    pass


_TTL = 3600.0
_cache = {'rates': None, 'fetched_at': 0.0, 'fetched_iso': None}
_lock = threading.Lock()
_API_URL_TEMPLATE = 'https://v6.exchangerate-api.com/v6/{key}/latest/USD'


FALLBACK_RATES = {'USD': 1.0, 'AMD': 390.0, 'RUB': 90.0}


def _fetch_rates():
    api_key = os.environ.get('EXCHANGERATE_API_KEY', '').strip()
    if not api_key:
        raise RatesUnavailableError('EXCHANGERATE_API_KEY is not configured')
    url = _API_URL_TEMPLATE.format(key=api_key)
    try:
        response = requests.get(url, timeout=10)
    except requests.RequestException as exc:
        raise RatesUnavailableError(str(exc)) from exc
    if response.status_code != 200:
        raise RatesUnavailableError('exchangerate-api returned status {}'.format(response.status_code))
    try:
        payload = response.json()
    except ValueError as exc:
        raise RatesUnavailableError(str(exc)) from exc
    if payload.get('result') != 'success':
        raise RatesUnavailableError(payload.get('error-type', 'unknown_error'))
    conversion = payload.get('conversion_rates') or {}
    amd = conversion.get('AMD')
    rub = conversion.get('RUB')
    if amd is None or rub is None:
        raise RatesUnavailableError('missing AMD or RUB in conversion_rates')
    return {'USD': 1.0, 'AMD': float(amd), 'RUB': float(rub)}


def get_rates():
    now = time.monotonic()
    with _lock:
        if _cache['rates'] is not None and (now - _cache['fetched_at']) < _TTL:
            return dict(_cache['rates']), _cache['fetched_iso']
    try:
        rates = _fetch_rates()
        fetched_iso = datetime.now(timezone.utc).isoformat()
    except RatesUnavailableError:
        rates = dict(FALLBACK_RATES)
        fetched_iso = None
    with _lock:
        _cache['rates'] = rates
        _cache['fetched_at'] = now
        _cache['fetched_iso'] = fetched_iso
    return dict(rates), fetched_iso


def invalidate_cache():
    with _lock:
        _cache['rates'] = None
        _cache['fetched_at'] = 0.0
        _cache['fetched_iso'] = None


def convert(amount_usd, currency):
    rates, _ = get_rates()
    rate = rates.get(currency)
    if rate is None:
        raise ValueError('unsupported currency: {}'.format(currency))
    return float(amount_usd) * rate
