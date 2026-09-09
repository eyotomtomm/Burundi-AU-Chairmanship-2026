from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone
from django.urls import reverse
from django_otp.oath import totp
from django_otp.plugins.otp_totp.models import TOTPDevice

from core.models import Article, ArticleComment, ContentReport, Discussion, DiscussionTopic


def login_with_2fa(client, user):
    """force_login + mark the session OTP-verified, as the middleware requires."""
    device, _ = TOTPDevice.objects.get_or_create(user=user, confirmed=True, defaults={'name': 'test'})
    client.force_login(user)
    session = client.session
    session['otp_device_id'] = device.persistent_id
    session.save()
    return device


def current_code(device):
    return f'{totp(device.bin_key, device.step, device.t0, device.digits, device.drift):06d}'


class UrlSectionMappingTests(SimpleTestCase):
    def test_every_url_is_mapped_or_unrestricted(self):
        from custom_admin import urls
        from custom_admin.permissions import get_required_section, MENU_KEYS, UNRESTRICTED_URLS, URL_SECTIONS
        for pattern in urls.urlpatterns:
            name = pattern.name
            if name in UNRESTRICTED_URLS:
                continue
            self.assertIn(get_required_section(name), MENU_KEYS, name)
        self.assertLessEqual(set(URL_SECTIONS.values()), MENU_KEYS)


@override_settings(ADMIN_2FA_REQUIRED=True)
class TwoFactorFlowTests(TestCase):
    def setUp(self):
        cache.clear()  # attempt counters live in the (process-wide) cache
        self.user = User.objects.create_superuser('boss', 'boss@example.com', 'correct-horse-battery')

    def test_password_login_requires_setup_then_dashboard(self):
        r = self.client.post(reverse('custom_admin:login'), {'username': 'boss', 'password': 'correct-horse-battery'})
        self.assertRedirects(r, reverse('custom_admin:2fa_setup'), fetch_redirect_response=False)
        # Every other admin page bounces to setup until a device is confirmed
        self.assertRedirects(self.client.get(reverse('custom_admin:dashboard')), reverse('custom_admin:2fa_setup'),
                             fetch_redirect_response=False)
        page = self.client.get(reverse('custom_admin:2fa_setup'))
        self.assertEqual(page.status_code, 200)
        self.assertContains(page, '<svg')
        device = TOTPDevice.objects.get(user=self.user, confirmed=False)
        r = self.client.post(reverse('custom_admin:2fa_setup'), {'otp_code': current_code(device)})
        self.assertRedirects(r, reverse('custom_admin:dashboard'), fetch_redirect_response=False)
        self.assertTrue(TOTPDevice.objects.get(pk=device.pk).confirmed)
        self.assertEqual(self.client.get(reverse('custom_admin:dashboard')).status_code, 200)

    def test_confirmed_device_goes_to_verify_and_limits_attempts(self):
        device = TOTPDevice.objects.create(user=self.user, name='a', confirmed=True)
        r = self.client.post(reverse('custom_admin:login'), {'username': 'boss', 'password': 'correct-horse-battery'})
        self.assertRedirects(r, reverse('custom_admin:2fa_verify'), fetch_redirect_response=False)
        self.assertRedirects(self.client.get(reverse('custom_admin:users_list')), reverse('custom_admin:2fa_verify'),
                             fetch_redirect_response=False)
        for _ in range(5):
            self.assertContains(self.client.post(reverse('custom_admin:2fa_verify'), {'otp_code': '000000'}), 'Invalid code')
        self.assertContains(self.client.post(reverse('custom_admin:2fa_verify'), {'otp_code': current_code(device)}),
                            'Too many attempts')

    def test_force_password_change_gate(self):
        self.user.profile.force_password_change = True
        self.user.profile.save(update_fields=['force_password_change'])
        login_with_2fa(self.client, self.user)
        self.assertRedirects(self.client.get(reverse('custom_admin:dashboard')),
                             reverse('custom_admin:force_password_change'), fetch_redirect_response=False)
        self.assertEqual(self.client.get(reverse('custom_admin:force_password_change')).status_code, 200)


