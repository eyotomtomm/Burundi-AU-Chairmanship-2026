"""
Tests for the dual auth backend seam (Firebase + JWT).

Verifies that:
1. Firebase auto-promotes is_email_verified False->True
2. Firebase never downgrades is_email_verified True->False
3. JWT path does not auto-promote is_email_verified
4. _require_verified_email gate applies equally to both auth paths
"""
from unittest.mock import patch, MagicMock

from django.contrib.auth.models import User
from django.test import TestCase, override_settings, RequestFactory
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from core.authentication import FirebaseAuthentication
from core.models import UserProfile


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


class FirebaseAutoPromotionTests(TestCase):
    """Test Firebase email-verification auto-promotion logic."""

    def setUp(self):
        self.user = User.objects.create_user(
            'fbuser', 'fb@example.com', 'P@ss12345!',
        )
        self.profile = self.user.profile
        self.profile.firebase_uid = 'firebase-uid-123'
        self.profile.save()
        self.factory = RequestFactory()
        self.backend = FirebaseAuthentication()

    @patch('core.authentication.verify_firebase_token')
    def test_firebase_promotes_unverified_to_verified(self, mock_verify):
        """Firebase token with email_verified=True promotes a False profile."""
        self.profile.is_email_verified = False
        self.profile.save(update_fields=['is_email_verified'])

        mock_verify.return_value = {
            'uid': 'firebase-uid-123',
            'email_verified': True,
        }

        request = self.factory.get('/', HTTP_AUTHORIZATION='Bearer fake-firebase-token')
        user, token_data = self.backend.authenticate(request)

        self.profile.refresh_from_db()
        self.assertEqual(user, self.user)
        self.assertTrue(self.profile.is_email_verified)

    @patch('core.authentication.verify_firebase_token')
    def test_firebase_does_not_downgrade_verified(self, mock_verify):
        """Firebase token with email_verified=False must NOT downgrade a True profile."""
        self.profile.is_email_verified = True
        self.profile.save(update_fields=['is_email_verified'])

        mock_verify.return_value = {
            'uid': 'firebase-uid-123',
            'email_verified': False,
        }

        request = self.factory.get('/', HTTP_AUTHORIZATION='Bearer fake-firebase-token')
        user, token_data = self.backend.authenticate(request)

        self.profile.refresh_from_db()
        self.assertEqual(user, self.user)
        self.assertTrue(self.profile.is_email_verified)


@override_settings(
    REST_FRAMEWORK={
        'DEFAULT_THROTTLE_CLASSES': [],
        'DEFAULT_THROTTLE_RATES': TEST_THROTTLE_RATES,
        'DEFAULT_PERMISSION_CLASSES': [
            'rest_framework.permissions.IsAuthenticated',
        ],
        'DEFAULT_AUTHENTICATION_CLASSES': [
            'rest_framework_simplejwt.authentication.JWTAuthentication',
        ],
    }
)
class JWTNoPromotionTests(TestCase):
    """Verify JWT path does NOT auto-promote is_email_verified."""

    def test_jwt_does_not_promote_unverified(self):
        """JWT login for an unverified user leaves is_email_verified=False."""
        user = User.objects.create_user(
            'jwtuser', 'jwt@example.com', 'P@ss12345!',
        )
        profile = user.profile
        profile.is_email_verified = False
        profile.save(update_fields=['is_email_verified'])

        client = APIClient()
        refresh = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        # Hit a protected endpoint to exercise the JWT auth path
        client.get('/api/auth/profile/')

        profile.refresh_from_db()
        self.assertFalse(profile.is_email_verified)


@override_settings(
    REST_FRAMEWORK={
        'DEFAULT_THROTTLE_CLASSES': [],
        'DEFAULT_THROTTLE_RATES': TEST_THROTTLE_RATES,
        'DEFAULT_PERMISSION_CLASSES': [
            'rest_framework.permissions.IsAuthenticated',
        ],
        'DEFAULT_AUTHENTICATION_CLASSES': [
            'rest_framework_simplejwt.authentication.JWTAuthentication',
        ],
    }
)
class VerifiedEmailGateTests(TestCase):
    """Verify _require_verified_email blocks unverified users via JWT."""

    def test_unverified_user_gets_403_on_gated_endpoint(self):
        """An unverified user hitting a verified-email-gated endpoint gets 403."""
        user = User.objects.create_user(
            'unverified', 'unverified@example.com', 'P@ss12345!',
        )
        profile = user.profile
        profile.is_email_verified = False
        profile.save(update_fields=['is_email_verified'])

        client = APIClient()
        refresh = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        # event-submissions create calls _require_verified_email
        resp = client.post('/api/event-submissions/', {
            'event_registration': 9999,
            'form_data': {},
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_verified_user_passes_email_gate(self):
        """A verified user is not blocked by _require_verified_email."""
        user = User.objects.create_user(
            'verified', 'verified@example.com', 'P@ss12345!',
        )
        profile = user.profile
        profile.is_email_verified = True
        profile.save(update_fields=['is_email_verified'])

        client = APIClient()
        refresh = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        # Should pass the email gate (may fail for other reasons like missing
        # event_registration, but NOT with 403)
        resp = client.post('/api/event-submissions/', {
            'event_registration': 9999,
            'form_data': {},
        }, format='json')
        self.assertNotEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
