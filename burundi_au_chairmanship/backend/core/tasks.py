"""
Celery background tasks for async processing.

Tasks:
  - Email sending (OTP, notifications, reports)
  - Push notifications (FCM batch sending)
  - Account cleanup (expired OTPs, deactivated accounts)
  - Report generation (weekly analytics PDF)
  - Image optimization (WebP thumbnail generation)
"""
import logging
from celery import shared_task
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_email_async(self, subject, message, from_email, recipient_list, html_message=None):
    """Send email asynchronously with retry logic."""
    try:
        from django.core.mail import send_mail
        send_mail(
            subject=subject,
            message=message,
            from_email=from_email,
            recipient_list=recipient_list,
            html_message=html_message,
            fail_silently=False,
        )
        logger.info(f"Email sent to {recipient_list}")
    except Exception as exc:
        logger.error(f"Email send failed: {exc}")
        raise self.retry(exc=exc)


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_push_notification_async(self, user_ids, title, body, data=None):
    """Send FCM push notifications in batch."""
    try:
        from .models import UserProfile
        import firebase_admin.messaging as messaging

        profiles = UserProfile.objects.filter(
            user_id__in=user_ids,
            fcm_token__isnull=False,
        ).exclude(fcm_token='')

        tokens = list(profiles.values_list('fcm_token', flat=True))
        if not tokens:
            return

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
        )
        response = messaging.send_each_for_multicast(message)
        logger.info(f"Push sent: {response.success_count} success, {response.failure_count} failed")
    except Exception as exc:
        logger.error(f"Push notification failed: {exc}")
        raise self.retry(exc=exc)


@shared_task
def cleanup_expired_otps():
    """Remove OTP records older than 10 minutes."""
    from .models import OTPVerification
    cutoff = timezone.now() - timedelta(minutes=10)
    deleted, _ = OTPVerification.objects.filter(created_at__lt=cutoff).delete()
    logger.info(f"Cleaned up {deleted} expired OTPs")


@shared_task
def cleanup_deactivated_accounts():
    """Permanently delete accounts deactivated for 30+ days."""
    from .models import UserProfile
    cutoff = timezone.now() - timedelta(days=30)
    profiles = UserProfile.objects.filter(
        is_deactivated=True,
        deactivated_at__lt=cutoff,
    )
    count = profiles.count()
    for profile in profiles:
        user = profile.user
        user.delete()  # Cascade deletes profile
    logger.info(f"Permanently deleted {count} deactivated accounts")


@shared_task
def generate_weekly_report():
    """Generate weekly analytics report."""
    from .models import Article, Event, UserProfile
    from django.contrib.auth.models import User

    now = timezone.now()
    week_ago = now - timedelta(days=7)

    stats = {
        'new_users': User.objects.filter(date_joined__gte=week_ago).count(),
        'new_articles': Article.objects.filter(created_at__gte=week_ago).count(),
        'upcoming_events': Event.objects.filter(start_date__gte=now).count(),
        'total_users': User.objects.filter(is_active=True).count(),
    }
    logger.info(f"Weekly report: {stats}")
    return stats


@shared_task(bind=True, max_retries=2, default_retry_delay=30)
def optimize_image_async(self, image_path):
    """Generate WebP thumbnails at multiple sizes."""
    try:
        from PIL import Image
        from pathlib import Path
        import os

        path = Path(image_path)
        if not path.exists():
            logger.warning(f"Image not found: {image_path}")
            return

        sizes = {'thumb': 300, 'medium': 600, 'large': 1200}
        img = Image.open(path)

        for suffix, max_size in sizes.items():
            ratio = min(max_size / img.width, max_size / img.height)
            if ratio >= 1:
                continue  # Skip if image is already smaller

            new_size = (int(img.width * ratio), int(img.height * ratio))
            resized = img.resize(new_size, Image.LANCZOS)

            output_name = f"{path.stem}_{suffix}.webp"
            output_path = path.parent / output_name
            resized.save(output_path, 'WEBP', quality=85)
            logger.info(f"Generated {suffix} thumbnail: {output_path}")

    except Exception as exc:
        logger.error(f"Image optimization failed: {exc}")
        raise self.retry(exc=exc)
