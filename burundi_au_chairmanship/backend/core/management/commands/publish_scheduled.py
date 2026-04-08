"""
Management command to publish scheduled content.

Queries all content models with status='scheduled' and scheduled_publish_date <= now(),
sets their status to 'published', and logs each transition.

Usage:
    python manage.py publish_scheduled

Recommended to run via cron every minute or via Celery beat:
    * * * * * cd /path/to/backend && python manage.py publish_scheduled >> /var/log/publish_scheduled.log 2>&1
"""

import logging
from django.core.management.base import BaseCommand
from django.utils import timezone

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Publish all content with status=scheduled and scheduled_publish_date <= now()'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be published without actually changing anything',
        )

    def handle(self, *args, **options):
        from core.models import (
            Article, MagazineEdition, Event, Video,
            GalleryAlbum, LiveFeed, Resource,
        )

        dry_run = options['dry_run']
        now = timezone.now()
        total_published = 0

        # Define all content models and their status field name
        # (model_class, status_field_name, scheduled_date_field_name, label)
        content_models = [
            (Article, 'status', 'scheduled_publish_date', 'Article'),
            (MagazineEdition, 'status', 'scheduled_publish_date', 'Magazine'),
            (Event, 'status', 'scheduled_publish_date', 'Event'),
            (Video, 'status', 'scheduled_publish_date', 'Video'),
            (GalleryAlbum, 'status', 'scheduled_publish_date', 'Gallery Album'),
            (LiveFeed, 'content_status', 'scheduled_publish_date', 'Live Feed'),
            (Resource, 'status', 'scheduled_publish_date', 'Resource'),
        ]

        for model_class, status_field, date_field, label in content_models:
            # Build the filter: status/content_status = 'scheduled' AND scheduled_publish_date <= now
            filter_kwargs = {
                status_field: 'scheduled',
                f'{date_field}__lte': now,
            }

            items = model_class.objects.filter(**filter_kwargs)
            count = items.count()

            if count == 0:
                continue

            for item in items:
                item_title = getattr(item, 'title', None) or getattr(item, 'name', None) or str(item)
                scheduled_date = getattr(item, date_field)

                if dry_run:
                    self.stdout.write(
                        self.style.WARNING(
                            f'[DRY RUN] Would publish {label} #{item.pk}: '
                            f'"{item_title}" (scheduled for {scheduled_date})'
                        )
                    )
                else:
                    # Set status to published
                    setattr(item, status_field, 'published')

                    # Also set is_active=True if the model has that field
                    if hasattr(item, 'is_active'):
                        item.is_active = True

                    # Also clear is_draft for Article (legacy field)
                    if hasattr(item, 'is_draft'):
                        item.is_draft = False

                    item.save()

                    logger.info(
                        'Auto-published %s #%d: "%s" (was scheduled for %s)',
                        label, item.pk, item_title, scheduled_date,
                    )
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Published {label} #{item.pk}: "{item_title}" '
                            f'(was scheduled for {scheduled_date})'
                        )
                    )

                total_published += 1

        if total_published == 0:
            self.stdout.write(self.style.NOTICE('No scheduled content ready to publish.'))
        else:
            action = 'would publish' if dry_run else 'published'
            self.stdout.write(
                self.style.SUCCESS(f'\nDone! {total_published} item(s) {action}.')
            )
