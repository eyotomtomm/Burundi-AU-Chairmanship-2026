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
        from .models import UserProfile, DeviceToken
        from config.firebase import initialize_firebase
        initialize_firebase()
        import firebase_admin.messaging as messaging

        # Collect tokens from both DeviceToken (preferred) and legacy UserProfile
        device_tokens = list(
            DeviceToken.objects.filter(
                user_id__in=user_ids,
                is_active=True,
            ).values_list('token', flat=True).distinct()
        )
        legacy_tokens = list(
            UserProfile.objects.filter(
                user_id__in=user_ids,
                fcm_token__isnull=False,
            ).exclude(fcm_token='').values_list('fcm_token', flat=True)
        )
        tokens = list(set(device_tokens + [t for t in legacy_tokens if t]))
        if not tokens:
            return

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='default_channel',
                    priority='max',
                    default_sound=True,
                    default_vibrate_timings=True,
                ),
            ),
            apns=messaging.APNSConfig(
                headers={'apns-priority': '10'},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                    ),
                ),
            ),
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
    """Permanently delete accounts whose deletion grace period has expired.

    Paused ("Take a Break", is_deactivated=True) accounts are never deleted here;
    only accounts the user explicitly scheduled for deletion. Reuses the
    purge_deleted_accounts command so Firebase Auth cleanup stays in one place.
    """
    from django.core.management import call_command
    call_command('purge_deleted_accounts')


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
        'upcoming_events': Event.objects.filter(event_date__gte=now).count(),
        'total_users': User.objects.filter(is_active=True).count(),
    }
    logger.info(f"Weekly report: {stats}")
    return stats


@shared_task
def send_scheduled_notifications():
    """Send scheduled and recurring notifications.
    Runs every minute via CELERY_BEAT_SCHEDULE.

    Handles:
    - One-time scheduled notifications (scheduled_at has passed, not yet sent)
    - Daily recurring notifications (is_scheduled=True, schedule_type='daily')
    - Weekly recurring notifications (is_scheduled=True, schedule_type='weekly')
    """
    from .models import Notification
    from .push_service import send_push_notification
    from datetime import datetime

    now = timezone.now()
    # schedule_time / schedule_day are entered by admins in local (TIME_ZONE)
    # terms, so compare against local wall-clock time, not UTC.
    local_now = timezone.localtime(now)
    sent_count = 0

    def _due_now(notification, local_now):
        scheduled_dt = datetime.combine(local_now.date(), notification.schedule_time)
        current_dt = datetime.combine(local_now.date(), local_now.time())
        if abs((current_dt - scheduled_dt).total_seconds()) > 120:
            return False
        last = notification.last_scheduled_send
        return not (last and timezone.localtime(last).date() == local_now.date())

    # 1. One-time scheduled notifications
    pending = Notification.objects.filter(
        scheduled_at__lte=now,
        push_sent=False,
        is_active=True,
    ).exclude(scheduled_at__isnull=True).exclude(
        is_scheduled=True, schedule_type__in=['daily', 'weekly']
    )

    for notification in pending:
        try:
            success, failure = send_push_notification(notification)
            sent_count += 1
            logger.info(f"Scheduled notification '{notification.title}' sent to {success} devices")
        except Exception as e:
            logger.error(f"Failed to send scheduled notification {notification.id}: {e}")

    # 2. Daily recurring notifications
    daily_notifications = Notification.objects.filter(
        is_scheduled=True,
        schedule_type='daily',
        is_active=True,
        schedule_time__isnull=False,
    )

    for notification in daily_notifications:
        if not _due_now(notification, local_now):
            continue

        try:
            notification.push_sent = False
            notification.save(update_fields=['push_sent'])
            success, failure = send_push_notification(notification)
            notification.last_scheduled_send = now
            notification.save(update_fields=['last_scheduled_send'])
            sent_count += 1
            logger.info(f"Daily notification '{notification.title}' sent to {success} devices")
        except Exception as e:
            logger.error(f"Failed to send daily notification {notification.id}: {e}")

    # 3. Weekly recurring notifications
    weekly_notifications = Notification.objects.filter(
        is_scheduled=True,
        schedule_type='weekly',
        is_active=True,
        schedule_time__isnull=False,
        schedule_day__isnull=False,
    )

    for notification in weekly_notifications:
        if local_now.weekday() != notification.schedule_day:
            continue
        if not _due_now(notification, local_now):
            continue

        try:
            notification.push_sent = False
            notification.save(update_fields=['push_sent'])
            success, failure = send_push_notification(notification)
            notification.last_scheduled_send = now
            notification.save(update_fields=['last_scheduled_send'])
            sent_count += 1
            logger.info(f"Weekly notification '{notification.title}' sent to {success} devices")
        except Exception as e:
            logger.error(f"Failed to send weekly notification {notification.id}: {e}")

    if sent_count:
        logger.info(f"Processed {sent_count} scheduled notifications")
    return sent_count


