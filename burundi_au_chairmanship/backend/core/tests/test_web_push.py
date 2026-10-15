"""Website (browser) push subscribers get a click-through link and the seal icon."""
from unittest import mock

from django.test import TestCase, override_settings

from core.models import DeviceToken, Notification
from core.push_service import send_push_notification


@override_settings(SITE_URL='https://burundi4africa.com')
class WebPushTests(TestCase):
    def setUp(self):
        DeviceToken.objects.create(token='w' * 160, device_os='Web', preferred_language='fr')

    def _send(self, **fields):
        from firebase_admin import messaging
        n = Notification.objects.create(title='Hi', title_fr='Salut', message='m', is_global=True, **fields)
        ok = mock.Mock(success_count=1, failure_count=0, responses=[mock.Mock(exception=None)])
        with mock.patch('config.firebase.initialize_firebase'), \
                mock.patch.object(messaging, 'send_each', return_value=ok) as send:
            send_push_notification(n)
        [msg] = send.call_args[0][0]
        return msg

    def test_default_link_is_site_home(self):
        msg = self._send()
        self.assertEqual(msg.webpush.fcm_options.link, 'https://burundi4africa.com')
        self.assertEqual(msg.webpush.notification.icon, 'https://burundi4africa.com/img/seal.png')
        self.assertEqual(msg.notification.title, 'Salut')

    def test_external_https_url_is_the_link(self):
        msg = self._send(action_type='url', action_value='https://au.int/en/summit')
        self.assertEqual(msg.webpush.fcm_options.link, 'https://au.int/en/summit')
