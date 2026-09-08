"""Pull candidate news from external sources into the review queue.

Nothing here publishes anything. Every fetched post lands as a *pending*
``ScrapedItem`` for a human to approve or reject in the admin.

Two adapters:
  * ``x``   — a public X/Twitter account, read through gallery-dl's guest
              token (no login, no cookies, no API key).
  * ``rss`` — an RSS or Atom feed, parsed with the stdlib.
"""

import hashlib
import json
import logging
import os
import re
import subprocess
import tempfile
from datetime import datetime, timedelta, timezone as dt_timezone
from urllib.parse import quote, urlparse
from xml.etree import ElementTree

import requests
from django.core.files.base import ContentFile
from django.db import IntegrityError
from django.utils import timezone

from .models import ScrapedItem

logger = logging.getLogger(__name__)

# gallery-dl emits one row per media file, so this caps files, not posts.
# Measured against a real account: 400 files ≈ 100 posts.
MAX_MEDIA_ITEMS = 400
IMAGE_EXTENSIONS = ('jpg', 'jpeg', 'png', 'webp')
VIDEO_EXTENSIONS = ('mp4', 'm3u8', 'mov')
FETCH_TIMEOUT = 240
IMAGE_TIMEOUT = 20
MAX_IMAGE_BYTES = 10 * 1024 * 1024


class ScrapeError(Exception):
    """A source could not be fetched; the message is shown to the admin."""


# Cached temp jar, keyed by a hash of its contents so an admin pasting a new
# session takes effect immediately instead of serving a stale file.
_COOKIE_TMP = None
_COOKIE_KEY = None


def _cookie_blob():
    """The raw cookies.txt text, from the admin portal or the environment."""
    try:
        from .models import AppSettings
        blob = (AppSettings.load().x_cookies or '').strip()
        if blob:
            return blob
    except Exception as exc:
        # Never let a DB hiccup take the scraper down; fall through to env.
        logger.warning('scraper: could not read X cookies from settings: %s', exc)
    return os.environ.get('X_COOKIES', '').strip()


def x_cookies_path():
    """Path to a Netscape cookies.txt for X, or '' when none is configured.

    Preference order:

    * ``X_COOKIES_FILE`` — a path on disk. Handy for local runs.
    * the **admin portal** field, else the ``X_COOKIES`` env var — the file's
      *contents*, written to a private temp file. Our host has no persistent
      disk, so an uploaded file would not survive a deploy; storing the text
      lets the session be replaced from the admin without one.

    Reading a public account needs a logged-in session, not ownership of the
    account being read, so a throwaway X account is the right thing to use.
    """
    global _COOKIE_TMP, _COOKIE_KEY

    path = os.environ.get('X_COOKIES_FILE', '').strip()
    if path:
        if os.path.exists(path):
            return path
        logger.warning('scraper: X_COOKIES_FILE=%s does not exist; ignoring.', path)

    blob = _cookie_blob()
    if not blob:
        return ''

    key = hashlib.sha256(blob.encode('utf-8')).hexdigest()
    if _COOKIE_TMP and _COOKIE_KEY == key and os.path.exists(_COOKIE_TMP):
        return _COOKIE_TMP

    # Netscape format is tab-separated. Pasted or env-carried jars routinely
    # arrive with those tabs and newlines backslash-escaped, which silently
    # yields an unusable jar, so undo that before writing.
    text = blob.replace('\\t', '\t').replace('\\n', '\n')
    if not text.endswith('\n'):
        text += '\n'
    fd, _COOKIE_TMP = tempfile.mkstemp(prefix='x_cookies_', suffix='.txt')
    try:
        os.write(fd, text.encode('utf-8'))
    finally:
        os.close(fd)
    os.chmod(_COOKIE_TMP, 0o600)  # session token — keep it off other users' eyes
    _COOKIE_KEY = key
    return _COOKIE_TMP


# ─────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────

