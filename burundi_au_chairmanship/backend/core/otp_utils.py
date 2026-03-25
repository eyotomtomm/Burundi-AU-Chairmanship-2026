"""OTP utility functions for email and SMS verification"""
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
    Send OTP to email address
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

        # Send email
        subject = 'Burundi AU Chairmanship - Email Verification OTP'
        message = f'''
Hello {user.username},

Your email verification OTP code is: {otp_code}

This code will expire in 10 minutes.

If you did not request this code, please ignore this email.

Best regards,
Burundi AU Chairmanship Team
        '''

        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )

        return True, 'OTP sent successfully', otp.id

    except Exception as e:
        logger.exception('Failed to send email OTP')
        return False, 'Failed to send verification code. Please try again.', None


def verify_email_otp(user, email, otp_code):
    """
    Verify email OTP code with brute-force protection
    Returns (success, message)
    """
    try:
        # Get the most recent unverified OTP for this email
        otp = OTPVerification.objects.filter(
            user=user,
            type='email',
            contact=email,
            is_verified=False
        ).order_by('-created_at').first()

        if not otp:
            return False, 'No pending verification found. Please request a new code.'

        # Check brute-force attempts
        attempts = getattr(otp, 'attempts', 0)
        if attempts >= MAX_OTP_ATTEMPTS:
            otp.is_verified = True  # Invalidate it
            otp.save()
            return False, 'Too many failed attempts. Please request a new code.'

        if otp.is_expired():
            return False, 'OTP has expired. Please request a new one.'

        if otp.otp_code != otp_code:
            # Increment attempt counter
            OTPVerification.objects.filter(pk=otp.pk).update(
                attempts=models_F('attempts') + 1
            )
            return False, 'Invalid OTP code'

        # Mark as verified
        otp.is_verified = True
        otp.save()

        # Update user profile
        profile = user.profile
        profile.is_email_verified = True
        profile.email_verified_at = timezone.now()
        profile.save()

        return True, 'Email verified successfully'

    except Exception as e:
        logger.exception('Failed to verify email OTP')
        return False, 'Verification failed. Please try again.'


def send_phone_otp_twilio(user, country_code, phone_number, channel='sms'):
    """
    Send OTP via Twilio Verify Service (or fallback to SMS).
    channel: 'sms' or 'whatsapp'
    Returns (success, message, otp_id)
    """
    try:
        full_phone = f"{country_code}{phone_number}"

        # Invalidate all previous unverified OTPs for this user+phone
        OTPVerification.objects.filter(
            user=user, type='phone', contact=full_phone, is_verified=False
        ).update(is_verified=True)

        # Check if Twilio is configured
        if not hasattr(settings, 'TWILIO_ACCOUNT_SID') or not settings.TWILIO_ACCOUNT_SID:
            return False, 'SMS verification is not configured. Please contact administrator.', None

        # Import Twilio (optional dependency)
        try:
            from twilio.rest import Client
        except ImportError:
            return False, 'Twilio library not installed. Please contact administrator.', None

        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

        # Validate channel
        if channel not in ('sms', 'whatsapp'):
            channel = 'sms'

        # Use Twilio Verify if Service SID is configured (recommended)
        # Twilio Verify supports both 'sms' and 'whatsapp' channels
        if hasattr(settings, 'TWILIO_VERIFY_SERVICE_SID') and settings.TWILIO_VERIFY_SERVICE_SID:
            try:
                verification = client.verify.v2.services(
                    settings.TWILIO_VERIFY_SERVICE_SID
                ).verifications.create(
                    to=full_phone,
                    channel=channel  # 'sms' or 'whatsapp'
                )

                # Create OTP record for tracking (Twilio manages the actual code)
                otp = OTPVerification.objects.create(
                    user=user,
                    type='phone',
                    contact=full_phone,
                    otp_code='TWILIO_VERIFY',
                    expires_at=timezone.now() + timedelta(minutes=10)
                )

                channel_label = 'WhatsApp' if channel == 'whatsapp' else 'SMS'
                return True, f'OTP sent via {channel_label}', otp.id

            except Exception as verify_error:
                logger.warning('Twilio Verify failed (%s), falling back to manual SMS: %s', channel, verify_error)
                # WhatsApp only works via Verify — no fallback possible
                if channel == 'whatsapp':
                    return False, 'WhatsApp delivery failed. Please try SMS instead.', None

        # Fallback: Manual SMS with Alphanumeric Sender ID or Phone Number
        otp_code = generate_otp()

        otp = OTPVerification.objects.create(
            user=user,
            type='phone',
            contact=full_phone,
            otp_code=otp_code,
            expires_at=timezone.now() + timedelta(minutes=10)
        )

        # Determine sender (Alphanumeric Sender ID or Phone Number)
        sender = None
        if hasattr(settings, 'TWILIO_SENDER_ID') and settings.TWILIO_SENDER_ID:
            sender = settings.TWILIO_SENDER_ID
        elif hasattr(settings, 'TWILIO_PHONE_NUMBER') and settings.TWILIO_PHONE_NUMBER:
            sender = settings.TWILIO_PHONE_NUMBER
        else:
            return False, 'No sender configured. Please set TWILIO_SENDER_ID or TWILIO_PHONE_NUMBER in settings.', None

        client.messages.create(
            body=f'Your Burundi AU Chairmanship verification code is: {otp_code}. Valid for 10 minutes.',
            from_=sender,
            to=full_phone
        )

        return True, 'OTP sent via SMS', otp.id

    except Exception as e:
        logger.exception('Failed to send phone OTP')
        return False, 'Failed to send verification code. Please try again.', None


