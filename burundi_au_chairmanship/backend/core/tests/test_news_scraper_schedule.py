"""The daily auto-fetch fires once per source per day, and a reviewer's
edits — not the scraped text — are what gets published."""
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from core.models import NewsSource, ScrapedItem
from core.tasks import auto_fetch_news_sources
from custom_admin.tests import login_with_2fa


class AutoFetchScheduleTests(TestCase):
    def setUp(self):
        self.hour = timezone.localtime().hour
        self.source = NewsSource.objects.create(
            name='AU', kind='rss', target='https://au.int/rss',
            is_active=True, auto_fetch=True, auto_fetch_hour=self.hour,
            auto_fetch_days=2,
        )

    def _run(self):
        with patch('core.news_scraper.fetch_source', return_value=(3, 0)) as fetch:
            auto_fetch_news_sources()
        return fetch

    def test_fetches_on_its_hour(self):
        fetch = self._run()
        self.assertEqual(fetch.call_count, 1)
        _src, start, end = fetch.call_args[0]
        self.assertAlmostEqual((end - start).days, 2, delta=1)

    def test_skips_other_hours(self):
        self.source.auto_fetch_hour = (self.hour + 5) % 24
        self.source.save()
        self.assertEqual(self._run().call_count, 0)

    def test_skips_when_already_fetched_today(self):
        self.source.last_fetched_at = timezone.now()
        self.source.save()
        self.assertEqual(self._run().call_count, 0)

    def test_skips_manual_and_paused_sources(self):
        self.source.auto_fetch = False
        self.source.save()
        self.assertEqual(self._run().call_count, 0)
        self.source.auto_fetch, self.source.is_active = True, False
        self.source.save()
        self.assertEqual(self._run().call_count, 0)

    def test_one_bad_source_does_not_stop_the_rest(self):
        from core.news_scraper import ScrapeError
        other = NewsSource.objects.create(
            name='Broken', kind='rss', target='https://nope/rss',
            is_active=True, auto_fetch=True, auto_fetch_hour=self.hour,
        )
        with patch('core.news_scraper.fetch_source',
                   side_effect=[ScrapeError('down'), (1, 0)]) as fetch:
            auto_fetch_news_sources()
        self.assertEqual(fetch.call_count, 2)
        del other


class ApproveWithEditsTests(TestCase):
    def setUp(self):
        self.admin = get_user_model().objects.create_superuser(
            'editor', 'e@example.com', 'pw',
        )
        login_with_2fa(self.client, self.admin)
        source = NewsSource.objects.create(
            name='Ours', kind='x', target='BurundinAddis', is_own_content=True,
        )
        self.item = ScrapedItem.objects.create(
            source=source, external_id='1', title='raw title',
            content='raw body', published_at=timezone.now() - timedelta(hours=1),
        )

    def _approve(self, **extra):
        return self.client.post(
            reverse('custom_admin:news_scraper_review'),
            {'decision': 'approve', 'item_ids': [self.item.pk], **extra},
        )

    def test_edited_text_is_what_publishes(self):
        self._approve(**{
            f'title_{self.item.pk}': 'Fixed headline',
            f'content_{self.item.pk}': 'Cleaned up body.',
        })
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, 'approved')
        self.assertEqual(self.item.article.title, 'Fixed headline')
        self.assertEqual(self.item.article.content, 'Cleaned up body.')

    def test_untouched_item_keeps_the_scraped_text(self):
        self._approve()
        self.item.refresh_from_db()
        self.assertEqual(self.item.article.title, 'raw title')
        self.assertEqual(self.item.article.content, 'raw body')


class XRouteTests(TestCase):
    """Cookies decide the route: date-bounded search, or the guest timeline."""

    def _url(self, cookies, env=None):
        import os
        from unittest.mock import patch as _p
        from core.news_scraper import _fetch_x
        env = env if env is not None else ({'X_COOKIES_FILE': cookies} if cookies else {})
        captured = {}

        class _Proc:
            stdout, stderr = '[]', ''

        def _run(cmd, **kw):
            captured['cmd'] = cmd
            return _Proc()

        with _p.dict(os.environ, env, clear=not cookies), \
                _p('core.news_scraper.subprocess.run', _run):
            list(_fetch_x('@BurundinAddis',
                          timezone.now() - timedelta(days=2), timezone.now()))
        return captured['cmd']

    def test_guest_uses_the_public_timeline(self):
        cmd = self._url(None)
        self.assertIn('https://x.com/BurundinAddis/timeline', cmd)
        self.assertNotIn('--cookies', cmd)

    def test_cookies_switch_to_date_bounded_search(self):
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.txt') as jar:
            cmd = self._url(jar.name)
        url = cmd[-1]
        self.assertIn('/search?q=', url)
        self.assertIn('from%3ABurundinAddis', url)
        self.assertIn('since%3A', url)
        self.assertIn('until%3A', url)
        self.assertIn('--cookies', cmd)
        # until: is exclusive, so it must sit a day past the requested end.
        self.assertIn((timezone.now().date() + timedelta(days=1)).isoformat(),
                      url.replace('%3A', ':'))

    def test_env_secret_also_switches_to_search(self):
        import core.news_scraper as ns
        ns._COOKIE_TMP = None
        cmd = self._url(None, env={'X_COOKIES': '.x.com\tTRUE\t/\tauth_token\tsecret'})
        self.assertIn('/search?q=', cmd[-1])
        self.assertIn('--cookies', cmd)


class CookieJarTests(TestCase):
    """The jar can come from a path or, on a diskless host, an env secret."""

    def setUp(self):
        import core.news_scraper as ns
        ns._COOKIE_TMP = None

    def _path(self, **env):
        import os
        from unittest.mock import patch as _p
        from core.news_scraper import x_cookies_path
        with _p.dict(os.environ, env, clear=True):
            return x_cookies_path()

    def test_no_config_means_no_jar(self):
        self.assertEqual(self._path(), '')

    def test_missing_file_is_ignored_not_passed_on(self):
        self.assertEqual(self._path(X_COOKIES_FILE='/nope/cookies.txt'), '')

    def test_env_blob_is_written_to_a_private_file(self):
        import os
        blob = '.x.com\tTRUE\t/\tTRUE\t0\tauth_token\tsecret'
        path = self._path(X_COOKIES=blob)
        self.assertTrue(os.path.exists(path))
        self.assertEqual(oct(os.stat(path).st_mode)[-3:], '600')
        self.assertEqual(open(path).read(), blob + '\n')
        os.unlink(path)

    def test_escaped_tabs_are_restored(self):
        import os
        path = self._path(X_COOKIES='.x.com\\tTRUE\\t/\\tauth_token\\tsecret')
        body = open(path).read()
        self.assertIn('\t', body)
        self.assertNotIn('\\t', body)
        os.unlink(path)
