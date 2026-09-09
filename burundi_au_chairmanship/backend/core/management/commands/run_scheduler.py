"""Run the periodic jobs on a clock, without Celery's broker.

Celery needs a broker (Redis) to queue work. With no broker configured Django
sets ``CELERY_TASK_ALWAYS_EAGER``, which turns every task into an ordinary
function that runs when called — so the queue is not what we are missing, only
something to call the jobs on time. That is all this does.

Schedules come from ``CELERY_BEAT_SCHEDULE`` so there is still exactly one
place that defines them; switching to real Celery later means running
``celery -A config worker -B`` instead of this, and changing nothing else.

Trade-off against real Celery: no retries, and a slow job delays the ones
behind it. Acceptable here because every job is written as "find the rows that
are due and process them", so a late or missed tick self-heals on the next one.

Last-run times live in the cache (the database cache table, created by
migration 0181) so a restart does not re-fire a weekly job.
"""

import logging
import signal
import time

from django.conf import settings
from django.core.cache import cache
from django.core.management.base import BaseCommand
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)

# The finest schedule in use is 60s; checking four times a minute keeps jobs
# punctual without hammering the cache table.
TICK_SECONDS = 15
CACHE_KEY = 'scheduler:last_run:{}'
# Never expire: a weekly job must keep its cadence across restarts.
FOREVER = None


class Command(BaseCommand):
    help = 'Run CELERY_BEAT_SCHEDULE jobs on a timer, without a broker.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--once', action='store_true',
            help='Run a single pass and exit, instead of looping. For tests.',
        )

    def handle(self, *args, **options):
        jobs = self._load_jobs()
        if not jobs:
            self.stderr.write('No usable entries in CELERY_BEAT_SCHEDULE; nothing to run.')
            return

        self.stdout.write(f'Scheduler starting with {len(jobs)} job(s):')
        for name, (_, interval) in sorted(jobs.items()):
            self.stdout.write(f'  {name} every {interval}s')

        if options['once']:
            self._pass(jobs)
            return

        # DigitalOcean sends SIGTERM on deploy; finish the tick, then exit 0.
        stopping = {'now': False}

        def _stop(signum, frame):
            self.stdout.write('Shutdown signal received; stopping after this tick.')
            stopping['now'] = True

        signal.signal(signal.SIGTERM, _stop)
        signal.signal(signal.SIGINT, _stop)

        while not stopping['now']:
            self._pass(jobs)
            # Sleep in short slices so a shutdown signal is not ignored for
            # a whole tick.
            for _ in range(TICK_SECONDS):
                if stopping['now']:
                    break
                time.sleep(1)
        self.stdout.write('Scheduler stopped.')

    def _load_jobs(self):
        """Resolve each schedule entry to (callable, interval_seconds)."""
        jobs = {}
        for name, cfg in getattr(settings, 'CELERY_BEAT_SCHEDULE', {}).items():
            interval = cfg.get('schedule')
            if not isinstance(interval, (int, float)):
                # A crontab()/solar schedule needs Celery proper to interpret.
                logger.warning('scheduler: skipping %s — non-numeric schedule %r',
                               name, interval)
                continue
            try:
                jobs[name] = (import_string(cfg['task']), int(interval))
            except (ImportError, KeyError) as exc:
                logger.warning('scheduler: skipping %s — %s', name, exc)
        return jobs

    def _pass(self, jobs):
        """One sweep: run whatever is due."""
        now = time.time()
        for name, (func, interval) in jobs.items():
            key = CACHE_KEY.format(name)
            last = cache.get(key)

            if last is None:
                # First sight of this job. Start its clock rather than firing
                # immediately, so a redeploy cannot stampede every job at once.
                cache.set(key, now, FOREVER)
                continue

            if now - last < interval:
                continue

            # Stamp before running, not after: if the job raises every time, we
            # must not retry it on every tick.
            cache.set(key, now, FOREVER)
            try:
                func()
                logger.info('scheduler: ran %s', name)
            except Exception:
                # One broken job must never stop the others.
                logger.exception('scheduler: %s failed', name)
