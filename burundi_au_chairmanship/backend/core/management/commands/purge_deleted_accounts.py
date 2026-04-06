"""
Management command to permanently delete accounts past their 30-day grace period.

Deletes both Django user data (cascade) and Firebase Auth accounts.

Run daily via cron:
  python manage.py purge_deleted_accounts

Or via crontab:
  0 3 * * * cd /path/to/backend && python manage.py purge_deleted_accounts
"""
import logging
from django.core.management.base import BaseCommand
from django.utils import timezone
from firebase_admin import auth as firebase_auth
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

    def _delete_firebase_account(self, firebase_uid, email):
        """Delete the Firebase Auth account for this user."""
        if not firebase_uid:
            return
        try:
            firebase_auth.delete_user(firebase_uid)
            logger.info('Deleted Firebase Auth account for %s (uid: %s)', email, firebase_uid)
        except firebase_auth.UserNotFoundError:
            logger.info('Firebase Auth account already gone for %s (uid: %s)', email, firebase_uid)
        except Exception as e:
            logger.error('Failed to delete Firebase Auth account for %s: %s', email, e)

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
                    f'  - {user.email} (uid: {profile.firebase_uid}, '
                    f'requested: {profile.deletion_requested_at}, '
                    f'scheduled: {profile.deletion_scheduled_for})'
                )
            return

        deleted = 0
        for profile in expired_profiles:
            user = profile.user
            email = user.email
            firebase_uid = profile.firebase_uid
            try:
                # Delete Firebase Auth account first
                self._delete_firebase_account(firebase_uid, email)
                # Cascade deletes profile, likes, views, and all related data
                user.delete()
                deleted += 1
                logger.info('Purged expired account: %s', email)
                self.stdout.write(self.style.SUCCESS(f'Deleted: {email}'))
            except Exception as e:
                logger.error('Failed to purge account %s: %s', email, e)
                self.stdout.write(self.style.ERROR(f'Failed: {email} - {e}'))

        self.stdout.write(self.style.SUCCESS(f'Purged {deleted} of {count} expired account(s).'))
