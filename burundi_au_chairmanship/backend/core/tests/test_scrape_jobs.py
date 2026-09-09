"""The admin's Fetch must return immediately and report progress, because
Cloudflare abandons any request that takes longer than 100 seconds."""
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from core import scrape_jobs
from core.models import NewsSource, ScrapedItem
from custom_admin.tests import login_with_2fa


class ScrapeJobStateTests(TestCase):
    def setUp(self):
        cache.clear()
        self.source = NewsSource.objects.create(
            name='Ours', kind='x', target='BurundinAddis', is_active=True,
        )

    def test_a_run_reports_progress_and_finishes(self):
        def fake_fetch(source, start, end, time_budget=None, progress=None):
            progress(0, 2, 0, 0)
            progress(1, 2, 1, 0)
            progress(2, 2, 2, 0)
            return 2, 0, False

        job = scrape_jobs.new_job()
        self.assertEqual(scrape_jobs.read(job)['state'], 'starting')
        with patch('core.news_scraper.fetch_source', side_effect=fake_fetch):
            scrape_jobs._run(job, [self.source.pk], timezone.now(), timezone.now())
        state = scrape_jobs.read(job)
        self.assertEqual(state['state'], 'done')
        self.assertEqual(state['percent'], 100)
        self.assertEqual(state['created'], 2)

    def test_a_job_whose_process_died_is_reported_failed(self):
        """A recycled web worker takes its threads with it. Say so, don't spin."""
        job = scrape_jobs.new_job()
        state = cache.get(scrape_jobs.KEY.format(job))
        state['updated'] = state['updated'] - scrape_jobs.STALE - 1
        cache.set(scrape_jobs.KEY.format(job), state, scrape_jobs.TTL)
        self.assertEqual(scrape_jobs.read(job)['state'], 'failed')

    def test_a_finished_job_is_never_called_stale(self):
        job = scrape_jobs.new_job()
        scrape_jobs._update(job, state='done', percent=100)
        state = cache.get(scrape_jobs.KEY.format(job))
        state['updated'] = 0
        cache.set(scrape_jobs.KEY.format(job), state, scrape_jobs.TTL)
        self.assertEqual(scrape_jobs.read(job)['state'], 'done')

    def test_spawn_hands_the_work_to_the_celery_worker(self):
        """The web process recycles its workers; the fetch must not live there."""
        job = scrape_jobs.new_job()
        start, end = timezone.now() - timedelta(days=1), timezone.now()
        with self.settings(CELERY_TASK_ALWAYS_EAGER=False), \
                patch('core.tasks.run_scrape_job.delay') as delay:
            scrape_jobs.spawn(job, [self.source], start, end)
        delay.assert_called_once_with(job, [self.source.pk],
                                      start.isoformat(), end.isoformat())

    def test_an_unreachable_broker_falls_back_to_a_thread(self):
        """Fetch must still run when the queue is down, not 500."""
        job = scrape_jobs.new_job()
        with self.settings(CELERY_TASK_ALWAYS_EAGER=False), \
                patch('core.tasks.run_scrape_job.delay',
                      side_effect=OSError('broker is down')), \
                patch('core.scrape_jobs._run') as run:
            thread = scrape_jobs.spawn(job, [self.source],
                                       timezone.now(), timezone.now())
        thread.join(timeout=5)
        run.assert_called_once()

    def test_the_worker_gets_the_range_back_as_datetimes(self):
        seen = {}

        def fake_fetch(source, start, end, time_budget=None, progress=None):
            seen['start'], seen['end'] = start, end
            return 0, 0, False

        job = scrape_jobs.new_job()
        start, end = timezone.now() - timedelta(days=1), timezone.now()
        with patch('core.news_scraper.fetch_source', side_effect=fake_fetch):
            scrape_jobs._run(job, [self.source.pk], start.isoformat(), end.isoformat())
        self.assertEqual(seen['start'], start)
        self.assertEqual(seen['end'], end)

    def test_one_dead_source_does_not_abandon_the_others(self):
        from core.news_scraper import ScrapeError
        other = NewsSource.objects.create(
            name='Broken', kind='rss', target='https://nope/rss', is_active=True,
        )
        calls = []

        def fake_fetch(source, start, end, time_budget=None, progress=None):
            calls.append(source.name)
            if source.name == 'Broken':
                raise ScrapeError('feed is down')
            return 1, 0, False

        job = scrape_jobs.new_job()
        with patch('core.news_scraper.fetch_source', side_effect=fake_fetch):
            scrape_jobs._run(job, [self.source.pk, other.pk],
                             timezone.now(), timezone.now())
        state = scrape_jobs.read(job)
        self.assertEqual(len(calls), 2)
        self.assertEqual(state['state'], 'done')
        self.assertEqual(state['created'], 1)
        self.assertTrue(any('feed is down' in e for e in state['errors']))

    def test_a_crash_is_recorded_not_swallowed(self):
        job = scrape_jobs.new_job()
        with patch('core.news_scraper.fetch_source', side_effect=RuntimeError('boom')):
            scrape_jobs._run(job, [self.source.pk], timezone.now(), timezone.now())
        state = scrape_jobs.read(job)
        self.assertEqual(state['state'], 'failed')
        self.assertTrue(any('boom' in e for e in state['errors']))

    def test_unknown_job_reads_as_none(self):
        self.assertIsNone(scrape_jobs.read('does-not-exist'))


class FetchEndpointTests(TestCase):
    def setUp(self):
        cache.clear()
        self.admin = get_user_model().objects.create_superuser(
            'fetcher', 'f@example.com', 'pw')
        login_with_2fa(self.client, self.admin)
        self.source = NewsSource.objects.create(
            name='Ours', kind='x', target='BurundinAddis', is_active=True,
        )

    def test_fetch_returns_at_once_and_hands_back_a_job(self):
        spawned = {}

        def fake_spawn(job_id, sources, start, end):
            spawned['job'] = job_id
            spawned['sources'] = [s.name for s in sources]

        with patch('core.scrape_jobs.spawn', side_effect=fake_spawn):
            res = self.client.post(reverse('custom_admin:news_scraper'), {
                'action': 'fetch', 'source_ids': [self.source.pk],
            })
        self.assertEqual(res.status_code, 302)
        self.assertIn(f"job={spawned['job']}", res['Location'])
        self.assertEqual(spawned['sources'], ['Ours'])
        # Nothing was fetched inline — that is the whole point.
        self.assertEqual(ScrapedItem.objects.count(), 0)

    def test_progress_endpoint_reports_the_job(self):
        job = scrape_jobs.new_job()
        scrape_jobs._update(job, state='running', percent=42, created=3)
        res = self.client.get(reverse('custom_admin:news_scraper_progress'),
                              {'job': job})
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body['state'], 'running')
        self.assertEqual(body['percent'], 42)
        self.assertEqual(body['created'], 3)

    def test_progress_endpoint_on_an_expired_job(self):
        res = self.client.get(reverse('custom_admin:news_scraper_progress'),
                              {'job': 'gone'})
        self.assertEqual(res.json()['state'], 'unknown')

    def test_progress_endpoint_requires_staff(self):
        self.client.logout()
        res = self.client.get(reverse('custom_admin:news_scraper_progress'),
                              {'job': 'x'})
        self.assertIn(res.status_code, (302, 403))