def verify_phone_otp(user, country_code, phone_number, otp_code):
    """
    Verify phone OTP code with brute-force protection.
    On success, marks user profile phone_verified=True.
    Returns (success, message)
    """
    try:
        from django.conf import settings
        full_phone = f"{country_code}{phone_number}"

        # Get the most recent OTP for this phone
        otp = OTPVerification.objects.filter(
            user=user,
            type='phone',
            contact=full_phone,
            is_verified=False
        ).order_by('-created_at').first()

        if not otp:
            return False, 'No pending verification found. Please request a new code.'

        # Check brute-force attempts
        attempts = getattr(otp, 'attempts', 0)
        if attempts >= MAX_OTP_ATTEMPTS:
            otp.is_verified = True
            otp.save()
            return False, 'Too many failed attempts. Please request a new code.'

        # If using Twilio Verify Service
        if otp.otp_code == 'TWILIO_VERIFY':
            try:
                from twilio.rest import Client
                client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

                verification_check = client.verify.v2.services(
                    settings.TWILIO_VERIFY_SERVICE_SID
                ).verification_checks.create(
                    to=full_phone,
                    code=otp_code
                )

                if verification_check.status == 'approved':
                    otp.is_verified = True
                    otp.save()
                    _mark_phone_verified(user, country_code, phone_number)
                    return True, 'Phone number verified successfully'
                else:
                    OTPVerification.objects.filter(pk=otp.pk).update(
                        attempts=models_F('attempts') + 1
                    )
                    return False, 'Invalid OTP code'

            except Exception as e:
                logger.exception('Twilio verification failed')
                return False, 'Verification failed. Please try again.'

        # Manual verification
        if otp.is_expired():
            return False, 'OTP has expired. Please request a new one.'

        if otp.otp_code != otp_code:
            OTPVerification.objects.filter(pk=otp.pk).update(
                attempts=models_F('attempts') + 1
            )
            return False, 'Invalid OTP code'

        # Mark as verified
        otp.is_verified = True
        otp.save()

        _mark_phone_verified(user, country_code, phone_number)
        return True, 'Phone number verified successfully'

    except Exception as e:
        logger.exception('Failed to verify phone OTP')
        return False, 'Verification failed. Please try again.'


def _mark_phone_verified(user, country_code, phone_number):
    """Update user profile with verified phone number."""
    try:
        profile = user.profile
        profile.phone_verified = True
        profile.country_code = country_code
        profile.phone_number = phone_number
        profile.save(update_fields=['phone_verified', 'country_code', 'phone_number'])
    except Exception:
        logger.exception('Failed to update phone_verified on profile')
