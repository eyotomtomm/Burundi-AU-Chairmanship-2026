"""Explore feed: moderation gates, blocking, and the query counts that matter."""
from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from core.models import (
    Block, ContentReport, Discussion, DiscussionReply, DiscussionTag,
    ExploreNotification, Poll, PollOption,
)


def make_user(name, *, verified=True, terms=True):
    user = User.objects.create_user(name, f'{name}@example.com', 'pw', first_name=name.title())
    profile = user.profile
    profile.is_email_verified = verified
    if terms:
        profile.explore_terms_accepted_at = timezone.now()
    profile.save()
    return user


def complete(user):
    """Fill the fields _require_complete_profile insists on."""
    p = user.profile
    p.nationality = 'BI'  # ISO code — the column is max_length=5, not a country name
    p.gender = 'female'
    p.date_of_birth = '1998-04-02'
    p.phone_number = '+25779000000'
    p.profile_picture = 'profiles/x.jpg'
    p.save()
    user.last_name = 'Test'
    user.save()
    return user


class PostModerationTests(TestCase):
    def setUp(self):
        self.user = complete(make_user('ann'))
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_a_banned_account_cannot_post(self):
        # It could before: the ban was only checked when writing a reply.
        self.user.profile.is_comment_banned = True
        self.user.profile.save()
        res = self.client.post('/api/discussions/', {'content': 'hello', 'category': 'general'})
        self.assertEqual(res.status_code, 403)
        self.assertEqual(Discussion.objects.count(), 0)

    def test_posting_without_accepting_the_terms_is_refused(self):
        self.user.profile.explore_terms_accepted_at = None
        self.user.profile.save()
        res = self.client.post('/api/discussions/', {'content': 'hello', 'category': 'general'})
        self.assertEqual(res.status_code, 403)
        self.assertTrue(res.json().get('terms_required'))

    def test_post_content_is_length_capped(self):
        res = self.client.post(
            '/api/discussions/',
            {'content': 'x' * (Discussion.MAX_CONTENT_LENGTH + 1), 'category': 'general'})
        self.assertEqual(res.status_code, 400)

    def test_edits_close_after_the_window_and_are_marked(self):
        post = Discussion.objects.create(author=self.user, content='first', category='general')
        res = self.client.patch(f'/api/discussions/{post.pk}/', {'content': 'second'})
        self.assertEqual(res.status_code, 200)
        self.assertIsNotNone(res.json()['edited_at'])

        # Age the row in place — re-saving the stale instance would put the
        # old text back and mask the check we are testing.
        Discussion.objects.filter(pk=post.pk).update(
            created_at=timezone.now() - timezone.timedelta(hours=2))
        late = self.client.patch(f'/api/discussions/{post.pk}/', {'content': 'third'})
        self.assertEqual(late.status_code, 403)
        post.refresh_from_db()
        self.assertEqual(post.content, 'second')


class CommentTextTests(TestCase):
    def test_comment_text_is_stored_as_typed(self):
        # Escaping on write reached readers as "Burundi&#x27;s".
        user = make_user('ben')
        client = APIClient()
        client.force_authenticate(user=user)
        post = Discussion.objects.create(author=user, content='q')
        res = client.post(f'/api/discussions/{post.pk}/replies/',
                          {'content': "Burundi's youth & the AU <3"})
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.json()['content'], "Burundi's youth & the AU <3")


class BlockTests(TestCase):
    def setUp(self):
        self.me = make_user('me')
        self.them = make_user('them')
        self.post = Discussion.objects.create(author=self.them, content='theirs')
        self.client = APIClient()
        self.client.force_authenticate(user=self.me)

    def test_blocking_hides_their_posts_both_ways(self):
        self.assertEqual(len(self.client.get('/api/discussions/').json()['results']), 1)

        res = self.client.post(f'/api/users/{self.them.pk}/block/')
        self.assertTrue(res.json()['is_blocked'])
        self.assertEqual(self.client.get('/api/discussions/').json()['results'], [])

        # And they cannot see mine either.
        Discussion.objects.create(author=self.me, content='mine')
        theirs = APIClient()
        theirs.force_authenticate(user=self.them)
        contents = [p['content'] for p in theirs.get('/api/discussions/').json()['results']]
        self.assertNotIn('mine', contents)

    def test_blocking_unfollows_and_silences_notifications(self):
        self.client.post(f'/api/users/{self.them.pk}/block/')
        ExploreNotification.objects.all().delete()
        theirs = APIClient()
        theirs.force_authenticate(user=self.them)
        mine = Discussion.objects.create(author=self.me, content='mine')
        theirs.post(f'/api/discussions/{mine.pk}/toggle-like/')
        self.assertEqual(ExploreNotification.objects.count(), 0)

    def test_unblocking_restores_the_feed(self):
        self.client.post(f'/api/users/{self.them.pk}/block/')
        self.client.post(f'/api/users/{self.them.pk}/block/')
        self.assertEqual(len(self.client.get('/api/discussions/').json()['results']), 1)


