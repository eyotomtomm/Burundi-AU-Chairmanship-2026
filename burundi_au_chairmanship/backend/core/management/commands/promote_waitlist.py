"""
Management command to promote waitlisted event submissions when spots open up.

Usage:
    python manage.py promote_waitlist
    python manage.py promote_waitlist --event-registration 5
    python manage.py promote_waitlist --dry-run
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import EventRegistration, EventSubmission, EventWaitlist


class Command(BaseCommand):
    help = 'Promote waitlisted users to registered when spots open up'

    def add_arguments(self, parser):
        parser.add_argument(
            '--event-registration',
            type=int,
            help='Only process a specific event registration ID',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be promoted without making changes',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        event_reg_id = options.get('event_registration')

        qs = EventRegistration.objects.filter(is_active=True, max_registrations__gt=0)
        if event_reg_id:
            qs = qs.filter(pk=event_reg_id)

        total_promoted = 0

        for event_reg in qs:
            current_count = event_reg.submissions.filter(is_waitlisted=False).count()
            available_spots = event_reg.max_registrations - current_count

            if available_spots <= 0:
                continue

            # Get waitlisted submissions in order (oldest first)
            waitlisted = event_reg.submissions.filter(
                is_waitlisted=True
            ).order_by('submitted_at')[:available_spots]

            for submission in waitlisted:
                if dry_run:
                    self.stdout.write(
                        f'  [DRY RUN] Would promote: {submission.user.username} '
                        f'for "{event_reg.event_title}"'
                    )
                else:
                    submission.is_waitlisted = False
                    submission.status = 'pending'
                    submission.save(update_fields=['is_waitlisted', 'status'])

                    # Update EventWaitlist entry
                    EventWaitlist.objects.filter(
                        user=submission.user,
                        event_registration=event_reg,
                    ).update(promoted=True, notified=True)

                    self.stdout.write(self.style.SUCCESS(
                        f'  Promoted: {submission.user.username} '
                        f'for "{event_reg.event_title}"'
                    ))
                total_promoted += 1

        action = 'Would promote' if dry_run else 'Promoted'
        self.stdout.write(self.style.SUCCESS(
            f'\n{action} {total_promoted} waitlisted submission(s).'
        ))
