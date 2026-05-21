"""
Load X posts fixture into the database (production-safe).

Reads fixtures/x_posts_data.json and creates Articles, Events, and LiveFeeds.
Skips duplicates by title. Does NOT conflict with existing PKs.

For images: if media/x_scrape/ exists locally, attaches images via Django's
configured storage backend (Spaces in production, local FS in dev).

Usage:
    python manage.py load_x_fixture                # load all
    python manage.py load_x_fixture --dry-run      # preview only
    python manage.py load_x_fixture --no-images    # skip image uploads
"""

import json
import os
import re
from pathlib import Path

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from core.models import Article, Event, LiveFeed, Category


CATEGORY_FR_MAP = {
    'Diplomacy': 'Diplomatie',
    'Governance': 'Gouvernance',
    'Health': 'Santé',
    'Economy': 'Économie',
    'AU Chairmanship': "Présidence de l'UA",
    'Culture': 'Culture',
}
CATEGORY_COLORS = {
    'Diplomacy': '#1EB53A',
    'Governance': '#CE1126',
    'Health': '#0077B6',
    'Economy': '#F4A261',
    'AU Chairmanship': '#FFD700',
    'Culture': '#9B59B6',
}


class Command(BaseCommand):
    help = 'Load X posts fixture into the database (production-safe, no PK conflicts)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview what would be imported without saving',
        )
        parser.add_argument(
            '--no-images',
            action='store_true',
            help='Skip attaching images (useful if x_scrape dir is not available)',
        )
        parser.add_argument(
            '--fixture',
            type=str,
            default='',
            help='Path to fixture JSON (default: fixtures/x_posts_data.json)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        no_images = options['no_images']

        fixture_path = options['fixture']
        if not fixture_path:
            fixture_path = os.path.join(settings.BASE_DIR, 'fixtures', 'x_posts_data.json')

        if not os.path.exists(fixture_path):
            self.stdout.write(self.style.ERROR(f'Fixture not found: {fixture_path}'))
            return

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — nothing will be saved\n'))

        with open(fixture_path) as f:
            data = json.load(f)

        self.stdout.write(f'Loaded {len(data)} records from fixture\n')

        # Check for local x_scrape images
        scrape_dir = Path(os.path.join(settings.BASE_DIR, 'media', 'x_scrape'))
        has_local_images = scrape_dir.exists() and not no_images
        if has_local_images:
            self.stdout.write(f'Local scrape dir found: {scrape_dir}')
        else:
            self.stdout.write('No local scrape images (articles will be created without images)')

        articles_created = 0
        articles_skipped = 0
        events_created = 0
        events_skipped = 0
        livefeeds_created = 0
        livefeeds_skipped = 0
        errors = 0

        for item in data:
            try:
                item_type = item['type']

                if item_type == 'article':
                    title = item['title']
                    if Article.objects.filter(title=title).exists():
                        articles_skipped += 1
                        continue

                    if not dry_run:
                        cat_name = item.get('category_name', 'Diplomacy')
                        category, _ = Category.objects.get_or_create(
                            name=cat_name,
                            defaults={
                                'name_fr': CATEGORY_FR_MAP.get(cat_name, cat_name),
                                'color': CATEGORY_COLORS.get(cat_name, '#1EB53A'),
                            },
                        )

                        article = Article(
                            title=title,
                            content=item.get('content', ''),
                            author=item.get('author', ''),
                            category=category,
                            publish_date=item.get('publish_date'),
                            status=item.get('status', 'published'),
                        )

                        # Try to attach image from local x_scrape
                        if has_local_images:
                            image_path = item.get('image_path', '')
                            if image_path:
                                # image_path looks like "articles/2008758478886891537_1.jpg"
                                # The original file is in media/x_scrape/ with the tweet_id pattern
                                local_file = Path(os.path.join(settings.BASE_DIR, 'media', image_path))
                                if local_file.exists():
                                    with open(local_file, 'rb') as img_f:
                                        article.image.save(
                                            local_file.name,
                                            ContentFile(img_f.read()),
                                            save=False,
                                        )

                        article.save()

                    articles_created += 1
                    self.stdout.write(f'  [Article] {title[:70]}')

                elif item_type == 'event':
                    name = item['name']
                    if Event.objects.filter(name=name).exists():
                        events_skipped += 1
                        continue

                    if not dry_run:
                        Event.objects.create(
                            name=name,
                            description=item.get('description', ''),
                            address=item.get('address', 'See article for details'),
                            latitude=item.get('latitude', 9.0380),
                            longitude=item.get('longitude', 38.7506),
                            event_date=item.get('event_date'),
                            status=item.get('status', 'published'),
                        )

                    events_created += 1
                    self.stdout.write(f'  [Event] {name[:70]}')

                elif item_type == 'livefeed':
                    title = item['title']
                    if LiveFeed.objects.filter(title=title).exists():
                        livefeeds_skipped += 1
                        continue

                    if not dry_run:
                        LiveFeed.objects.create(
                            title=title,
                            description=item.get('description', ''),
                            stream_url=item.get('stream_url', ''),
                            stream_type=item.get('stream_type', 'external'),
                            status=item.get('status', 'recorded'),
                            content_status=item.get('content_status', 'published'),
                            scheduled_time=item.get('scheduled_time'),
                        )

                    livefeeds_created += 1
                    self.stdout.write(f'  [LiveFeed] {title[:70]}')

            except Exception as e:
                errors += 1
                self.stdout.write(self.style.ERROR(f'  ERROR: {e}'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Articles: {articles_created} new / {articles_skipped} skipped, '
            f'Events: {events_created} new / {events_skipped} skipped, '
            f'LiveFeeds: {livefeeds_created} new / {livefeeds_skipped} skipped, '
            f'Errors: {errors}'
        ))
