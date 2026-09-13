"""EN <-> FR translation over free endpoints, no API key.

Lifted out of custom_admin.views.auto_translate so the admin's button and
the translate_articles command share one implementation: three providers
tried in order, long text split on sentence boundaries.
"""
import json
import re
import urllib.parse
import urllib.request

# Providers answer in wildly different shapes, so each one parses its own.
# Google's gtx endpoint is first because it is the only one that reports the
# language it detected, which is how a post's own language is read.
_UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
_TIMEOUT = 8
# MyMemory rejects anything longer; the other two are happier with short text
# anyway, and a sentence boundary keeps the split from cutting mid-clause.
CHUNK = 450


def _get(url):
    req = urllib.request.Request(url)
    req.add_header('User-Agent', _UA)
    with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
        return json.loads(resp.read())


def _gtx(chunk, sl, tl):
    """Returns (translation, detected source language)."""
    data = _get('https://translate.googleapis.com/translate_a/single'
                f'?client=gtx&sl={sl}&tl={tl}&dt=t&q={urllib.parse.quote(chunk)}')
    if data and data[0]:
        out = ''.join(seg[0] for seg in data[0] if seg and seg[0])
        if out.strip():
            detected = data[2] if len(data) > 2 and isinstance(data[2], str) else None
            return out, detected
    return None, None


def _lingva(chunk, sl, tl):
    data = _get(f'https://lingva.ml/api/v1/{sl}/{tl}/{urllib.parse.quote(chunk)}')
    out = data.get('translation', '')
    return (out, None) if out.strip() else (None, None)


def _mymemory(chunk, sl, tl):
    data = _get('https://api.mymemory.translated.net/get'
                f'?q={urllib.parse.quote(chunk)}&langpair={sl}|{tl}')
    out = data.get('responseData', {}).get('translatedText', '')
    if out.strip():
        return out, None
    for match in data.get('matches', []):
        if (match.get('translation') or '').strip():
            return match['translation'], None
    return None, None


def translate_chunk(chunk, source, target):
    """One short piece of text, through whichever provider answers first."""
    for provider in (_gtx, _lingva, _mymemory):
        try:
            out, _ = provider(chunk, source, target)
        except Exception:
            continue
        if out:
            return out
    return None


def split_text(text, limit=CHUNK):
    """Text in pieces a provider will accept, cut on sentence boundaries."""
    chunks = []
    remaining = text
    while remaining:
        if len(remaining) <= limit:
            chunks.append(remaining)
            break
        cut = limit
        for sep in ('. ', '.\n', '! ', '? ', '\n'):
            pos = remaining[:cut].rfind(sep)
            if pos > 100:
                cut = pos + len(sep)
                break
        chunks.append(remaining[:cut])
        remaining = remaining[cut:]
    return chunks


def translate_text(text, source, target):
    """The whole text, or None if any part of it could not be translated.

    Partial output would be worse than none: half an article in French and
    half in English reads as a bug to whoever opens it.
    """
    parts = []
    for chunk in split_text(text):
        out = translate_chunk(chunk, source, target)
        if not out:
            return None
        parts.append(out)
    return ''.join(parts)


def detect_language(text):
    """'en', 'fr' or None — what language a post was written in.

    Asks for a translation of the opening line and keeps only the language
    the provider reports having read, which costs no extra request.
    """
    sample = text.strip()[:200]
    if not sample:
        return None
    try:
        _, detected = _gtx(sample, 'auto', 'en')
    except Exception:
        return None
    return detected


# A headline is short, and a provider guessing from a dozen words calls
# English "rw" often enough to matter. These settle it without a request.
ETHIOPIC = re.compile(r'[\u1200-\u137F]')
FRENCH_MARKERS = re.compile(
    r'\b(?:le|la|les|des|du|dans|avec|pour|est|une|aux|cette|sur|par|nous|'
    r'leur|son|ses|qui|que|ainsi|lors|entre|sont|\u00e0)\b', re.I)


def guess_language(text):
    """'en', 'fr', or None for a post written in neither."""
    if ETHIOPIC.search(text):
        return None
    detected = detect_language(text)
    if detected in ('en', 'fr'):
        return detected
    # The provider read something else out of a short headline. The account
    # writes in two languages, so the question is only which of the two.
    return 'fr' if len(FRENCH_MARKERS.findall(text)) >= 2 else 'en'