class NotificationTests(TestCase):
    def test_relike_does_not_re_notify(self):
        author, fan = make_user('author'), make_user('fan')
        post = Discussion.objects.create(author=author, content='hi')
        client = APIClient()
        client.force_authenticate(user=fan)
        for _ in range(4):
            client.post(f'/api/discussions/{post.pk}/toggle-like/')
        self.assertEqual(
            ExploreNotification.objects.filter(recipient=author, verb='like').count(), 1)


class ReportTests(TestCase):
    def setUp(self):
        self.author = make_user('writer')
        self.post = Discussion.objects.create(author=self.author, content='spicy')

    def _report(self, user, reason):
        client = APIClient()
        client.force_authenticate(user=user)
        return client.post('/api/reports/', {'discussion': self.post.pk, 'reason': reason})

    def test_re_reporting_updates_the_reason(self):
        reporter = make_user('r1')
        self._report(reporter, 'spam')
        self._report(reporter, 'violence')
        self.assertEqual(
            ContentReport.objects.get(reporter=reporter, discussion=self.post).reason, 'violence')

    def test_enough_reports_pulls_the_post_from_the_feed(self):
        for i in range(Discussion.AUTO_HIDE_REPORTS):
            self._report(make_user(f'rep{i}'), 'harassment')
        self.post.refresh_from_db()
        self.assertTrue(self.post.is_hidden)

        onlooker = APIClient()
        onlooker.force_authenticate(user=make_user('onlooker'))
        self.assertEqual(onlooker.get('/api/discussions/').json()['results'], [])

        # The author still sees it, so it does not vanish silently on them.
        mine = APIClient()
        mine.force_authenticate(user=self.author)
        self.assertEqual(len(mine.get('/api/discussions/').json()['results']), 1)


class TagTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = make_user('tagger')

    def test_tags_are_indexed_on_save_and_resync_on_edit(self):
        post = Discussion.objects.create(author=self.user, content='clean #Water and #sanitation')
        self.assertEqual(set(post.tags.values_list('tag', flat=True)), {'water', 'sanitation'})

        post.content = 'only #water now'
        post.save()
        self.assertEqual(set(post.tags.values_list('tag', flat=True)), {'water'})

    def test_tag_filter_matches_whole_tags_only(self):
        Discussion.objects.create(author=self.user, content='#water')
        Discussion.objects.create(author=self.user, content='#watershed')
        client = APIClient()
        res = client.get('/api/discussions/?tag=water')
        self.assertEqual(len(res.json()['results']), 1)

    def test_trending_reads_the_index(self):
        for i in range(3):
            Discussion.objects.create(author=self.user, content=f'post {i} #arise')
        Discussion.objects.create(author=self.user, content='#culture')
        rows = APIClient().get('/api/explore/tags/').json()
        self.assertEqual(rows[0], {'tag': 'arise', 'count': 3})


class FeedQueryBudgetTests(TestCase):
    """The feed used to cost a query per repost and per poll: 69 for one page
    of twenty. These are ceilings, not exact counts — they fail on a
    regression back to per-row queries, not on an incidental improvement."""

    def assertQueriesAtMost(self, budget):
        from django.db import connection
        from django.test.utils import CaptureQueriesContext
        ctx = CaptureQueriesContext(connection)

        class _Guard:
            def __enter__(inner):
                ctx.__enter__()
                return inner

            def __exit__(inner, *exc):
                ctx.__exit__(*exc)
                if exc[0] is None:
                    self.assertLessEqual(len(ctx), budget,
                                         f'{len(ctx)} queries, budget {budget}')
        return _Guard()

    def test_a_page_of_reposts_and_polls_stays_under_budget(self):
        user = make_user('busy')
        for i in range(10):
            original = Discussion.objects.create(author=user, content=f'orig {i} #water')
            poll = Poll.objects.create(title='q', created_by=user, discussion=original)
            PollOption.objects.create(poll=poll, text='a', order=0, display_order=0)
            PollOption.objects.create(poll=poll, text='b', order=1, display_order=1)
            Discussion.objects.create(author=user, repost_of=original, content='')

        client = APIClient()
        client.force_authenticate(user=user)
        # Measure steady state. A user's first request also runs the
        # maintenance check and writes their session row (last_active update,
        # session lookup, session insert) — middleware noise that fires once
        # and would otherwise be counted against the endpoint's budget.
        client.get('/api/discussions/')
        with self.assertQueriesAtMost(12):
            res = client.get('/api/discussions/')
        self.assertEqual(len(res.json()['results']), 20)

    def test_a_thread_of_replies_stays_under_budget(self):
        user = make_user('chatty')
        post = Discussion.objects.create(author=user, content='q')
        DiscussionReply.objects.bulk_create(
            [DiscussionReply(discussion=post, author=user, content=f'r{i}') for i in range(30)])
        client = APIClient()
        client.force_authenticate(user=user)
        client.get(f'/api/discussions/{post.pk}/replies/')  # warm-up, see above
        with self.assertQueriesAtMost(8):
            res = client.get(f'/api/discussions/{post.pk}/replies/')
        self.assertEqual(res.json()['count'], 30)
