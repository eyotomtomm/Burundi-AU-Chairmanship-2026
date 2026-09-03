"""Regression tests for the 2026-09 security hardening."""
from datetime import timedelta
from unittest import mock

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from core.models import EventRegistration, EventSubmission
from core.tasks import cleanup_deactivated_accounts
from core.tests.test_api import TEST_REST_FRAMEWORK, _auth_header


class DeactivatedAccountCleanupTests(TestCase):
    def test_paused_accounts_survive_but_expired_deletions_are_purged(self):
        long_ago = timezone.now() - timedelta(days=45)
        paused = User.objects.create_user('paused', 'paused@example.com', 'P@ssw0rd!x')
        paused.profile.is_deactivated = True
        paused.profile.deactivated_at = long_ago
        paused.profile.save()

        doomed = User.objects.create_user('doomed', 'doomed@example.com', 'P@ssw0rd!x')
        doomed.profile.is_scheduled_for_deletion = True
        doomed.profile.deletion_scheduled_for = long_ago
        doomed.profile.save()

        with mock.patch('core.management.commands.purge_deleted_accounts.firebase_auth'):
            cleanup_deactivated_accounts()

        self.assertTrue(User.objects.filter(pk=paused.pk).exists())
        self.assertFalse(User.objects.filter(pk=doomed.pk).exists())


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class ProfilePrivilegeFieldsTests(TestCase):
    def test_admin_sections_cannot_be_set_via_profile_update(self):
        user = User.objects.create_user('plain', 'plain@example.com', 'P@ssw0rd!x')
        user.profile.receives_newsletter = False
        user.profile.save()
        client = APIClient()
        client.credentials(**_auth_header(user))
        resp = client.put('/api/auth/profile/update/', {
            'profile': {'admin_sections': ['analytics'], 'is_usher': True, 'receives_newsletter': True},
            'organization': 'Legit change',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        user.profile.refresh_from_db()
        self.assertFalse(user.profile.admin_sections)
        self.assertFalse(user.profile.is_usher)
        self.assertFalse(user.profile.receives_newsletter)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class InactiveLoginTests(TestCase):
    def test_admin_disabled_account_cannot_log_in(self):
        user = User.objects.create_user('disabled', 'disabled@example.com', 'P@ssw0rd!x')
        user.is_active = False
        user.save()
        resp = APIClient().post('/api/auth/login/', {
            'email': 'disabled@example.com', 'password': 'P@ssw0rd!x',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertNotIn('access', resp.data)
        user.refresh_from_db()
        self.assertFalse(user.is_active)

    def test_self_deactivated_account_still_reactivates(self):
        user = User.objects.create_user('paused2', 'paused2@example.com', 'P@ssw0rd!x')
        user.is_active = False
        user.save()
        user.profile.is_deactivated = True
        user.profile.save()
        resp = APIClient().post('/api/auth/login/', {
            'email': 'paused2@example.com', 'password': 'P@ssw0rd!x',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data.get('reactivated'))


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class CheckInPermissionTests(TestCase):
    def setUp(self):
        self.attendee = User.objects.create_user('att', 'att@example.com', 'P@ssw0rd!x')
        self.attendee.profile.is_email_verified = True
        self.attendee.profile.save()
        reg = EventRegistration.objects.create(
            event_title='Gala', event_description='x', is_registration_enabled=True,
            max_registrations=0, send_confirmation_email=False,
        )
        self.submission = EventSubmission.objects.create(
            event_registration=reg, user=self.attendee, form_data={}, status='approved',
        )
        if not self.submission.qr_ticket_hash:
            self.submission.generate_qr_hash()
            self.submission.save()
        self.qr = f'EVT:{self.submission.id}:{self.submission.qr_ticket_hash}'
        self.url = f'/api/event-submissions/{self.submission.id}/check-in/'

    def test_attendee_cannot_self_check_in(self):
        client = APIClient()
        client.credentials(**_auth_header(self.attendee))
        resp = client.post(self.url, {'qr_data': self.qr}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.submission.refresh_from_db()
        self.assertIsNone(self.submission.checked_in_at)

    def test_staff_can_check_in_someone_elses_ticket(self):
        staff = User.objects.create_user('staff', 'staff@example.com', 'P@ssw0rd!x', is_staff=True)
        staff.profile.is_email_verified = True
        staff.profile.save()
        client = APIClient()
        client.credentials(**_auth_header(staff))
        resp = client.post(self.url, {'qr_data': self.qr}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.submission.refresh_from_db()
        self.assertIsNotNone(self.submission.checked_in_at)
