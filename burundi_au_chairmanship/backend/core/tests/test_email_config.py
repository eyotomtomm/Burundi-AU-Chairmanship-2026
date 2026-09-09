"""OTP and system mail must have a sane, sendable SMTP configuration.

Django refuses EMAIL_USE_TLS and EMAIL_USE_SSL together, so an environment that
sets only one of them must not inherit a conflicting default for the other —
that would break every outgoing email, sign-up OTPs included.
"""
from unittest import mock

from django.core.mail.backends.smtp import EmailBackend as SMTPEmailBackend
from django.test import SimpleTestCase, TestCase

from config.settings import _smtp_security


class SmtpSecurityTests(SimpleTestCase):
    def test_tls_and_ssl_are_never_both_on(self):
        cases = [
            ({}, 465), ({}, 587),
            ({'T': 'True'}, 587), ({'T': 'False'}, 465),
            ({'S': 'True'}, 465), ({'S': 'False'}, 587),
            ({'T': 'True', 'S': 'True'}, 465),   # misconfigured
            ({'T': 'True', 'S': 'True'}, 587),   # misconfigured
            ({'T': 'False', 'S': 'False'}, 587),
        ]
        for env, port in cases:
            with self.subTest(env=env, port=port):
                mapping = {}
                if 'T' in env:
                    mapping['X_TLS'] = env['T']
                if 'S' in env:
                    mapping['X_SSL'] = env['S']
                import os
                for k, v in mapping.items():
                    os.environ[k] = v
                try:
                    tls, ssl = _smtp_security('X_TLS', 'X_SSL', port)
                finally:
                    for k in mapping:
                        os.environ.pop(k, None)
                self.assertFalse(tls and ssl, 'both on — Django would refuse')

    def test_encryption_is_never_dropped_by_default(self):
        # Turning both off is a deliberate operator choice (an internal relay
        # on port 25); silently defaulting into plaintext is not.
        for port in (25, 465, 587, 2525):
            tls, ssl = _smtp_security('W_TLS', 'W_SSL', port)
            self.assertTrue(tls or ssl, f'port {port} defaulted to plaintext')

    def test_the_port_decides_when_nothing_is_stated(self):
        self.assertEqual(_smtp_security('U_TLS', 'U_SSL', 465), (False, True))
        self.assertEqual(_smtp_security('U_TLS', 'U_SSL', 587), (True, False))

    def test_a_stated_flag_wins(self):
        import os
        os.environ['V_TLS'] = 'True'
        try:
            # Port 465 would normally imply SSL; an explicit TLS=True overrides.
            self.assertEqual(_smtp_security('V_TLS', 'V_SSL', 465), (True, False))
        finally:
            os.environ.pop('V_TLS', None)


class SenderIdentityTests(SimpleTestCase):
    def test_each_smtp_host_sends_as_an_address_it_can_authenticate(self):
        # A From on one domain sent through the other domain's server fails
        # DMARC, which is exactly how OTPs end up in spam.
        from django.conf import settings
        pairs = [
            (settings.EMAIL_HOST, settings.DEFAULT_FROM_EMAIL),
            (settings.FALLBACK_EMAIL_HOST, settings.FALLBACK_FROM_EMAIL),
        ]
        for host, from_email in pairs:
            with self.subTest(host=host):
                if 'burundichairship' in host:
                    self.assertIn('burundichairship.africa', from_email)
                elif 'gmail' in host:
                    self.assertIn('burundi4africa.com', from_email)


class LoggingBackendTests(TestCase):
    """The logging backend must record mail without hiding failures.

    It used to swallow every exception, which would have let send_email_otp
    report success for a code that never left the building.
    """

    def _backend(self, fail_silently=False):
        from core.email_backend import LoggingEmailBackend
        return LoggingEmailBackend(fail_silently=fail_silently)

    def _message(self):
        from django.core.mail import EmailMessage
        return EmailMessage(
            subject='Be 4 Africa - Email Verification OTP',
            body='Your email verification OTP code is: 123456',
            from_email='Be 4 Africa <info@burundichairship.africa>',
            to=['someone@example.com'],
        )

    def test_a_failed_send_raises_and_is_still_logged(self):
        from core.models import EmailLog
        backend = self._backend(fail_silently=False)
        with mock.patch.object(SMTPEmailBackend, 'send_messages',
                               side_effect=OSError('connection refused')):
            with self.assertRaises(OSError):
                backend.send_messages([self._message()])
        row = EmailLog.objects.latest('id')
        self.assertEqual(row.status, 'failed')
        # Categorised from the subject; either label puts it in the redact set.
        self.assertIn(row.category, ('otp', 'verification'))

    def test_fail_silently_still_suppresses(self):
        backend = self._backend(fail_silently=True)
        with mock.patch.object(SMTPEmailBackend, 'send_messages',
                               side_effect=OSError('connection refused')):
            self.assertEqual(backend.send_messages([self._message()]), 0)

    def test_a_successful_send_is_logged_with_the_code_redacted(self):
        from core.models import EmailLog
        backend = self._backend()
        with mock.patch.object(SMTPEmailBackend, 'send_messages', return_value=1):
            self.assertEqual(backend.send_messages([self._message()]), 1)
        row = EmailLog.objects.latest('id')
        self.assertEqual(row.status, 'sent')
        # An OTP body must never be readable from the log.
        self.assertNotIn('123456', row.body_preview)