class TwoFactorDisabledTests(TestCase):
    """ADMIN_2FA_REQUIRED off (the default): password alone reaches the dashboard."""

    def setUp(self):
        cache.clear()
        self.user = User.objects.create_superuser('boss', 'boss@example.com', 'correct-horse-battery')

    def test_login_goes_straight_to_dashboard(self):
        r = self.client.post(reverse('custom_admin:login'),
                             {'username': 'boss', 'password': 'correct-horse-battery'})
        self.assertRedirects(r, reverse('custom_admin:dashboard'), fetch_redirect_response=False)
        self.assertEqual(self.client.get(reverse('custom_admin:dashboard')).status_code, 200)

    def test_force_password_change_still_gates(self):
        self.user.profile.force_password_change = True
        self.user.profile.save(update_fields=['force_password_change'])
        self.client.force_login(self.user)
        self.assertRedirects(self.client.get(reverse('custom_admin:dashboard')),
                             reverse('custom_admin:force_password_change'), fetch_redirect_response=False)


class DestructiveViewsRequirePostTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_superuser('boss', 'boss@example.com', 'x')
        login_with_2fa(self.client, self.user)

    def test_get_does_not_delete(self):
        topic = DiscussionTopic.objects.create(title='Water')
        self.assertEqual(self.client.get(reverse('custom_admin:discussion_topic_delete', args=[topic.pk])).status_code, 405)
        self.assertTrue(DiscussionTopic.objects.filter(pk=topic.pk).exists())
        self.client.post(reverse('custom_admin:discussion_topic_delete', args=[topic.pk]))
        self.assertFalse(DiscussionTopic.objects.filter(pk=topic.pk).exists())

    def test_report_status_only_via_post(self):
        reporter = User.objects.create_user('rep', password='x')
        report = ContentReport.objects.create(reporter=reporter, reason='spam')
        url = reverse('custom_admin:content_report_set_status', args=[report.pk, 'dismissed'])
        self.assertEqual(self.client.get(url).status_code, 405)
        self.client.post(url)
        report.refresh_from_db()
        self.assertEqual(report.status, 'dismissed')


class EngagementViewTests(TestCase):
    """Admins can set a like count and post a comment on any content type."""

    def setUp(self):
        self.staff = User.objects.create_superuser('boss', 'boss@example.com', 'x')
        login_with_2fa(self.client, self.staff)
        self.article = Article.objects.create(title='Summit opens', content='...', publish_date=timezone.now())
        self.url = reverse('custom_admin:comment_engagement')

    def test_sets_like_count(self):
        self.client.post(self.url, {
            'type': 'article', 'content': self.article.pk,
            'action': 'likes', 'like_count': '250',
        })
        self.article.refresh_from_db()
        self.assertEqual(self.article.like_count, 250)

    def test_rejects_non_numeric_like_count(self):
        self.client.post(self.url, {
            'type': 'article', 'content': self.article.pk,
            'action': 'likes', 'like_count': 'lots',
        })
        self.article.refresh_from_db()
        self.assertEqual(self.article.like_count, 0)

    def test_posts_comment_as_named_user(self):
        reader = User.objects.create_user('amina', password='x')
        self.client.post(self.url, {
            'type': 'article', 'content': self.article.pk,
            'action': 'comment', 'username': 'amina', 'comment_text': 'Bravo!',
        })
        comment = ArticleComment.objects.get(article=self.article)
        self.assertEqual(comment.user, reader)
        self.assertEqual(comment.content, 'Bravo!')

    def test_posts_comment_as_admin_when_username_blank(self):
        self.client.post(self.url, {
            'type': 'article', 'content': self.article.pk,
            'action': 'comment', 'username': '', 'comment_text': 'Noted.',
        })
        self.assertEqual(ArticleComment.objects.get(article=self.article).user, self.staff)

    def test_unknown_username_creates_nothing(self):
        self.client.post(self.url, {
            'type': 'article', 'content': self.article.pk,
            'action': 'comment', 'username': 'ghost', 'comment_text': 'Hi',
        })
        self.assertFalse(ArticleComment.objects.exists())

    def test_page_renders_for_each_content_type(self):
        for kind in ('article', 'event', 'magazine', 'livefeed', 'video', 'gallery', 'discussion'):
            self.assertEqual(self.client.get(self.url, {'type': kind}).status_code, 200, kind)
        page = self.client.get(self.url, {'type': 'article', 'content': self.article.pk})
        self.assertContains(page, 'Summit opens')

    def test_content_lists_still_render(self):
        """The per-post shortcut markup did not break any content list template."""
        for name in ('articles_list', 'events_list', 'magazines_list', 'live_feeds_list',
                     'videos_list', 'gallery_list', 'discussions_list'):
            self.assertEqual(self.client.get(reverse(f'custom_admin:{name}')).status_code, 200, name)

    def test_article_row_links_to_engagement_page(self):
        page = self.client.get(reverse('custom_admin:articles_list'))
        self.assertContains(page, f'{self.url}?type=article&amp;content={self.article.pk}')
