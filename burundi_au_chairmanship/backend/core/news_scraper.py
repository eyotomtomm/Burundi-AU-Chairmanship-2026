"""Pull candidate news from external sources into the review queue.

Nothing here publishes anything. Every fetched post lands as a *pending*
``ScrapedItem`` for a human to approve or reject in the admin.

Two adapters:
  * ``x``   — a public X/Twitter account, read through gallery-dl's guest
              token (no login, no cookies, no API key).
  * ``rss`` — an RSS or Atom feed, parsed with the stdlib.
"""

import json
import logging
import re
import subprocess
from datetime import datetime, timezone as dt_timezone
from urllib.parse import urlparse
from xml.etree import ElementTree

import requests
from django.core.files.base import ContentFile
from django.db import IntegrityError
from django.utils import timezone

from .models import ScrapedItem

logger = logging.getLogger(__name__)

# gallery-dl walks the timeline newest-first. We stop paging once we're past
# the window, but cap the walk so an old date range can't run forever.
MAX_MEDIA_ITEMS = 400
FETCH_TIMEOUT = 240
IMAGE_TIMEOUT = 20
MAX_IMAGE_BYTES = 10 * 1024 * 1024


class ScrapeError(Exception):
    """A source could not be fetched; the message is shown to the admin."""


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
    """Read a public X timeline via gallery-dl's guest token."""
    handle = handle.strip().lstrip('@')
    url = f'https://x.com/{handle}/timeline'
    cmd = [
        'gallery-dl', '--no-download', '--dump-json',
        '--range', f'1-{MAX_MEDIA_ITEMS}', url,
    ]
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

    # gallery-dl emits one row per *media file*; several can share a tweet.
    posts = {}
    for row in rows:
        if not (isinstance(row, list) and len(row) >= 3 and isinstance(row[2], dict)):
            continue
        meta = row[2]
        tweet_id = str(meta.get('tweet_id') or meta.get('conversation_id') or '')
        if not tweet_id:
            continue
        if tweet_id not in posts:
            posts[tweet_id] = {'meta': meta, 'image_url': None}
        # row[1] is the media URL for file rows
        if posts[tweet_id]['image_url'] is None and isinstance(row[1], str) and row[1].startswith('http'):
            if meta.get('extension') in ('jpg', 'jpeg', 'png', 'webp'):
                posts[tweet_id]['image_url'] = row[1]

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
        yield {
            'external_id': tweet_id,
            'title': _title_from(text, f'Post by @{handle}'),
            'content': text,
            'image_url': bundle['image_url'] or '',
            'source_url': f'https://x.com/{handle}/status/{tweet_id}',
            'published_at': published,
            'raw': {
                'author': author,
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
            raw=post['raw'],
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
