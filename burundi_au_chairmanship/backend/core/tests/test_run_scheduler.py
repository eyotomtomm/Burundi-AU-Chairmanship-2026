"""The scheduler replaces Celery beat, so it must fire jobs on time, survive a
job that raises, and not re-fire a weekly job every time the worker restarts."""
import time
from unittest.mock import patch

from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase, override_settings

RAN = []


def _job_a():
    RAN.append('a')


def _job_b():
    RAN.append('b')


def _job_boom():
    RAN.append('boom')
    raise RuntimeError('this job is broken')


SCHEDULE = {
    'job-a': {'task': 'core.tests.test_run_scheduler._job_a', 'schedule': 60},
    'job-b': {'task': 'core.tests.test_run_scheduler._job_b', 'schedule': 3600},
}


@override_settings(CELERY_BEAT_SCHEDULE=SCHEDULE)
class RunSchedulerTests(TestCase):
    def setUp(self):
        RAN.clear()
        cache.clear()

    def _run(self):
        call_command('run_scheduler', '--once', verbosity=0)

    def test_first_pass_starts_the_clock_without_firing(self):
        # Otherwise every redeploy would stampede all ten jobs at once.
        self._run()
        self.assertEqual(RAN, [])
        self.assertIsNotNone(cache.get('scheduler:last_run:job-a'))

    def test_job_fires_once_its_interval_has_passed(self):
        self._run()
        cache.set('scheduler:last_run:job-a', time.time() - 61, None)
        self._run()
        self.assertEqual(RAN, ['a'])

    def test_job_does_not_fire_before_its_interval(self):
        self._run()
        cache.set('scheduler:last_run:job-a', time.time() - 59, None)
        self._run()
        self.assertEqual(RAN, [])

    def test_a_restart_does_not_refire_a_weekly_job(self):
        # The whole point of persisting last-run in the cache.
        self._run()
        cache.set('scheduler:last_run:job-b', time.time() - 100, None)
        self._run()   # a "restart" — the loop starts over, the cache does not
        self._run()
        self.assertEqual(RAN, [])

    def test_a_failing_job_does_not_stop_the_others(self):
        schedule = dict(SCHEDULE)
        schedule['job-boom'] = {
            'task': 'core.tests.test_run_scheduler._job_boom', 'schedule': 60,
        }
        with override_settings(CELERY_BEAT_SCHEDULE=schedule):
            self._run()
            past = time.time() - 61
            cache.set('scheduler:last_run:job-boom', past, None)
            cache.set('scheduler:last_run:job-a', past, None)
            self._run()
        self.assertIn('boom', RAN)
        self.assertIn('a', RAN)

    def test_a_failing_job_is_not_retried_every_tick(self):
        schedule = {'job-boom': {'task': 'core.tests.test_run_scheduler._job_boom',
                                 'schedule': 60}}
        with override_settings(CELERY_BEAT_SCHEDULE=schedule):
            self._run()
            cache.set('scheduler:last_run:job-boom', time.time() - 61, None)
            self._run()
            self._run()
        self.assertEqual(RAN, ['boom'])

    def test_non_numeric_schedules_are_skipped_not_fatal(self):
        schedule = {'cronish': {'task': 'core.tests.test_run_scheduler._job_a',
                                'schedule': object()}}
        with override_settings(CELERY_BEAT_SCHEDULE=schedule):
            self._run()   # must not raise
        self.assertEqual(RAN, [])



class RealScheduleTests(TestCase):
    """No override here — this checks the schedule the app actually ships."""

    def test_every_scheduled_task_can_be_imported(self):
        """Guards against a typo'd dotted path in CELERY_BEAT_SCHEDULE."""
        from django.conf import settings
        from django.utils.module_loading import import_string
        schedule = settings.CELERY_BEAT_SCHEDULE
        self.assertTrue(schedule, 'no beat schedule configured')
        for name, cfg in schedule.items():
            with self.subTest(job=name):
                self.assertTrue(callable(import_string(cfg['task'])))

    def test_the_news_fetch_is_scheduled(self):
        from django.conf import settings
        tasks = {c['task'] for c in settings.CELERY_BEAT_SCHEDULE.values()}
        self.assertIn('core.tasks.auto_fetch_news_sources', tasks)
