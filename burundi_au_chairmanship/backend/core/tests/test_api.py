"""
Smoke tests for the highest-risk API paths.

Run with:  python manage.py test core -v2
"""
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    AppSettings, Article, Category, DeviceToken, Event,
    EventRegistration, EventSubmission, FeatureCard, HeroSlide,
    UserProfile,
)

# Disable throttling globally so tests don't trip rate limits.
# Per-view @throttle_classes decorators still instantiate throttle classes,
# which look up their rate via scope in DEFAULT_THROTTLE_RATES, so we set
# all known scopes to a very high rate rather than removing them.
TEST_THROTTLE_RATES = {
    'anon': '10000/min',
    'user': '10000/min',
    'auth': '10000/min',
    'otp': '10000/min',
    'otp_verify': '10000/min',
    'view_count': '10000/min',
    'like_toggle': '10000/min',
    'support': '10000/min',
    'search': '10000/min',
    'proxy_registration': '10000/min',
}

TEST_REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_CLASSES': [],
    'DEFAULT_THROTTLE_RATES': TEST_THROTTLE_RATES,
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
}


def _auth_header(user):
    """Return a Bearer header dict for the given user (JWT)."""
    refresh = RefreshToken.for_user(user)
    return {'HTTP_AUTHORIZATION': f'Bearer {refresh.access_token}'}


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class HealthCheckTests(TestCase):
    """Verify the load-balancer health endpoint stays up."""

    def test_anonymous_returns_200(self):
        resp = self.client.get('/api/health/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.json()['status'], 'ok')

    def test_staff_gets_detailed_response(self):
        admin = User.objects.create_superuser('admin', 'a@b.com', 'pw12345678')
        client = APIClient()
        client.credentials(**_auth_header(admin))
        resp = client.get('/api/health/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertIn('checks', data)
        self.assertIn('database', data['checks'])


# ───────────────────────── Auth flow ──────────────────────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class JWTRegistrationTests(TestCase):
    """Legacy email/password registration."""

    def setUp(self):
        # Clear cache so per-view @throttle_classes don't carry over
        # between tests (all tests share 127.0.0.1 as client IP).
        from django.core.cache import cache
        cache.clear()

    def test_register_success(self):
        resp = self.client.post('/api/auth/register/', {
            'name': 'Test User',
            'email': 'test@example.com',
            'password': 'StrongP@ss123!',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        data = resp.json()
        self.assertIn('access', data)
        self.assertIn('refresh', data)
        self.assertTrue(User.objects.filter(email='test@example.com').exists())

    def test_register_duplicate_email_rejected(self):
        User.objects.create_user('existing', 'dup@example.com', 'pw12345678')
        resp = self.client.post('/api/auth/register/', {
            'name': 'Dup',
            'email': 'dup@example.com',
            'password': 'StrongP@ss123!',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_weak_password_rejected(self):
        resp = self.client.post('/api/auth/register/', {
            'name': 'Weak',
            'email': 'weak@example.com',
            'password': '123',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_honeypot_returns_fake_success(self):
        resp = self.client.post('/api/auth/register/', {
            'name': 'Bot',
            'email': 'bot@example.com',
            'password': 'StrongP@ss123!',
            '_hp': 'gotcha',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        # No user should actually be created
        self.assertFalse(User.objects.filter(email='bot@example.com').exists())


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class JWTLoginTests(TestCase):
    """Legacy email/password login."""

    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.user = User.objects.create_user(
            'loginuser', 'login@example.com', 'C0rrectP@ss!',
        )

    def test_login_success(self):
        resp = self.client.post('/api/auth/login/', {
            'email': 'login@example.com',
            'password': 'C0rrectP@ss!',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertIn('access', data)
        self.assertIn('refresh', data)

    def test_login_wrong_password(self):
        resp = self.client.post('/api/auth/login/', {
            'email': 'login@example.com',
            'password': 'WrongPassword1!',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_nonexistent_email(self):
        resp = self.client.post('/api/auth/login/', {
            'email': 'nobody@example.com',
            'password': 'Whatever1!',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_returns_same_error_for_user_not_found_and_wrong_password(self):
        """Prevent account enumeration via different error messages."""
        resp_no_user = self.client.post('/api/auth/login/', {
            'email': 'nobody@example.com',
            'password': 'Whatever1!',
        }, content_type='application/json')
        resp_wrong_pw = self.client.post('/api/auth/login/', {
            'email': 'login@example.com',
            'password': 'WrongPassword1!',
        }, content_type='application/json')
        self.assertEqual(
            resp_no_user.json()['detail'],
            resp_wrong_pw.json()['detail'],
        )


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class LogoutTests(TestCase):
    """Verify token blacklisting on logout."""

    def setUp(self):
        self.user = User.objects.create_user(
            'logoutuser', 'logout@example.com', 'L0goutP@ss!',
        )
        self.refresh = RefreshToken.for_user(self.user)
        self.client = APIClient()
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {self.refresh.access_token}',
        )

    def test_logout_requires_refresh_token(self):
        resp = self.client.post('/api/auth/logout/', {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_success(self):
        resp = self.client.post('/api/auth/logout/', {
            'refresh': str(self.refresh),
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class ProfileTests(TestCase):
    """Verify authenticated profile access."""

    def setUp(self):
        self.user = User.objects.create_user(
            'profileuser', 'profile@example.com', 'Pr0fileP@ss!',
        )
        self.client = APIClient()
        self.client.credentials(**_auth_header(self.user))

    def test_get_profile_authenticated(self):
        resp = self.client.get('/api/auth/profile/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.json()['email'], 'profile@example.com')

    def test_get_profile_unauthenticated(self):
        client = APIClient()
        resp = client.get('/api/auth/profile/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


# ────────────────── Push token registration ───────────────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class FCMTokenRegistrationTests(TestCase):
    """Push notification token registration (public + authenticated)."""

    def test_register_anonymous_token(self):
        resp = self.client.post('/api/register-fcm-token/', {
            'fcm_token': 'fake-fcm-token-abc123',
            'device_type': 'iPhone 15',
            'device_os': 'iOS 18',
            'preferred_language': 'fr',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        token = DeviceToken.objects.get(token='fake-fcm-token-abc123')
        self.assertIsNone(token.user)
        self.assertTrue(token.is_active)
        self.assertEqual(token.preferred_language, 'fr')

    def test_register_token_missing_value(self):
        resp = self.client.post('/api/register-fcm-token/', {},
                                content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_token_invalid_language_defaults_to_en(self):
        resp = self.client.post('/api/register-fcm-token/', {
            'fcm_token': 'token-lang-test',
            'preferred_language': 'xx',
        }, content_type='application/json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(
            DeviceToken.objects.get(token='token-lang-test').preferred_language,
            'en',
        )

    def test_authenticated_update_fcm_token(self):
        user = User.objects.create_user('fcmuser', 'fcm@example.com', 'FcmP@ss123!')
        client = APIClient()
        client.credentials(**_auth_header(user))
        resp = client.post('/api/auth/update-fcm-token/', {
            'fcm_token': 'auth-fcm-token-xyz',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        token = DeviceToken.objects.get(token='auth-fcm-token-xyz')
        self.assertEqual(token.user, user)

    def test_update_fcm_token_unauthenticated(self):
        client = APIClient()
        resp = client.post('/api/auth/update-fcm-token/', {
            'fcm_token': 'unauth-token',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


# ───────────────── Event registration submission ──────────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class EventSubmissionTests(TestCase):
    """Event registration submission (highest-risk write path)."""

    def setUp(self):
        self.user = User.objects.create_user(
            'evtuser', 'evt@example.com', 'EvtP@ss123!',
        )
        # Mark email as verified so _require_verified_email passes
        profile = self.user.profile
        profile.is_email_verified = True
        profile.save()

        self.event_reg = EventRegistration.objects.create(
            event_title='Test Gala',
            event_description='A test event',
            is_registration_enabled=True,
            max_registrations=0,  # unlimited
            send_confirmation_email=False,
        )
        self.client = APIClient()
        self.client.credentials(**_auth_header(self.user))

    def test_submit_registration(self):
        resp = self.client.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {'full_name': 'Test User', 'email': 'evt@example.com'},
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(EventSubmission.objects.count(), 1)

    def test_duplicate_self_registration_blocked(self):
        # First submission
        self.client.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {'full_name': 'Test User'},
        }, format='json')
        # Second should fail
        resp = self.client.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {'full_name': 'Test User Again'},
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(EventSubmission.objects.count(), 1)

    def test_waitlist_when_full(self):
        self.event_reg.max_registrations = 1
        self.event_reg.save()

        # First user fills the slot
        user1 = User.objects.create_user('first', 'first@example.com', 'P@ss12345!')
        user1.profile.is_email_verified = True
        user1.profile.save()
        c1 = APIClient()
        c1.credentials(**_auth_header(user1))
        c1.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {},
        }, format='json')

        # Second user should be waitlisted
        resp = self.client.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {},
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        submission = EventSubmission.objects.get(user=self.user)
        self.assertTrue(submission.is_waitlisted)

    def test_unauthenticated_submission_rejected(self):
        client = APIClient()
        resp = client.post('/api/event-submissions/', {
            'event_registration': self.event_reg.pk,
            'form_data': {},
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


# ──────────────────── Public read endpoints ───────────────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class PublicEndpointTests(TestCase):
    """Smoke-test that public read endpoints return 200 and valid structure."""

    def test_home_feed(self):
        AppSettings.objects.create(summit_year='2026')
        resp = self.client.get('/api/home-feed/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertIn('hero_slides', data)
        self.assertIn('feature_cards', data)
        self.assertIn('settings', data)

    def test_app_settings(self):
        AppSettings.objects.create(summit_year='2026')
        resp = self.client.get('/api/settings/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_articles_list(self):
        resp = self.client.get('/api/articles/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_events_list(self):
        resp = self.client.get('/api/events/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_categories_list(self):
        resp = self.client.get('/api/categories/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_feature_cards_list(self):
        resp = self.client.get('/api/feature-cards/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_event_registrations_list(self):
        resp = self.client.get('/api/event-registrations/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_hero_slides_list(self):
        resp = self.client.get('/api/hero-slides/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_priority_agendas_list(self):
        resp = self.client.get('/api/priority-agendas/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_gallery_list(self):
        resp = self.client.get('/api/gallery/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_videos_list(self):
        resp = self.client.get('/api/videos/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_social_media_list(self):
        resp = self.client.get('/api/social-media/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)


# ─────────────── Auth-guarded endpoints require auth ──────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class AuthGuardTests(TestCase):
    """Verify that endpoints meant to be auth-guarded actually reject anon."""

    GUARDED_ENDPOINTS = [
        ('GET', '/api/auth/profile/'),
        ('POST', '/api/auth/update-fcm-token/'),
        ('POST', '/api/auth/deactivate-fcm-token/'),
        ('POST', '/api/auth/logout/'),
        ('PUT', '/api/auth/profile/update/'),
        ('POST', '/api/auth/change-password/'),
        ('GET', '/api/auth/login-history/'),
        ('GET', '/api/auth/active-sessions/'),
        ('POST', '/api/event-submissions/'),
        ('GET', '/api/bookmarks/'),
    ]

    def test_guarded_endpoints_reject_anonymous(self):
        client = APIClient()
        for method, url in self.GUARDED_ENDPOINTS:
            with self.subTest(url=url, method=method):
                if method == 'GET':
                    resp = client.get(url)
                else:
                    resp = client.post(url, {}, format='json')
                self.assertEqual(
                    resp.status_code,
                    status.HTTP_401_UNAUTHORIZED,
                    f'{method} {url} should require auth but returned {resp.status_code}',
                )


# ─────────────── UserProfile auto-creation signal ─────────────


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class UserProfileSignalTests(TestCase):
    """Verify UserProfile is auto-created for every new User."""

    def test_profile_created_on_user_create(self):
        user = User.objects.create_user('sigtest', 'sig@example.com', 'P@ss12345!')
        self.assertTrue(hasattr(user, 'profile'))
        self.assertIsInstance(user.profile, UserProfile)

    def test_profile_not_duplicated_on_user_save(self):
        user = User.objects.create_user('sigtest2', 'sig2@example.com', 'P@ss12345!')
        user.first_name = 'Updated'
        user.save()
        self.assertEqual(UserProfile.objects.filter(user=user).count(), 1)