def _aware(dt):
    """Normalise a naive datetime to UTC so comparisons never explode."""
    if dt is None:
        return None
    if timezone.is_naive(dt):
        return timezone.make_aware(dt, dt_timezone.utc)
    return dt


def _title_from(text, fallback):
    """Derive a headline from a post body.

    Splitting on the first full stop is tempting but wrong here: diplomatic
    copy is full of abbreviations ("H.E.", "Amb.", "Dr.") and would yield
    two-character titles. Take the first line instead, and only trim on a
    sentence boundary once we are past a sensible minimum length.
    """
    text = (text or '').strip()
    if not text:
        return fallback
    text = re.sub(r'https?://\S+', '', text).strip()
    text = re.sub(r'\s+', ' ', text.split('\n')[0]).strip() or text
    if not text:
        return fallback
    if len(text) <= 200:
        return text
    # Prefer a sentence end, else a word boundary, within the limit.
    window = text[:200]
    cut = max(window.rfind('. '), window.rfind('! '), window.rfind('? '))
    if cut < 60:
        cut = window.rfind(' ')
    return (window[:cut].rstrip(' .,;:') if cut > 0 else window).rstrip() + '…'


def _download_image(url):
    """Fetch a remote image, refusing anything oversized or non-image."""
    if not url:
        return None
    try:
        resp = requests.get(url, timeout=IMAGE_TIMEOUT, stream=True)
        resp.raise_for_status()
        ctype = resp.headers.get('Content-Type', '')
        if not ctype.startswith('image/'):
            return None
        length = resp.headers.get('Content-Length')
        if length and int(length) > MAX_IMAGE_BYTES:
            return None
        data = b''
        for chunk in resp.iter_content(65536):
            data += chunk
            if len(data) > MAX_IMAGE_BYTES:
                return None
        name = (urlparse(url).path.rsplit('/', 1)[-1] or 'image.jpg')[:80]
        if '.' not in name:
            name += '.jpg'
        return name, data
    except Exception as exc:
        logger.warning('scraper: image download failed for %s: %s', url, exc)
        return None


# ─────────────────────────────────────────────────────────────
#  Adapters — each yields dicts, newest first
# ─────────────────────────────────────────────────────────────

