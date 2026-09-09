"""The daily auto-fetch fires once per source per day, and a reviewer's
edits — not the scraped text — are what gets published."""
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.core.files.base import ContentFile
from django.utils import timezone

from core.models import NewsSource, ScrapedItem
from core.tasks import auto_fetch_news_sources
from custom_admin.tests import login_with_2fa

# Smallest valid PNG, so ImageField validation passes.
_PNG = (b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
        b'\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01'
        b'\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82')


class AutoFetchScheduleTests(TestCase):
    def setUp(self):
        self.hour = timezone.localtime().hour
        self.source = NewsSource.objects.create(
            name='AU', kind='rss', target='https://au.int/rss',
            is_active=True, auto_fetch=True, auto_fetch_hour=self.hour,
            auto_fetch_days=2,
        )

    def _run(self):
        with patch('core.news_scraper.fetch_source', return_value=(3, 0, False)) as fetch:
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
                   side_effect=[ScrapeError('down'), (1, 0, False)]) as fetch:
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

    def test_admin_saved_session_wins_over_env(self):
        import os
        from core.models import AppSettings
        from unittest.mock import patch as _p
        from core.news_scraper import x_cookies_path
        settings_obj = AppSettings.load()
        settings_obj.x_cookies = '.x.com\tTRUE\t/\tauth_token\tFROM_ADMIN'
        settings_obj.save()
        with _p.dict(os.environ, {'X_COOKIES': 'FROM_ENV'}, clear=True):
            path = x_cookies_path()
        self.assertIn('FROM_ADMIN', open(path).read())
        os.unlink(path)

    def test_replacing_the_session_is_picked_up_immediately(self):
        import os
        from core.models import AppSettings
        from unittest.mock import patch as _p
        from core.news_scraper import x_cookies_path
        settings_obj = AppSettings.load()
        with _p.dict(os.environ, {}, clear=True):
            settings_obj.x_cookies = 'FIRST_TOKEN'
            settings_obj.save()
            first = x_cookies_path()
            self.assertIn('FIRST_TOKEN', open(first).read())
            # An admin pastes a fresh jar; the cached temp file must not win.
            settings_obj.x_cookies = 'SECOND_TOKEN'
            settings_obj.save()
            second = x_cookies_path()
        self.assertIn('SECOND_TOKEN', open(second).read())
        for f in {first, second}:
            os.path.exists(f) and os.unlink(f)

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


