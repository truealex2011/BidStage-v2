import re
import unicodedata

try:
    from rapidfuzz import fuzz, utils as rf_utils
    _HAS_RAPIDFUZZ = True
except ImportError:
    _HAS_RAPIDFUZZ = False


STOP_WORDS = {
    'хочу', 'хотел', 'хотела', 'хотим', 'нужен', 'нужна', 'нужно', 'нужны',
    'ищу', 'найди', 'найти', 'найдите', 'покажи', 'покажите', 'есть',
    'купить', 'куплю', 'покупка', 'покупаю', 'приобрести', 'возьму',
    'хочется', 'хотелось', 'желаю', 'мне', 'мной', 'я', 'ты', 'мы', 'вы',
    'они', 'он', 'она', 'оно',
    'это', 'этот', 'эта', 'эти', 'эту', 'этого', 'этой',
    'тот', 'та', 'те', 'то',
    'или', 'и', 'а', 'но', 'да', 'же', 'ли', 'ну', 'вот', 'тут', 'там', 'где',
    'как', 'что', 'кто', 'почему', 'зачем', 'когда', 'куда', 'откуда',
    'для', 'от', 'до', 'из', 'к', 'ко', 'в', 'во', 'на', 'над', 'под', 'при',
    'про', 'без', 'через', 'у', 'с', 'со', 'о', 'об', 'обо', 'по', 'за',
    'мой', 'моя', 'моё', 'мои', 'твой', 'наш', 'ваш', 'их', 'его', 'её',
    'не', 'ни', 'бы', 'будет', 'был', 'была', 'были', 'есть',
    'еще', 'ещё', 'уже', 'тоже', 'также', 'очень', 'сильно',
    'пожалуйста', 'плиз', 'плз',
    'купи', 'продай', 'продаёт', 'продаёшь', 'дай', 'дайте',
    'i', 'want', 'need', 'looking', 'find', 'buy', 'purchase', 'get',
    'a', 'an', 'the', 'this', 'that', 'these', 'those', 'is', 'are', 'was',
    'be', 'been', 'and', 'or', 'but', 'of', 'in', 'on', 'at', 'to', 'for',
    'with', 'from', 'by', 'about', 'as', 'me', 'my', 'mine', 'we', 'our',
    'you', 'your', 'they', 'them', 'their', 'he', 'she', 'it', 'its',
    'please', 'plz',
}


_RU_TO_LAT = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
}

_LAT_TO_RU_PAIRS = [
    ('shch', 'щ'), ('sch', 'щ'), ('zh', 'ж'), ('ch', 'ч'), ('sh', 'ш'),
    ('ts', 'ц'), ('yu', 'ю'), ('ya', 'я'), ('yo', 'ё'),
    ('y', 'й'),
    ('a', 'а'), ('b', 'б'), ('v', 'в'), ('w', 'в'), ('g', 'г'), ('d', 'д'),
    ('e', 'е'), ('z', 'з'), ('i', 'и'), ('k', 'к'), ('l', 'л'), ('m', 'м'),
    ('n', 'н'), ('o', 'о'), ('p', 'п'), ('r', 'р'), ('s', 'с'), ('t', 'т'),
    ('u', 'у'), ('f', 'ф'), ('h', 'х'), ('x', 'х'), ('c', 'к'), ('q', 'к'),
    ('j', 'ж'),
]


def _strip_diacritics(s):
    nfkd = unicodedata.normalize('NFKD', s)
    return ''.join(c for c in nfkd if not unicodedata.combining(c))


def _normalize_word(word):
    word = word.lower().strip()
    word = _strip_diacritics(word)
    return word


def _to_latin(word):
    out = []
    for ch in word:
        if ch in _RU_TO_LAT:
            out.append(_RU_TO_LAT[ch])
        else:
            out.append(ch)
    return ''.join(out)


def _to_cyrillic(word):
    s = word
    for lat, rus in _LAT_TO_RU_PAIRS:
        s = s.replace(lat, rus)
    return s


def _stem(word):
    if len(word) <= 3:
        return word
    suffixes = (
        'ами', 'ями', 'иями', 'ями', 'ого', 'ему', 'ому', 'ыми', 'ими',
        'ой', 'ей', 'ую', 'юю', 'ая', 'яя', 'ое', 'ее', 'ие', 'ые',
        'ах', 'ях', 'ом', 'ем', 'ам', 'ям',
        'ть', 'ться', 'ешь', 'ишь', 'ете', 'ите',
        'ки', 'ка', 'ко', 'ку', 'ке',
        'ов', 'ев', 'ин', 'ын',
        'ing', 'ed', 'es', 's', 'ly',
    )
    for suf in suffixes:
        if word.endswith(suf) and len(word) - len(suf) >= 3:
            return word[: -len(suf)]
    return word


def tokenize(query):
    if not query:
        return []
    cleaned = re.sub(r'[^\w\s]+', ' ', query, flags=re.UNICODE)
    cleaned = cleaned.replace('_', ' ')
    raw = [w for w in cleaned.split() if w]
    out = []
    seen = set()
    for word in raw:
        norm = _normalize_word(word)
        if not norm:
            continue
        if norm in STOP_WORDS:
            continue
        if len(norm) < 2 and not norm.isdigit():
            continue
        variants = {norm}
        variants.add(_stem(norm))
        if any('а' <= ch <= 'я' or ch == 'ё' for ch in norm):
            lat = _to_latin(norm)
            if lat:
                variants.add(lat)
                variants.add(_stem(lat))
                if 'v' in lat:
                    variants.add(lat.replace('v', 'w'))
        elif any('a' <= ch <= 'z' for ch in norm):
            cyr = _to_cyrillic(norm)
            if cyr:
                variants.add(cyr)
                variants.add(_stem(cyr))
            if 'w' in norm:
                variants.add(norm.replace('w', 'v'))
        token_id = norm
        if token_id in seen:
            continue
        seen.add(token_id)
        out.append({
            'word': norm,
            'stem': _stem(norm),
            'variants': [v for v in variants if v and len(v) >= 2],
        })
    return out