def _fetch_x(handle, date_from, date_to):
    """Read an X account through gallery-dl.

    Two routes, because X gates them differently:

    * With ``X_COOKIES_FILE`` set — the *search* route, which honours
      ``since:``/``until:`` server-side. Chronological, date-bounded and
      complete: this is the one to use for a scheduled daily fetch.
    * Without cookies — the public *timeline* route, readable with a guest
      token (free, no login). Verified working, but X hands a guest only a
      shallow, unordered slice of the account: roughly a hundred posts, and
      in practice nothing recent. Fine for a one-off backfill, not enough to
      catch yesterday's post — hence the warning the admin sees.
    """
    handle = handle.strip().lstrip('@')
    cookies_file = x_cookies_path()

    if cookies_file:
        # since: is inclusive, until: is exclusive — push it a day out so the
        # last day of the admin's range is actually covered.
        query = (
            f'from:{handle} '
            f'since:{date_from.date().isoformat()} '
            f'until:{(date_to.date() + timedelta(days=1)).isoformat()}'
        )
        url = f'https://x.com/search?q={quote(query)}&f=live'
    else:
        url = f'https://x.com/{handle}/timeline'

    cmd = [
        'gallery-dl', '--no-download', '--dump-json',
        '--range', f'1-{MAX_MEDIA_ITEMS}', url,
    ]
    if cookies_file:
        cmd[1:1] = ['--cookies', cookies_file]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=FETCH_TIMEOUT)
    except FileNotFoundError:
        raise ScrapeError(
            'gallery-dl is not installed on this server. Install it with '
            '`pip install gallery-dl`, or run the fetch locally.'
        )
    except subprocess.TimeoutExpired:
        raise ScrapeError(f'X did not respond within {FETCH_TIMEOUT}s — try a narrower date range.')

    if not proc.stdout.strip():
        raise ScrapeError(
            'X returned nothing. The account may be private or renamed, or X may be '
            f'rate-limiting this server. gallery-dl said: {proc.stderr.strip()[:300] or "(no output)"}'
        )

    try:
        rows = json.loads(proc.stdout)
    except json.JSONDecodeError:
        raise ScrapeError('Could not parse the response from gallery-dl.')

    # gallery-dl reports failures as a row of [-1, {"error": ...}].
    for row in rows:
        if isinstance(row, list) and row and row[0] == -1 and isinstance(row[-1], dict):
            err = row[-1].get('error', '')
            if err == 'AuthRequired':
                raise ScrapeError(
                    'X refused this request without a login. Export a cookies.txt '
                    'from a browser signed in to any X account — it does not have to '
                    'be the account being read — and set X_COOKIES_FILE to its path '
                    'on the server. That also switches this source to the '
                    'date-bounded search route, which is the only one that reliably '
                    'returns recent posts. RSS sources need none of this.'
                )
            raise ScrapeError(f'X refused the request: {err or row[-1]}')

    # gallery-dl emits one row per *media file*, and a third of this account's
    # posts carry more than one, so collect them all rather than the first.
    posts = {}
    for row in rows:
        if not (isinstance(row, list) and len(row) >= 3 and isinstance(row[2], dict)):
            continue
        meta = row[2]
        tweet_id = str(meta.get('tweet_id') or meta.get('conversation_id') or '')
        if not tweet_id:
            continue
        bundle = posts.setdefault(tweet_id, {'meta': meta, 'media': []})
        # row[1] is the media URL on file rows.
        url = row[1] if isinstance(row[1], str) else ''
        if not url.startswith('http'):
            continue
        ext = (meta.get('extension') or '').lower()
        kind = 'image' if ext in IMAGE_EXTENSIONS else 'video' if ext in VIDEO_EXTENSIONS else None
        if kind and not any(m['url'] == url for m in bundle['media']):
            bundle['media'].append({'type': kind, 'url': url})

    for tweet_id, bundle in posts.items():
        meta = bundle['meta']
        raw_date = meta.get('date')
        published = None
        if isinstance(raw_date, str):
            for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S'):
                try:
                    published = datetime.strptime(raw_date[:19], fmt)
                    break
                except ValueError:
                    continue
        published = _aware(published)
        if published is None:
            continue
        if published < date_from or published > date_to:
            continue

        text = meta.get('content') or ''
        author = (meta.get('author') or {}).get('nick') or handle
        media = bundle['media']
        # The first image is the article's header; the rest become a gallery.
        hero = next((m['url'] for m in media if m['type'] == 'image'), '')
        yield {
            'external_id': tweet_id,
            'title': _title_from(text, f'Post by @{handle}'),
            'content': text,
            'media': media,
            'image_url': hero,
            'source_url': f'https://x.com/{handle}/status/{tweet_id}',
            'published_at': published,
            'raw': {
                'author': author,
                'media': media,
                'hashtags': meta.get('hashtags') or [],
                'favorite_count': meta.get('favorite_count'),
                'retweet_count': meta.get('retweet_count'),
                'lang': meta.get('lang'),
            },
        }


_RSS_DATE_FORMATS = (
    '%a, %d %b %Y %H:%M:%S %z',
    '%a, %d %b %Y %H:%M:%S %Z',
    '%Y-%m-%dT%H:%M:%S%z',
    '%Y-%m-%dT%H:%M:%SZ',
    '%Y-%m-%d %H:%M:%S',
    '%Y-%m-%d',
)


def _parse_feed_date(value):
    if not value:
        return None
    value = value.strip().replace('GMT', '+0000')
    for fmt in _RSS_DATE_FORMATS:
        try:
            return _aware(datetime.strptime(value, fmt))
        except ValueError:
            continue
    return None


