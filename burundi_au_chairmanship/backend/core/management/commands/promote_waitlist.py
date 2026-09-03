"""
Management command to promote waitlisted event submissions when spots open up.

Usage:
    python manage.py promote_waitlist
    python manage.py promote_waitlist --event-registration 5
    python manage.py promote_waitlist --dry-run
"""
from django.core.management.base import BaseCommand
from core.models import EventRegistration
from core.utils import active_registration_count, promote_waitlist


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
            if dry_run:
                available = event_reg.max_registrations - active_registration_count(event_reg)
                waitlisted = event_reg.submissions.filter(is_waitlisted=True).order_by('submitted_at')[:max(available, 0)]
                for submission in waitlisted:
                    self.stdout.write(
                        f'  [DRY RUN] Would promote: {submission.user.username} '
                        f'for "{event_reg.event_title}"'
                    )
                    total_promoted += 1
                continue
            promoted = promote_waitlist(event_reg)
            if promoted:
                self.stdout.write(self.style.SUCCESS(
                    f'  Promoted {promoted} for "{event_reg.event_title}"'
                ))
            total_promoted += promoted

        action = 'Would promote' if dry_run else 'Promoted'
        self.stdout.write(self.style.SUCCESS(
            f'\n{action} {total_promoted} waitlisted submission(s).'
        ))
