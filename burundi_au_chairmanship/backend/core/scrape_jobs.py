"""Run a news fetch in the background and report progress.

Cloudflare gives up on any request after 100s (error 524), and a fetch over a
wide date range takes far longer than that: gallery-dl, then an image download
and a Gemini headline per new post. Its own error page prescribes the fix —
"use status polling of large HTTP processes" — which is what this does. The
admin's button starts a job and returns at once; the page then polls for a
percentage.

State lives in the cache, which in this deployment is the database cache table,
so it is shared between both web instances: the browser can poll whichever
instance the load balancer picks, not just the one that started the job.
"""

import logging
import threading
import uuid

from django.core.cache import cache
from django.db import connection

logger = logging.getLogger(__name__)

KEY = 'scrape_job:{}'
# Long enough to watch a slow fetch, short enough not to litter the table.
TTL = 60 * 60
# A stuck job must not spin forever in a thread nobody is watching.
MAX_RUNTIME = 15 * 60


def new_job():
    job_id = uuid.uuid4().hex
    _write(job_id, {'state': 'starting', 'percent': 0, 'done': 0, 'total': 0,
                    'created': 0, 'skipped': 0, 'errors': [], 'source': ''})
    return job_id


def read(job_id):
    """Current state of a job, or None once it has expired."""
    return cache.get(KEY.format(job_id)) if job_id else None


def _write(job_id, data):
    cache.set(KEY.format(job_id), data, TTL)


def _update(job_id, **fields):
    data = cache.get(KEY.format(job_id)) or {}
    data.update(fields)
    _write(job_id, data)
    return data


def spawn(job_id, sources, start, end):
    """Run the fetch on a background thread. Returns immediately."""
    thread = threading.Thread(
        target=_run, args=(job_id, [s.pk for s in sources], start, end),
        daemon=True, name=f'scrape-{job_id[:8]}',
    )
    thread.start()
    return thread


def _run(job_id, source_ids, start, end):
    """Thread body: fetch each source, recording progress as it goes."""
    from .models import NewsSource
    from .news_scraper import fetch_source, ScrapeError

    created = skipped = 0
    errors, truncated = [], False
    try:
        sources = list(NewsSource.objects.filter(pk__in=source_ids))
        for index, source in enumerate(sources):
            base = created, skipped

            def report(done, total, made, seen, _s=source, _b=base, _i=index):
                # Weight each source's share of the overall bar equally.
                share = (done / total) if total else 1
                _update(job_id,
                        state='running',
                        source=_s.name,
                        percent=int(((_i + share) / len(sources)) * 100),
                        done=done, total=total,
                        created=_b[0] + made, skipped=_b[1] + seen)

            try:
                made, seen, cut = fetch_source(
                    source, start, end, time_budget=MAX_RUNTIME, progress=report)
                created += made
                skipped += seen
                truncated = truncated or cut
            except ScrapeError as exc:
                # One dead source must not abandon the ones behind it.
                errors.append(f'{source.name}: {exc}')
                logger.warning('scrape job %s: %s failed: %s', job_id, source.name, exc)

        _update(job_id, state='done', percent=100, created=created,
                skipped=skipped, errors=errors, truncated=truncated)
    except Exception as exc:
        logger.exception('scrape job %s crashed', job_id)
        _update(job_id, state='failed', errors=errors + [str(exc)])
    finally:
        # A spawned thread gets its own connection and must hand it back, or it
        # leaks. Only ever close our own: called on the main thread (tests, or a
        # synchronous run) this would otherwise shut the caller's connection.
        if threading.current_thread() is not threading.main_thread():
            connection.close()