class ScrapedMediaTests(TestCase):
    """A post's extra images and its video must survive into the article."""

    def setUp(self):
        self.admin = get_user_model().objects.create_superuser(
            'mediaeditor', 'm@example.com', 'pw',
        )
        login_with_2fa(self.client, self.admin)
        self.source = NewsSource.objects.create(
            name='Ours', kind='x', target='BurundinAddis', is_own_content=True,
        )

    def _approve(self, item):
        return self.client.post(
            reverse('custom_admin:news_scraper_review'),
            {'decision': 'approve', 'item_ids': [item.pk]},
        )

    def test_video_becomes_article_media_with_its_url(self):
        vid = ('https://video.twimg.com/ext_tw_video/1660297159902650368/pu/'
               'vid/1280x720/yqQtLPE_WgtezYEI.mp4?tag=12')
        item = ScrapedItem.objects.create(
            source=self.source, external_id='v1', title='Has video',
            published_at=timezone.now(),
            raw={'media': [{'type': 'video', 'url': vid}]},
        )
        self._approve(item)
        item.refresh_from_db()
        media = list(item.article.media.all())
        self.assertEqual(len(media), 1)
        self.assertEqual(media[0].media_type, 'video')
        # Stored whole — a truncated CDN link is a dead link.
        self.assertEqual(media[0].video_url, vid)

    def test_absurdly_long_video_url_is_skipped_not_truncated(self):
        item = ScrapedItem.objects.create(
            source=self.source, external_id='v2', title='Long url',
            published_at=timezone.now(),
            raw={'media': [{'type': 'video', 'url': 'https://v.tw/' + 'a' * 600}]},
        )
        self._approve(item)
        item.refresh_from_db()
        self.assertEqual(item.article.media.count(), 0)

    def test_extra_images_are_downloaded_and_hero_is_not_duplicated(self):
        from unittest.mock import patch as _p
        hero, extra = 'https://pbs.twimg.com/media/A?format=jpg', 'https://pbs.twimg.com/media/B?format=jpg'
        item = ScrapedItem.objects.create(
            source=self.source, external_id='i1', title='Two images',
            published_at=timezone.now(), image_url=hero,
            raw={'media': [{'type': 'image', 'url': hero},
                           {'type': 'image', 'url': extra}]},
        )
        item.image.save('hero.jpg', ContentFile(_PNG), save=True)
        with _p('core.news_scraper._download_image',
                return_value=('b.jpg', _PNG)) as dl:
            self._approve(item)
        item.refresh_from_db()
        # Only the non-hero image is fetched again.
        self.assertEqual(dl.call_count, 1)
        self.assertEqual(dl.call_args[0][0], extra)
        self.assertEqual(item.article.media.count(), 1)

    def test_a_failed_image_download_does_not_lose_the_article(self):
        from unittest.mock import patch as _p
        item = ScrapedItem.objects.create(
            source=self.source, external_id='i2', title='Broken image',
            published_at=timezone.now(),
            raw={'media': [{'type': 'image', 'url': 'https://pbs.twimg.com/media/X'}]},
        )
        with _p('core.news_scraper._download_image', return_value=None):
            self._approve(item)
        item.refresh_from_db()
        self.assertEqual(item.status, 'approved')
        self.assertIsNotNone(item.article)
        self.assertEqual(item.article.media.count(), 0)


class XRowParsingTests(TestCase):
    """gallery-dl emits a directory row per tweet and a file row per media.

    Text-only posts have no file row at all, so parsing must not depend on
    them — that is where most plain announcements live.
    """

    def _parse(self, rows):
        import json, os
        from unittest.mock import patch as _p
        from core.news_scraper import _fetch_x

        class _Proc:
            stdout, stderr = json.dumps(rows), ''

        lo = timezone.now() - timedelta(days=365)
        hi = timezone.now() + timedelta(days=1)
        with _p.dict(os.environ, {}, clear=True), \
                _p('core.news_scraper.subprocess.run', lambda *a, **k: _Proc()):
            return list(_fetch_x('BurundinAddis', lo, hi))

    @staticmethod
    def _tweet(tid, **extra):
        base = {'tweet_id': tid, 'date': timezone.now().strftime('%Y-%m-%d %H:%M:%S'),
                'content': f'Post {tid}', 'author': {'nick': 'Embassy'}}
        base.update(extra)
        return base

    def test_text_only_post_is_kept(self):
        posts = self._parse([[2, self._tweet(1)]])
        self.assertEqual(len(posts), 1)
        self.assertEqual(posts[0]['media'], [])
        self.assertEqual(posts[0]['image_url'], '')

    def test_all_images_are_collected_and_first_is_the_hero(self):
        t = self._tweet(2)
        rows = [
            [2, dict(t, count=2)],
            [3, 'https://pbs.twimg.com/media/A?format=jpg', dict(t, extension='jpg')],
            [3, 'https://pbs.twimg.com/media/B?format=jpg', dict(t, extension='jpg')],
        ]
        post = self._parse(rows)[0]
        self.assertEqual([m['type'] for m in post['media']], ['image', 'image'])
        self.assertTrue(post['image_url'].endswith('A?format=jpg'))

    def test_video_is_captured_and_hero_stays_empty_when_no_image(self):
        t = self._tweet(3)
        rows = [
            [2, dict(t, count=1)],
            [3, 'https://video.twimg.com/x/vid.mp4?tag=12', dict(t, extension='mp4')],
        ]
        post = self._parse(rows)[0]
        self.assertEqual(post['media'], [
            {'type': 'video', 'url': 'https://video.twimg.com/x/vid.mp4?tag=12'}])
        self.assertEqual(post['image_url'], '')

    def test_duplicate_file_rows_do_not_double_up(self):
        t = self._tweet(4)
        url = 'https://pbs.twimg.com/media/A?format=jpg'
        rows = [[2, t], [3, url, dict(t, extension='jpg')],
                [3, url, dict(t, extension='jpg')]]
        self.assertEqual(len(self._parse(rows)[0]['media']), 1)

    def test_command_asks_for_text_tweets(self):
        import json, os
        from unittest.mock import patch as _p
        from core.news_scraper import _fetch_x
        seen = {}

        class _Proc:
            stdout, stderr = '[]', ''

        with _p.dict(os.environ, {}, clear=True), \
                _p('core.news_scraper.subprocess.run',
                   lambda cmd, **k: (seen.update(cmd=cmd), _Proc())[1]):
            list(_fetch_x('x', timezone.now() - timedelta(days=1), timezone.now()))
        self.assertIn('text-tweets=true', seen['cmd'])


