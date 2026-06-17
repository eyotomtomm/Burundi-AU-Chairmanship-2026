"""Custom SMTP email backend that logs every outgoing email to EmailLog.

Swap the stock backend in settings.py via:

    EMAIL_BACKEND = 'core.email_backend.LoggingEmailBackend'

Every ``send_mail`` / ``EmailMessage.send()`` call in the project is
transparently captured (subject, recipients, status, error, body preview),
so the admin "Email Logs" page can show sent + failed mail without
touching Gmail.
"""
import re

from django.core.mail.backends.smtp import EmailBackend as SMTPEmailBackend

_OTP_RE = re.compile(r'\b\d{4,8}\b')
_PASSWORD_RE = re.compile(r'(Temporary Password:\s*)(\S+)', re.IGNORECASE)


def _categorize(subject: str) -> str:
    """Best-effort category tag based on the subject line."""
    s = (subject or '').lower()
    if s.startswith('[test]') or 'preview' in s:
        return 'test'
    if 'verification' in s or 'verify' in s or 'badge' in s:
        return 'verification'
    if 'otp' in s or 'code' in s or 'login' in s or 'reset' in s:
        return 'otp'
    if 'admin' in s and 'access' in s:
        return 'admin_invite'
    if 'event' in s or 'registration' in s or 'ticket' in s:
        return 'event'
    if 'support' in s or 'ticket' in s:
        return 'support'
    if 'welcome' in s or 'maintenance' in s or 'admin' in s:
        return 'system'
    return 'other'


def _body_preview(msg, redact: bool = False) -> str:
    """Extract a short body preview from an EmailMessage / EmailMultiAlternatives.

    When *redact* is True, credentials and OTP codes are replaced with
    ``[REDACTED]`` so the log never stores live secrets.
    """
    try:
        text = msg.body or ''
        # If multipart with HTML alt, prefer stripped HTML
        if hasattr(msg, 'alternatives') and msg.alternatives:
            for content, mimetype in msg.alternatives:
                if mimetype == 'text/html':
                    text = content
                    break
        preview = (text or '')[:500]
        if redact:
            preview = _OTP_RE.sub('[REDACTED]', preview)
            preview = _PASSWORD_RE.sub(r'\1[REDACTED]', preview)
        return preview
    except Exception:
        return ''


class LoggingEmailBackend(SMTPEmailBackend):
    """SMTP backend that writes an EmailLog row for every message."""

    def send_messages(self, email_messages):
        # Lazy import to avoid Django app-loading issues during startup.
        from core.models import EmailLog

        if not email_messages:
            return 0

        total_sent = 0
        for msg in email_messages:
            subject = getattr(msg, 'subject', '') or ''
            recipients = ', '.join(getattr(msg, 'to', []) or [])
            from_email = getattr(msg, 'from_email', '') or ''
            category = _categorize(subject)
            redact = category in ('otp', 'verification', 'admin_invite')
            body_preview = _body_preview(msg, redact=redact)

            try:
                sent = super().send_messages([msg]) or 0
                total_sent += sent
                status = 'sent' if sent else 'failed'
                error = '' if sent else 'send_messages returned 0'
            except Exception as exc:
                status = 'failed'
                error = str(exc)[:2000]

            try:
                EmailLog.objects.create(
                    subject=subject[:255],
                    recipients=recipients,
                    from_email=from_email[:255],
                    status=status,
                    error=error,
                    category=category,
                    body_preview=body_preview,
                )
            except Exception:
                # Logging must never break real mail delivery.
                pass

        return total_sent
