import os
import json
import logging
import threading
import urllib.parse

import requests

import models


logger = logging.getLogger('bidstage.translator')

MYMEMORY_URL = 'https://api.mymemory.translated.net/get'

SUPPORTED = ('ru', 'en', 'hy')

_lock = threading.Lock()
_inflight = {}


def _ensure_table(conn):
    with conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS translation_cache ("
            "id BIGSERIAL PRIMARY KEY, "
            "source_hash TEXT NOT NULL, "
            "source_lang TEXT NOT NULL, "
            "target_lang TEXT NOT NULL, "
            "source_text TEXT NOT NULL, "
            "translated_text TEXT NOT NULL, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), "
            "UNIQUE(source_hash, source_lang, target_lang))"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_translation_lookup ON translation_cache (source_hash, target_lang)")


def _hash(text):
    import hashlib
    return hashlib.sha1(text.encode('utf-8')).hexdigest()


def _get_cached(source_text, source_lang, target_lang):
    h = _hash(source_text)
    try:
        with models.get_conn() as conn:
            _ensure_table(conn)
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT translated_text FROM translation_cache "
                    "WHERE source_hash = %s AND source_lang = %s AND target_lang = %s",
                    (h, source_lang, target_lang),
                )
                row = cur.fetchone()
            conn.commit()
            if row:
                return row[0]
    except Exception as exc:
        logger.warning('translation_cache_read_failed: %s', exc)
    return None


def _save_cache(source_text, source_lang, target_lang, translated):
    h = _hash(source_text)
    try:
        with models.get_conn() as conn:
            _ensure_table(conn)
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO translation_cache (source_hash, source_lang, target_lang, source_text, translated_text) "
                    "VALUES (%s, %s, %s, %s, %s) "
                    "ON CONFLICT (source_hash, source_lang, target_lang) DO NOTHING",
                    (h, source_lang, target_lang, source_text, translated),
                )
            conn.commit()
    except Exception as exc:
        logger.warning('translation_cache_write_failed: %s', exc)


def _detect_lang(text):
    if not text:
        return 'ru'
    if any('\u0400' <= ch <= '\u04ff' for ch in text):
        return 'ru'
    if any('\u0530' <= ch <= '\u058f' for ch in text):
        return 'hy'
    return 'en'


def translate(text, target_lang, source_lang=None):
    if not text or not isinstance(text, str):
        return text
    if target_lang not in SUPPORTED:
        return text
    if source_lang is None:
        source_lang = _detect_lang(text)
    if source_lang == target_lang:
        return text
    cached = _get_cached(text, source_lang, target_lang)
    if cached is not None:
        return cached
    key = (text, source_lang, target_lang)
    with _lock:
        if key in _inflight:
            return text
        _inflight[key] = True
    try:
        params = {
            'q': text,
            'langpair': '{}|{}'.format(source_lang, target_lang),
            'de': os.environ.get('TRANSLATOR_EMAIL', 'bidstage@example.com'),
        }
        response = requests.get(MYMEMORY_URL, params=params, timeout=8)
        if response.status_code != 200:
            return text
        payload = response.json()
        rd = payload.get('responseData') or {}
        translated = rd.get('translatedText') or ''
        if not translated:
            return text
        if translated.strip().lower() == text.strip().lower():
            return text
        _save_cache(text, source_lang, target_lang, translated)
        return translated
    except Exception as exc:
        logger.warning('translate_failed: %s', exc)
        return text
    finally:
        with _lock:
            _inflight.pop(key, None)


def translate_batch(items, target_lang, source_lang=None):
    return [translate(it, target_lang, source_lang) for it in items]