class AiHeadlineTests(TestCase):
    """Gemini writes the headline; a failure must never cost us the post."""

    def setUp(self):
        self.source = NewsSource.objects.create(
            name='Ours', kind='x', target='BurundinAddis',
        )
        self.body = ('Burundi Ambassador received H.E. Amjad Al-Momani, Ambassador of '
                     'the Hashemite Kingdom of Jordan to Ethiopia, on a courtesy call.')

    def _fetch(self, gemini):
        from unittest.mock import patch as _p
        post = {
            'external_id': 'p1', 'title': 'raw guessed title', 'title_derived': True,
            'content': self.body, 'image_url': '', 'source_url': '',
            'published_at': timezone.now(), 'media': [], 'raw': {},
        }
        with _p.dict('core.news_scraper.ADAPTERS',
                     {'x': lambda *a, **k: iter([post])}), \
                _p('core.news_scraper._ai_headline', gemini):
            from core.news_scraper import fetch_source
            fetch_source(self.source, timezone.now() - timedelta(days=2), timezone.now())
        return ScrapedItem.objects.get(external_id='p1')

    def test_headline_replaces_the_guessed_title(self):
        item = self._fetch(lambda text: 'Burundi and Jordan ambassadors meet in Addis')
        self.assertEqual(item.title, 'Burundi and Jordan ambassadors meet in Addis')

    def test_failure_falls_back_to_the_guessed_title(self):
        item = self._fetch(lambda text: '')
        self.assertEqual(item.title, 'raw guessed title')

    def test_already_queued_posts_are_not_re_billed(self):
        from unittest.mock import patch as _p
        calls = []
        self._fetch(lambda text: (calls.append(text), 'A headline that is long enough')[1])
        self.assertEqual(len(calls), 1)
        self._fetch(lambda text: (calls.append(text), 'Another headline entirely')[1])
        self.assertEqual(len(calls), 1)  # second run skipped the duplicate

    def test_reply_is_sanitised(self):
        from unittest.mock import patch as _p
        import core.news_scraper as ns

        class _R:
            status_code = 200
            def raise_for_status(self): pass
            def json(self):
                return {'candidates': [{'content': {'parts': [
                    {'text': '  "Burundi and Jordan meet."\nIgnore this second line'}]}}]}

        with _p.object(ns.django_settings, 'GEMINI_API_KEY', 'k', create=True), \
                _p('core.news_scraper.requests.post', lambda *a, **k: _R()):
            self.assertEqual(ns._ai_headline(self.body),
                             'Burundi and Jordan meet')

    def test_model_id_comes_from_settings(self):
        from unittest.mock import patch as _p
        import core.news_scraper as ns
        seen = {}

        class _R:
            def raise_for_status(self): pass
            def json(self):
                return {'candidates': [{'content': {'parts': [{'text': 'A fine headline here'}]}}]}

        def _post(url, **kw):
            seen['url'] = url
            return _R()

        with _p.object(ns.django_settings, 'GEMINI_API_KEY', 'k', create=True), \
                _p.object(ns.django_settings, 'GEMINI_MODEL', 'gemini-9-flash', create=True), \
                _p('core.news_scraper.requests.post', _post):
            ns._ai_headline(self.body)
        self.assertIn('gemini-9-flash:generateContent', seen['url'])
        self.assertNotIn('gemini-2.0', seen['url'])

    def test_no_api_key_means_no_call(self):
        from unittest.mock import patch as _p
        import core.news_scraper as ns
        with _p.object(ns.django_settings, 'GEMINI_API_KEY', '', create=True):
            self.assertEqual(ns._ai_headline(self.body), '')