def _tag(el):
    """Strip the namespace from an element tag."""
    return el.tag.rsplit('}', 1)[-1]


def _find_text(entry, *names):
    for child in entry:
        if _tag(child) in names and (child.text or '').strip():
            return child.text.strip()
    return ''


def _fetch_rss(url, date_from, date_to):
    """Parse an RSS 2.0 or Atom feed with the stdlib."""
    try:
        resp = requests.get(url, timeout=FETCH_TIMEOUT,
                            headers={'User-Agent': 'Be4Africa-NewsBot/1.0'})
        resp.raise_for_status()
    except requests.RequestException as exc:
        raise ScrapeError(f'Could not reach the feed: {exc}')

    try:
        root = ElementTree.fromstring(resp.content)
    except ElementTree.ParseError as exc:
        raise ScrapeError(f'That URL did not return valid RSS/Atom XML ({exc}).')

    entries = [e for e in root.iter() if _tag(e) in ('item', 'entry')]
    if not entries:
        raise ScrapeError('No <item> or <entry> elements found — is this really a feed URL?')

    for entry in entries:
        published = _parse_feed_date(
            _find_text(entry, 'pubDate', 'published', 'updated', 'date')
        )
        if published is None or published < date_from or published > date_to:
            continue

        # Atom puts the permalink in <link href="...">, RSS in <link>text</link>
        link = _find_text(entry, 'link')
        if not link:
            for child in entry:
                if _tag(child) == 'link' and child.get('href'):
                    link = child.get('href')
                    break

        image_url = ''
        for child in entry:
            if _tag(child) in ('enclosure', 'thumbnail', 'content') and child.get('url'):
                image_url = child.get('url')
                break

        body = _find_text(entry, 'description', 'summary', 'content', 'encoded')
        body = re.sub(r'<[^>]+>', '', body).strip()
        if not image_url:
            found = re.search(r'<img[^>]+src="([^"]+)"',
                              _find_text(entry, 'description', 'summary', 'content', 'encoded'))
            if found:
                image_url = found.group(1)

        title = _find_text(entry, 'title') or _title_from(body, 'Untitled')
        guid = _find_text(entry, 'guid', 'id') or link or title

        yield {
            'external_id': guid[:200],
            'title': title[:300],
            'content': body,
            'image_url': image_url,
            'source_url': link,
            'published_at': published,
            'media': [{'type': 'image', 'url': image_url}] if image_url else [],
            'raw': {'feed': url},
        }


ADAPTERS = {'x': _fetch_x, 'rss': _fetch_rss}


# ─────────────────────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────────────────────

def fetch_source(source, date_from, date_to, download_images=True):
    """Pull `source` between two dates into pending ScrapedItems.

    Returns ``(created, skipped)``. Already-seen posts are skipped, so
    re-running over the same range is safe and idempotent.
    """
    adapter = ADAPTERS.get(source.kind)
    if adapter is None:
        raise ScrapeError(f'No adapter for source type "{source.kind}".')

    date_from, date_to = _aware(date_from), _aware(date_to)
    created = skipped = 0

    for post in adapter(source.target, date_from, date_to):
        if ScrapedItem.objects.filter(source=source, external_id=post['external_id']).exists():
            skipped += 1
            continue

        item = ScrapedItem(
            source=source,
            external_id=post['external_id'],
            title=post['title'],
            content=post['content'],
            image_url=post['image_url'],
            source_url=post['source_url'],
            published_at=post['published_at'],
            raw={**post['raw'], 'media': post.get('media') or []},
        )
        if download_images and post['image_url']:
            downloaded = _download_image(post['image_url'])
            if downloaded:
                name, data = downloaded
                item.image.save(name, ContentFile(data), save=False)
        try:
            item.save()
            created += 1
        except IntegrityError:
            # Raced with a concurrent fetch of the same source.
            skipped += 1

    source.last_fetched_at = timezone.now()
    source.save(update_fields=['last_fetched_at'])
    return created, skipped
