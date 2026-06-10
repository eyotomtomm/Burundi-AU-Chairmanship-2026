"""OTP utility functions for email verification"""
import logging
import secrets
import string
from datetime import timedelta
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from django.db.models import F as models_F
from .models import OTPVerification

logger = logging.getLogger(__name__)

MAX_OTP_ATTEMPTS = 5


def generate_otp(length=6):
    """Generate a cryptographically secure random OTP code"""
    return ''.join(secrets.choice(string.digits) for _ in range(length))


def send_email_otp(user, email):
    """
    Send OTP to email address.
    Returns (success, message, otp_id)
    """
    try:
        # Invalidate all previous unverified OTPs for this user+email
        OTPVerification.objects.filter(
            user=user, type='email', contact=email, is_verified=False
        ).update(is_verified=True)

        # Generate OTP
        otp_code = generate_otp()

        # Create OTP record
        otp = OTPVerification.objects.create(
            user=user,
            type='email',
            contact=email,
            otp_code=otp_code,
            expires_at=timezone.now() + timedelta(minutes=10)
        )

        # Build email content
        subject = 'Be 4 Africa - Email Verification OTP'
        message = (
            f'Hello {user.username},\n\n'
            f'Your email verification OTP code is: {otp_code}\n\n'
            f'This code will expire in 10 minutes.\n\n'
            f'If you did not request this code, please ignore this email.\n\n'
            f'Best regards,\n'
            f'Be 4 Africa Team'
        )

        # Verify email configuration before sending
        backend = getattr(settings, 'EMAIL_BACKEND', '')
        if 'console' in backend.lower():
            logger.warning(
                'EMAIL_BACKEND is set to console - OTP emails will only appear '
                'in the server log. Set EMAIL_BACKEND to '
                'django.core.mail.backends.smtp.EmailBackend for production.'
            )

        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', None)
        if not from_email:
            logger.error('DEFAULT_FROM_EMAIL is not configured')
            return False, 'Email sending is not configured. Please contact support.', None

        send_mail(
            subject,
            message,
            from_email,
            [email],
            fail_silently=False,
        )

        logger.info(f'OTP email sent to {email} for user {user.pk}')
        return True, 'OTP sent successfully', otp.id

    except ConnectionRefusedError:
        logger.error(
            'SMTP connection refused. Check EMAIL_HOST (%s) and EMAIL_PORT (%s).',
            getattr(settings, 'EMAIL_HOST', '(not set)'),
            getattr(settings, 'EMAIL_PORT', '(not set)'),
        )
        return False, 'Email server is unreachable. Please try again later or contact support.', None
    except Exception as e:
        logger.exception('Failed to send email OTP: %s', e)
        error_detail = str(e)
        if 'authentication' in error_detail.lower():
            return False, 'Email authentication failed. Please contact support.', None
        elif 'timed out' in error_detail.lower() or 'timeout' in error_detail.lower():
            return False, 'Email server timed out. Please try again later.', None
        elif 'ssl' in error_detail.lower() or 'certificate' in error_detail.lower():
            return False, 'Email SSL/TLS error. Please contact support.', None
        return False, 'Failed to send verification code. Please try again.', None


def verify_email_otp(user, email, otp_code):
    """
    Verify email OTP code with brute-force protection
    Returns (success, message)
    """
    try:
        otp = OTPVerification.objects.filter(
            user=user,
            type='email',
            contact=email,
            is_verified=False
        ).order_by('-created_at').first()

        if not otp:
            return False, 'No pending verification found. Please request a new code.'

        attempts = getattr(otp, 'attempts', 0)
        if attempts >= MAX_OTP_ATTEMPTS:
            otp.is_verified = True
            otp.save()
            return False, 'Too many failed attempts. Please request a new code.'

        if otp.is_expired():
            return False, 'OTP has expired. Please request a new one.'

        if otp.otp_code != otp_code:
            OTPVerification.objects.filter(pk=otp.pk).update(
                attempts=models_F('attempts') + 1
            )
            return False, 'Invalid OTP code'

        otp.is_verified = True
        otp.save()

        profile = user.profile
        profile.is_email_verified = True
        profile.email_verified_at = timezone.now()
        profile.save()

        return True, 'Email verified successfully'

    except Exception as e:
        logger.exception('Failed to verify email OTP')
        return False, 'Verification failed. Please try again.'