class FetchTimeBudgetTests(TestCase):
    """Cloudflare kills the admin's request at 100s, so a fetch behind the
    button must stop early and stay resumable rather than time out."""

    def setUp(self):
        self.source = NewsSource.objects.create(
            name='Slow', kind='x', target='BurundinAddis',
        )

    def _posts(self, n):
        return [{
            'external_id': f'p{i}', 'title': f'post {i}', 'title_derived': False,
            'content': 'body', 'image_url': '', 'source_url': '',
            'published_at': timezone.now(), 'media': [], 'raw': {},
        } for i in range(n)]

    def _run(self, posts, budget, clock):
        from unittest.mock import patch as _p
        from core.news_scraper import fetch_source
        with _p.dict('core.news_scraper.ADAPTERS',
                     {'x': lambda *a, **k: iter(posts)}), \
                _p('core.news_scraper.time.monotonic', side_effect=clock):
            return fetch_source(self.source, timezone.now() - timedelta(days=2),
                                timezone.now(), time_budget=budget)

    def test_stops_early_when_the_budget_runs_out(self):
        # Clock jumps past the deadline after the first item.
        clock = [0, 0, 0, 1, 500, 500, 500, 500, 500, 500]
        created, _, truncated = self._run(self._posts(5), 70, clock)
        self.assertTrue(truncated)
        self.assertLess(created, 5)

    def test_what_it_saved_before_stopping_is_kept(self):
        clock = [0, 0, 0, 1, 500, 500, 500, 500, 500, 500]
        created, _, _ = self._run(self._posts(5), 70, clock)
        self.assertEqual(ScrapedItem.objects.count(), created)

    def test_a_second_run_resumes_instead_of_restarting(self):
        posts = self._posts(4)
        self._run(posts, 70, [0, 0, 0, 1, 500, 500, 500, 500])
        first = ScrapedItem.objects.count()
        self.assertGreater(first, 0)
        # Plenty of time now: the rest arrive, the earlier ones are skipped.
        created, skipped, truncated = self._run(posts, 70, [0] * 40)
        self.assertFalse(truncated)
        self.assertEqual(skipped, first)
        self.assertEqual(ScrapedItem.objects.count(), 4)

    def test_no_budget_means_no_truncation(self):
        created, _, truncated = self._run(self._posts(3), None, [0] * 40)
        self.assertFalse(truncated)
        self.assertEqual(created, 3)


class RemainingHelperTests(TestCase):
    def test_caps_at_the_default_and_never_returns_zero(self):
        from unittest.mock import patch as _p
        import core.news_scraper as ns
        self.assertEqual(ns._remaining(None, 240), 240)   # no deadline
        with _p('core.news_scraper.time.monotonic', return_value=0):
            self.assertEqual(ns._remaining(30, 240), 30)  # deadline is nearer
            self.assertEqual(ns._remaining(900, 240), 240)  # default is nearer
            self.assertEqual(ns._remaining(-5, 240), 1)   # already past: still positive
