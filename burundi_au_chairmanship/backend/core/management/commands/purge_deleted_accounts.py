"""
Management command to permanently delete accounts past their 30-day grace period.

Run daily via cron:
  python manage.py purge_deleted_accounts

Or via crontab:
  0 3 * * * cd /path/to/backend && python manage.py purge_deleted_accounts
"""
import logging
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import UserProfile

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Permanently delete user accounts past the 30-day deletion grace period'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show which accounts would be deleted without actually deleting them',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        now = timezone.now()

        expired_profiles = UserProfile.objects.filter(
            is_scheduled_for_deletion=True,
            deletion_scheduled_for__lte=now,
        ).select_related('user')

        count = expired_profiles.count()

        if count == 0:
            self.stdout.write(self.style.SUCCESS('No expired accounts to purge.'))
            return

        if dry_run:
            self.stdout.write(self.style.WARNING(f'DRY RUN: Would delete {count} account(s):'))
            for profile in expired_profiles:
                user = profile.user
                self.stdout.write(
                    f'  - {user.email} (requested: {profile.deletion_requested_at}, '
                    f'scheduled: {profile.deletion_scheduled_for})'
                )
            return

        for profile in expired_profiles:
            user = profile.user
            email = user.email
            try:
                user.delete()  # Cascade deletes profile and related data
                logger.info(f'Purged expired account: {email}')
                self.stdout.write(self.style.SUCCESS(f'Deleted: {email}'))
            except Exception as e:
                logger.error(f'Failed to purge account {email}: {e}')
                self.stdout.write(self.style.ERROR(f'Failed: {email} - {e}'))

        self.stdout.write(self.style.SUCCESS(f'Purged {count} expired account(s).'))
