"""
Link images to existing X-imported articles.

Updates articles that were imported without images to point to the correct
image files already uploaded to DigitalOcean Spaces.

Usage:
    python manage.py link_x_images               # update all
    python manage.py link_x_images --dry-run      # preview only
"""

import json
import os

from django.conf import settings
from django.core.management.base import BaseCommand

from core.models import Article


class Command(BaseCommand):
    help = 'Link Spaces images to existing X-imported articles'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview what would be updated without saving',
        )
        parser.add_argument(
            '--fixture',
            type=str,
            default='',
            help='Path to fixture JSON (default: fixtures/x_posts_data.json)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

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

        # Build title -> image_path map from fixture
        image_map = {}
        for item in data:
            if item.get('type') == 'article' and item.get('image_path'):
                image_map[item['title']] = item['image_path']

        self.stdout.write(f'Fixture has {len(image_map)} articles with images\n')

        updated = 0
        already_has_image = 0
        not_found = 0

        for title, image_path in image_map.items():
            try:
                article = Article.objects.filter(title=title).first()
                if not article:
                    not_found += 1
                    continue

                if article.image and article.image.name:
                    already_has_image += 1
                    continue

                if not dry_run:
                    article.image.name = image_path
                    article.save(update_fields=['image'])

                updated += 1
                self.stdout.write(f'  Linked: {image_path} -> {title[:60]}')

            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  ERROR {title[:50]}: {e}'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Updated: {updated}, Already had image: {already_has_image}, '
            f'Not found in DB: {not_found}'
        ))
