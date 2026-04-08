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


@shared_task
def send_scheduled_notifications():
    """Send scheduled notifications whose scheduled_at time has passed.
    Runs every minute via CELERY_BEAT_SCHEDULE."""
    from .models import Notification, UserProfile
    now = timezone.now()

    pending = Notification.objects.filter(
        scheduled_at__lte=now,
        push_sent=False,
        is_active=True,
    ).exclude(scheduled_at__isnull=True)

    sent_count = 0
    for notification in pending:
        try:
            from .push_service import send_push_notification
            success, failure = send_push_notification(notification)
            notification.push_sent = True
            notification.push_sent_at = now
            notification.push_recipient_count = success
            notification.save(update_fields=['push_sent', 'push_sent_at', 'push_recipient_count'])
            sent_count += 1
            logger.info(f"Scheduled notification '{notification.title}' sent to {success} devices")
        except Exception as e:
            logger.error(f"Failed to send scheduled notification {notification.id}: {e}")

    if sent_count:
        logger.info(f"Processed {sent_count} scheduled notifications")
    return sent_count


@shared_task
def send_weekly_newsletter():
    """Collect articles/events from the past/upcoming week and email subscribers."""
    from .models import Article, Event, UserProfile, NewsletterEdition, EmailTemplate
    from django.core.mail import send_mass_mail
    from django.template import Template, Context

    now = timezone.now()
    week_ago = now - timedelta(days=7)
    week_ahead = now + timedelta(days=7)

    # Collect recent content
    recent_articles = Article.objects.filter(
        publish_date__gte=week_ago
    ).order_by('-publish_date')[:10]

    upcoming_events = Event.objects.filter(
        event_date__gte=now,
        event_date__lte=week_ahead,
        is_active=True,
    ).order_by('event_date')[:10]

    if not recent_articles.exists() and not upcoming_events.exists():
        logger.info("No content for weekly newsletter, skipping")
        return 0

    # Build HTML body
    articles_html = ""
    for article in recent_articles:
        articles_html += f"<li><strong>{article.title}</strong> - {article.author}</li>\n"

    events_html = ""
    for event in upcoming_events:
        events_html += f"<li><strong>{event.name}</strong> - {event.event_date.strftime('%b %d, %Y')}</li>\n"

    body_html = f"""
    <h2>This Week's Highlights</h2>
    {'<h3>Recent Articles</h3><ul>' + articles_html + '</ul>' if articles_html else ''}
    {'<h3>Upcoming Events</h3><ul>' + events_html + '</ul>' if events_html else ''}
    <p>Stay connected with the Burundi AU Chairmanship.</p>
    """

    subject = f"Burundi AU Chairmanship - Weekly Digest ({now.strftime('%b %d, %Y')})"

    # Get subscribers
    subscribers = UserProfile.objects.filter(
        receives_newsletter=True,
        user__is_active=True,
    ).select_related('user').exclude(user__email='')

    recipient_emails = [p.user.email for p in subscribers if p.user.email]

    if not recipient_emails:
        logger.info("No newsletter subscribers found")
        return 0

    # Try to use the 'newsletter' EmailTemplate if it exists
    try:
        template = EmailTemplate.objects.get(key='newsletter', is_active=True)
        tmpl = Template(template.body_html)
        body_html = tmpl.render(Context({
            'articles': recent_articles,
            'events': upcoming_events,
            'articles_html': articles_html,
            'events_html': events_html,
        }))
        subject = template.subject or subject
    except EmailTemplate.DoesNotExist:
        pass  # Use default body_html built above

    # Send emails in batch
    from django.core.mail import EmailMessage
    from django.conf import settings as django_settings

    sent = 0
    batch_size = 50
    for i in range(0, len(recipient_emails), batch_size):
        batch = recipient_emails[i:i + batch_size]
        for email_addr in batch:
            try:
                msg = EmailMessage(
                    subject=subject,
                    body=body_html,
                    from_email=django_settings.DEFAULT_FROM_EMAIL,
                    to=[email_addr],
                )
                msg.content_subtype = 'html'
                msg.send(fail_silently=True)
                sent += 1
            except Exception as e:
                logger.error(f"Newsletter send failed for {email_addr}: {e}")

    # Record the edition
    NewsletterEdition.objects.create(
        subject=subject,
        body_html=body_html,
        sent_at=now,
        recipient_count=sent,
    )

    logger.info(f"Weekly newsletter sent to {sent}/{len(recipient_emails)} subscribers")
    return sent


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
