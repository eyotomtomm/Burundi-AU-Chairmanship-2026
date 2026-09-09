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
import time
import uuid

from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.utils.dateparse import parse_datetime

logger = logging.getLogger(__name__)

KEY = 'scrape_job:{}'
# Long enough to watch a slow fetch, short enough not to litter the table.
TTL = 60 * 60
# A stuck job must not spin forever in a thread nobody is watching.
MAX_RUNTIME = 15 * 60
# Longest a live run can go without writing an update: gallery-dl's own
# timeout, plus an image download and a headline for the post after it. Past
# this the process holding the job is gone, and the bar would otherwise spin
# for ever.
STALE = 6 * 60


def new_job():
    job_id = uuid.uuid4().hex
    _write(job_id, {'state': 'starting', 'percent': 0, 'done': 0, 'total': 0,
                    'created': 0, 'skipped': 0, 'errors': [], 'source': ''})
    return job_id


def read(job_id):
    """Current state of a job, or None once it has expired.

    A job whose process died — a recycled web worker, a worker that never
    picked the task up — stops being written to and would otherwise leave the
    page saying "Fetching…" for ever. Report it as failed once it goes quiet.
    """
    data = cache.get(KEY.format(job_id)) if job_id else None
    if not data:
        return data
    if (data.get('state') in ('starting', 'running')
            and time.time() - data.get('updated', 0) > STALE):
        data['state'] = 'failed'
        data['errors'] = (data.get('errors') or []) + [
            'The fetch stopped without finishing — the process running it was '
            'restarted, or the background worker never picked it up. Press '
            'Fetch again; anything already saved was kept.'
        ]
        _write(job_id, data)
    return data


def _write(job_id, data):
    data['updated'] = time.time()
    cache.set(KEY.format(job_id), data, TTL)


def _update(job_id, **fields):
    data = cache.get(KEY.format(job_id)) or {}
    data.update(fields)
    _write(job_id, data)
    return data


def spawn(job_id, sources, start, end):
    """Run the fetch outside this request. Returns immediately.

    A fetch takes minutes, and the web process is the wrong place for that:
    gunicorn recycles a worker every few hundred requests, which silently
    kills any thread still running in it — the job then never reports again.
    The Celery worker already runs this exact fetch on a schedule and has no
    such recycle, so hand it over there. A thread is kept for local runs,
    where tasks execute inline and there is no worker to hand to.
    """
    ids = [s.pk for s in sources]
    if not getattr(settings, 'CELERY_TASK_ALWAYS_EAGER', False):
        from .tasks import run_scrape_job
        run_scrape_job.delay(job_id, ids, start.isoformat(), end.isoformat())
        return None

    thread = threading.Thread(
        target=_run, args=(job_id, ids, start, end),
        daemon=True, name=f'scrape-{job_id[:8]}',
    )
    thread.start()
    return thread


def _run(job_id, source_ids, start, end):
    """Thread body: fetch each source, recording progress as it goes."""
    from .models import NewsSource
    from .news_scraper import fetch_source, ScrapeError

    # Celery carries the range as ISO strings; a thread passes datetimes.
    start = parse_datetime(start) if isinstance(start, str) else start
    end = parse_datetime(end) if isinstance(end, str) else end

    created = skipped = 0
    errors, truncated = [], False
    try:
        sources = list(NewsSource.objects.filter(pk__in=source_ids))
        for index, source in enumerate(sources):
            base = created, skipped
            # Reading the source is the slow part and reports nothing while it
            # runs, so name it up front rather than leave the page blank for
            # minutes with no sign the run is alive.
            _update(job_id, state='running', source=source.name,
                    percent=int((index / len(sources)) * 100))

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