@shared_task
def send_weekly_newsletter():
    """Collect articles/events from the past/upcoming week and email subscribers."""
    from .models import Article, Event, UserProfile, NewsletterEdition, EmailTemplate
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
    <p>Stay connected with the Be 4 Africa.</p>
    """

    subject = f"Be 4 Africa - Weekly Digest ({now.strftime('%b %d, %Y')})"

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

    # Record the edition first, then send in chunks; each chunk marks itself
    # done on the edition so a Celery retry never re-sends the same batch.
    edition = NewsletterEdition.objects.create(subject=subject, body_html=body_html, sent_at=now)
    user_pks = [p.user.pk for p in subscribers if p.user.email]
    for index, i in enumerate(range(0, len(user_pks), CAMPAIGN_CHUNK_SIZE)):
        send_newsletter_chunk.delay(edition.pk, index, user_pks[i:i + CAMPAIGN_CHUNK_SIZE])
    logger.info(f"Weekly newsletter {edition.pk} queued for {len(user_pks)} subscribers")
    return len(user_pks)


@shared_task(bind=True, max_retries=3, default_retry_delay=120)
def send_newsletter_chunk(self, edition_id, chunk_index, user_pks):
    from django.contrib.auth.models import User
    from django.core import signing
    from django.core.mail import EmailMessage, get_connection
    from django.conf import settings as django_settings
    from django.db.models import F
    from .models import NewsletterEdition

    edition = NewsletterEdition.objects.get(pk=edition_id)
    if chunk_index in (edition.sent_chunks or []):
        return 0  # already delivered by an earlier attempt

    site_url = getattr(django_settings, 'SITE_URL', 'https://burundi4africa.com').rstrip('/')
    footer = (
        '<hr style="margin:32px 0 16px;border:none;border-top:1px solid #e0e0e0">'
        '<p style="font-size:12px;color:#888;text-align:center">'
        'You received this because you subscribed to the Be 4 Africa weekly newsletter. '
        '<a href="{unsub_url}" style="color:#1976d2">Unsubscribe</a></p>'
    )
    sent = 0
    connection = get_connection()
    try:
        connection.open()
    except Exception as exc:
        raise self.retry(exc=exc)
    try:
        for user in User.objects.filter(pk__in=user_pks, is_active=True).exclude(email=''):
            unsub_url = f"{site_url}/api/newsletter/unsubscribe/{signing.dumps(user.pk)}/"
            msg = EmailMessage(
                subject=edition.subject,
                body=edition.body_html + footer.format(unsub_url=unsub_url),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                to=[user.email],
                connection=connection,
            )
            msg.content_subtype = 'html'
            try:
                sent += msg.send(fail_silently=False)
            except Exception as e:
                logger.error(f"Newsletter send failed for {user.email}: {e}")
    finally:
        try:
            connection.close()
        except Exception:
            pass

    NewsletterEdition.objects.filter(pk=edition_id).update(recipient_count=F('recipient_count') + sent)
    # Append via a fresh read so two chunks finishing together don't clobber each other.
    from django.db import transaction
    with transaction.atomic():
        e = NewsletterEdition.objects.select_for_update().get(pk=edition_id)
        chunks = list(e.sent_chunks or [])
        if chunk_index not in chunks:
            chunks.append(chunk_index)
            e.sent_chunks = chunks
            e.save(update_fields=['sent_chunks'])
    return sent


def _parse_duration(text):
    """'1h 30m' / '90m' / '2h' -> timedelta, or None when unparseable."""
    import re
    hours = re.search(r'(\d+)\s*h', text or '', re.I)
    mins = re.search(r'(\d+)\s*m', text or '', re.I)
    if not hours and not mins:
        return None
    return timedelta(hours=int(hours.group(1)) if hours else 0,
                     minutes=int(mins.group(1)) if mins else 0)


@shared_task
def transition_live_feed_statuses():
    """upcoming -> live at scheduled_time; live -> recorded once scheduled_time + duration passes.

    LiveFeed has no end_time; ``duration`` is free text. Feeds whose duration
    cannot be parsed stay 'live' until an admin marks them recorded.
    """
    from .models import LiveFeed
    now = timezone.now()
    went_live = LiveFeed.objects.filter(
        status='upcoming',
        scheduled_time__lte=now,
    ).update(status='live')
    ended = 0
    for feed in LiveFeed.objects.filter(status='live', scheduled_time__isnull=False).only('id', 'scheduled_time', 'duration'):
        length = _parse_duration(feed.duration)
        if length and feed.scheduled_time + length <= now:
            ended += LiveFeed.objects.filter(pk=feed.pk, status='live').update(status='recorded')
    if went_live or ended:
        logger.info(f"Live feeds: {went_live} went live, {ended} ended")
    return went_live + ended


@shared_task
def publish_scheduled_content():
    """Beat wrapper for `manage.py publish_scheduled` (runs every minute)."""
    from django.core.management import call_command
    call_command('publish_scheduled')


@shared_task
def promote_waitlist_task():
    """Beat wrapper for `manage.py promote_waitlist` (runs every minute)."""
    from django.core.management import call_command
    call_command('promote_waitlist')


@shared_task
def purge_old_user_sessions():
    """Drop analytics UserSession rows older than 90 days."""
    from .models import UserSession
    deleted, _ = UserSession.objects.filter(created_at__lt=timezone.now() - timedelta(days=90)).delete()
    logger.info(f"Purged {deleted} UserSession rows")
    return deleted


@shared_task
def send_sms_broadcast(title, message):
    """Background wrapper for the (stub) SMS fan-out."""
    from .utils import send_sms_to_enabled_users
    return send_sms_to_enabled_users(title, message)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_yd_applicant_email_async(self, application_id, subject, heading, badge_color, body_html, lang='en'):
    """Send the branded Continental Dialogue applicant email off the request thread."""
    from .models import YouthDialogueApplication
    from .views import _send_yd_applicant_email
    try:
        application = YouthDialogueApplication.objects.select_related('event').get(pk=application_id)
    except YouthDialogueApplication.DoesNotExist:
        return
    try:
        _send_yd_applicant_email(application, subject, heading, badge_color, body_html, lang=lang)
    except Exception as exc:
        raise self.retry(exc=exc)


CAMPAIGN_CHUNK_SIZE = 200


@shared_task
def send_email_campaign(campaign_id):
    """Fan an EmailCampaign out into <=200-recipient chunks, one SMTP connection each."""
    from .models import EmailCampaign
    from custom_admin.email_views import _campaign_audience_queryset
    campaign = EmailCampaign.objects.get(pk=campaign_id)
    recipients = _campaign_audience_queryset(campaign)
    if not recipients:
        EmailCampaign.objects.filter(pk=campaign_id).update(status='failed', last_error='No recipients resolved')
        return 0
    EmailCampaign.objects.filter(pk=campaign_id).update(
        status='sending', recipient_count=len(recipients), sent_count=0, failed_count=0, last_error='')
    for i in range(0, len(recipients), CAMPAIGN_CHUNK_SIZE):
        send_email_campaign_chunk.delay(campaign_id, recipients[i:i + CAMPAIGN_CHUNK_SIZE])
    return len(recipients)


@shared_task(bind=True, max_retries=2, default_retry_delay=120)
def send_email_campaign_chunk(self, campaign_id, recipients):
    import re as _re
    from django.conf import settings as django_settings
    from django.core.mail import EmailMultiAlternatives
    from django.db import transaction
    from django.db.models import F
    from .models import EmailCampaign, EmailLog
    from custom_admin.email_views import _get_campaign_smtp_connection, _wrap_campaign_html

    campaign = EmailCampaign.objects.get(pk=campaign_id)

    def _render(tpl, ctx):
        out = tpl
        for k, v in ctx.items():
            out = _re.sub(r'\{\{\s*' + k + r'\s*\}\}', str(v), out)
        return out

    sent_ok = sent_fail = 0
    last_error = ''
    connection = _get_campaign_smtp_connection()
    try:
        connection.open()
    except Exception as exc:
        raise self.retry(exc=exc)
    try:
        for email, name in recipients:
            user_name = name or email.split('@')[0]
            ctx = {'user_name': user_name, 'user_email': email, 'app_name': 'Be 4 Africa'}
            raw_body = _render(campaign.body_html, ctx)
            try:
                msg = EmailMultiAlternatives(
                    subject=_render(campaign.subject, ctx),
                    body=f'Hello {user_name},\n\n{raw_body[:500]}\n\n-- Be 4 Africa | Burundi AU Chairmanship',
                    from_email=django_settings.CAMPAIGN_FROM_EMAIL,
                    to=[email],
                    connection=connection,
                )
                msg.attach_alternative(_wrap_campaign_html(raw_body, user_name=user_name), 'text/html')
                msg.send(fail_silently=False)
                sent_ok += 1
                latest = EmailLog.objects.filter(recipients=email).order_by('-created_at').first()
                if latest and latest.campaign_id is None:
                    latest.campaign = campaign
                    latest.category = 'campaign'
                    latest.save(update_fields=['campaign', 'category'])
            except Exception as e:
                sent_fail += 1
                last_error = str(e)[:2000]
    finally:
        try:
            connection.close()
        except Exception:
            pass

    with transaction.atomic():
        c = EmailCampaign.objects.select_for_update().get(pk=campaign_id)
        c.sent_count = F('sent_count') + sent_ok
        c.failed_count = F('failed_count') + sent_fail
        if last_error:
            c.last_error = last_error
        c.save(update_fields=['sent_count', 'failed_count', 'last_error'])
        c.refresh_from_db()
        if c.sent_count + c.failed_count >= c.recipient_count:
            c.status = 'failed' if c.sent_count == 0 else 'sent'
            c.sent_at = timezone.now()
            c.save(update_fields=['status', 'sent_at'])
    return sent_ok, sent_fail


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_notification_push_async(self, notification_id):
    """Send push for a Notification model instance in the background."""
    from .models import Notification
    from .push_service import send_push_notification
    try:
        notification = Notification.objects.get(pk=notification_id)
    except Notification.DoesNotExist:
        logger.error(f"Notification {notification_id} not found, skipping push")
        return 0, 0
    try:
        success, failure = send_push_notification(notification)
        logger.info(f"Async push for notification {notification_id}: {success} sent, {failure} failed")
        return success, failure
    except Exception as exc:
        logger.error(f"Async push failed for notification {notification_id}: {exc}")
        raise self.retry(exc=exc)


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
