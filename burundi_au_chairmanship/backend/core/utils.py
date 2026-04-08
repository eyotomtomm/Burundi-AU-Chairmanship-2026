"""
Utility functions for the Burundi AU Chairmanship app.
"""

import logging

logger = logging.getLogger(__name__)


def send_sms(phone_number, message):
    """
    Stub SMS sending function.

    Logs the message instead of actually sending it.
    To integrate with a real SMS provider (e.g., Twilio, Africa's Talking),
    replace this stub with actual API calls and configure the provider's
    API keys in settings.

    Args:
        phone_number (str): The recipient's phone number (e.g., '+25779000000')
        message (str): The SMS message text (max ~160 chars for single SMS)

    Returns:
        bool: True if the SMS was "sent" (logged) successfully
    """
    if not phone_number or not message:
        logger.warning('SMS send failed: missing phone_number or message')
        return False

    # Validate phone number format (basic check)
    clean_number = phone_number.strip().replace(' ', '').replace('-', '')
    if not clean_number.startswith('+') or len(clean_number) < 8:
        logger.warning(f'SMS send failed: invalid phone number format: {phone_number}')
        return False

    # Log the SMS instead of actually sending
    logger.info(
        f'[SMS STUB] To: {phone_number} | Message: {message[:100]}'
        f'{"..." if len(message) > 100 else ""}'
    )

    # TODO: Replace with actual SMS provider integration
    # Example with Twilio:
    # from twilio.rest import Client
    # client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    # client.messages.create(
    #     body=message,
    #     from_=settings.TWILIO_PHONE_NUMBER,
    #     to=phone_number,
    # )

    return True


def send_sms_to_enabled_users(title, message):
    """
    Send SMS to all users with sms_enabled=True and a valid phone number.

    Args:
        title (str): The notification title (prepended to message)
        message (str): The notification message body

    Returns:
        tuple: (success_count, failure_count)
    """
    from core.models import UserProfile

    profiles = UserProfile.objects.filter(
        sms_enabled=True,
        user__is_active=True,
    ).exclude(
        phone_number=''
    ).exclude(
        phone_number__isnull=True
    )

    success_count = 0
    failure_count = 0

    sms_text = f"{title}: {message}"
    # Truncate to ~160 chars for a single SMS
    if len(sms_text) > 160:
        sms_text = sms_text[:157] + '...'

    for profile in profiles:
        if send_sms(profile.phone_number, sms_text):
            success_count += 1
        else:
            failure_count += 1

    logger.info(
        f'SMS batch send complete: {success_count} sent, {failure_count} failed '
        f'(out of {profiles.count()} eligible users)'
    )

    return success_count, failure_count
