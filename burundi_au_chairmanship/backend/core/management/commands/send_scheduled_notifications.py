"""
Management command to send scheduled and recurring push notifications.

Handles:
- One-time scheduled notifications (scheduled_at has passed, not yet sent)
- Daily recurring notifications (checked against schedule_time)
- Weekly recurring notifications (checked against schedule_day + schedule_time)

Usage:
    python manage.py send_scheduled_notifications

Recommended: Run via cron every minute:
    * * * * * cd /path/to/backend && python manage.py send_scheduled_notifications
"""

import logging
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Send scheduled and recurring push notifications that are due.'

    def handle(self, *args, **options):
        from core.models import Notification
        from core.push_service import send_push_notification

        now = timezone.now()
        total_sent = 0

        # 1. One-time scheduled notifications (backward compatible)
        pending_onetime = Notification.objects.filter(
            scheduled_at__lte=now,
            push_sent=False,
            is_active=True,
        ).exclude(scheduled_at__isnull=True).exclude(
            is_scheduled=True, schedule_type__in=['daily', 'weekly']
        )

        for notification in pending_onetime:
            try:
                success, failure = send_push_notification(notification)
                total_sent += 1
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Sent one-time notification "{notification.title}" '
                        f'to {success} devices ({failure} failed)'
                    )
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(
                        f'Failed to send notification #{notification.pk}: {e}'
                    )
                )

        # 2. Daily recurring notifications
        daily_due = Notification.objects.filter(
            is_scheduled=True,
            schedule_type='daily',
            is_active=True,
            schedule_time__isnull=False,
        )

        for notification in daily_due:
            if self._is_daily_due(notification, now):
                try:
                    # Reset push_sent so send_push_notification works
                    notification.push_sent = False
                    notification.save(update_fields=['push_sent'])

                    success, failure = send_push_notification(notification)
                    notification.last_scheduled_send = now
                    notification.save(update_fields=['last_scheduled_send'])
                    total_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Sent daily notification "{notification.title}" '
                            f'to {success} devices ({failure} failed)'
                        )
                    )
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(
                            f'Failed to send daily notification #{notification.pk}: {e}'
                        )
                    )

        # 3. Weekly recurring notifications
        weekly_due = Notification.objects.filter(
            is_scheduled=True,
            schedule_type='weekly',
            is_active=True,
            schedule_time__isnull=False,
            schedule_day__isnull=False,
        )

        for notification in weekly_due:
            if self._is_weekly_due(notification, now):
                try:
                    notification.push_sent = False
                    notification.save(update_fields=['push_sent'])

                    success, failure = send_push_notification(notification)
                    notification.last_scheduled_send = now
                    notification.save(update_fields=['last_scheduled_send'])
                    total_sent += 1
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Sent weekly notification "{notification.title}" '
                            f'to {success} devices ({failure} failed)'
                        )
                    )
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(
                            f'Failed to send weekly notification #{notification.pk}: {e}'
                        )
                    )

        if total_sent:
            self.stdout.write(
                self.style.SUCCESS(f'Total: {total_sent} scheduled notifications sent')
            )
        else:
            self.stdout.write('No scheduled notifications due at this time.')

    def _is_daily_due(self, notification, now):
        """Check if a daily notification should be sent now."""
        current_time = now.time()
        schedule_time = notification.schedule_time

        # Check if we're within a 2-minute window of the scheduled time
        # (to handle cron running every minute)
        from datetime import datetime, date
        scheduled_dt = datetime.combine(date.today(), schedule_time)
        current_dt = datetime.combine(date.today(), current_time)
        diff = abs((current_dt - scheduled_dt).total_seconds())

        if diff > 120:  # Not within the 2-minute window
            return False

        # Check that we haven't already sent today
        if notification.last_scheduled_send:
            last_send_date = notification.last_scheduled_send.date()
            if last_send_date == now.date():
                return False  # Already sent today

        return True

    def _is_weekly_due(self, notification, now):
        """Check if a weekly notification should be sent now."""
        # Check if today is the correct day of week (0=Monday in Python)
        if now.weekday() != notification.schedule_day:
            return False

        # Use the same time-window logic as daily
        return self._is_daily_due(notification, now)