def _haystack(lot):
    parts = [
        lot.get('title') or '',
        lot.get('artist') or '',
        lot.get('description') or '',
        lot.get('lot_type') or '',
    ]
    return _normalize_word(' '.join(parts))


def _ngrams(s, n=3):
    s = ' ' + s + ' '
    return {s[i:i + n] for i in range(len(s) - n + 1)}


def _trigram_score(needle, hay):
    if not needle or not hay:
        return 0.0
    a = _ngrams(needle)
    b = _ngrams(hay)
    if not a or not b:
        return 0.0
    inter = len(a & b)
    return inter / max(1, len(a))


def _expanded_query(tokens):
    parts = []
    for t in tokens:
        for v in t['variants']:
            parts.append(v)
    return ' '.join(parts) if parts else ''


def _build_haystacks(lot):
    title = _normalize_word(lot.get('title') or '')
    artist = _normalize_word(lot.get('artist') or '')
    description = _normalize_word(lot.get('description') or '')
    title_lat = _to_latin(title)
    artist_lat = _to_latin(artist)
    desc_lat = _to_latin(description)
    title_cyr = _to_cyrillic(title)
    artist_cyr = _to_cyrillic(artist)
    return {
        'title': title, 'artist': artist, 'description': description,
        'title_alt': '{} {}'.format(title_lat, title_cyr).strip(),
        'artist_alt': '{} {}'.format(artist_lat, artist_cyr).strip(),
        'desc_alt': desc_lat,
    }


def score_lot_rapidfuzz(lot, tokens, raw_query):
    hays = _build_haystacks(lot)
    expanded = _expanded_query(tokens) or _normalize_word(raw_query)
    title_pool = '{} {}'.format(hays['title'], hays['title_alt']).strip()
    artist_pool = '{} {}'.format(hays['artist'], hays['artist_alt']).strip()
    desc_pool = '{} {}'.format(hays['description'], hays['desc_alt']).strip()
    if not (title_pool or artist_pool or desc_pool):
        return 0.0
    title_score = fuzz.token_set_ratio(expanded, title_pool) if title_pool else 0
    artist_score = fuzz.token_set_ratio(expanded, artist_pool) if artist_pool else 0
    desc_score = fuzz.partial_ratio(expanded, desc_pool) if desc_pool else 0
    matched = 0
    bonus = 0.0
    for token in tokens:
        token_hit = 0
        for v in token['variants']:
            if not v:
                continue
            if v in title_pool:
                token_hit = max(token_hit, 100)
            elif v in artist_pool:
                token_hit = max(token_hit, 80)
            elif v in desc_pool:
                token_hit = max(token_hit, 50)
            else:
                pr = fuzz.partial_ratio(v, title_pool) if title_pool else 0
                if pr >= 85:
                    token_hit = max(token_hit, pr - 10)
        if token_hit > 0:
            matched += 1
            bonus += token_hit * 0.3
    if matched == 0 and max(title_score, artist_score, desc_score) < 60:
        return 0.0
    composite = (title_score * 1.6) + (artist_score * 1.2) + (desc_score * 0.6) + bonus
    if tokens:
        coverage = matched / len(tokens)
        composite *= (0.5 + 0.5 * coverage)
    return composite


def score_lot(lot, tokens):
    if not tokens:
        return 0.0
    title = _normalize_word(lot.get('title') or '')
    artist = _normalize_word(lot.get('artist') or '')
    description = _normalize_word(lot.get('description') or '')
    score = 0.0
    matched_tokens = 0
    for token in tokens:
        token_score = 0.0
        for v in token['variants']:
            if not v:
                continue
            if v in title:
                token_score = max(token_score, 5.0 + (1.0 if title.startswith(v) else 0.0))
            elif v in artist:
                token_score = max(token_score, 4.0)
            elif v in description:
                token_score = max(token_score, 2.0)
            else:
                tg = max(_trigram_score(v, title), _trigram_score(v, artist))
                if tg >= 0.5:
                    token_score = max(token_score, tg * 3.0)
                elif tg >= 0.3:
                    token_score = max(token_score, tg * 1.2)
        if token_score > 0:
            matched_tokens += 1
            score += token_score
    if matched_tokens == 0:
        return 0.0
    coverage = matched_tokens / len(tokens)
    score *= (0.4 + 0.6 * coverage)
    return score


def smart_search(lots, query, limit=60):
    tokens = tokenize(query)
    if not tokens:
        return []
    scored = []
    if _HAS_RAPIDFUZZ:
        for lot in lots:
            s = score_lot_rapidfuzz(lot, tokens, query)
            if s > 0:
                scored.append((s, lot))
    else:
        for lot in lots:
            s = score_lot(lot, tokens)
            if s > 0:
                scored.append((s, lot))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [lot for _s, lot in scored[:limit]]
