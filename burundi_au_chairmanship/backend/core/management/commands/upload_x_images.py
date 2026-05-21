"""
Upload article images from local media/articles/ to the configured storage backend.

This uploads local article images (from the X scrape import) to DigitalOcean Spaces
(or whatever DEFAULT_FILE_STORAGE is configured). Run this after load_x_fixture
to add images to articles that were created without them.

Usage:
    python manage.py upload_x_images               # upload all
    python manage.py upload_x_images --dry-run      # preview only
"""

import os
from pathlib import Path

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from core.models import Article


class Command(BaseCommand):
    help = 'Upload local article images to the configured storage backend (Spaces)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview what would be uploaded without saving',
        )
        parser.add_argument(
            '--source-dir',
            type=str,
            default='',
            help='Directory containing article images (default: media/articles)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        source_dir = options['source_dir']
        if not source_dir:
            source_dir = os.path.join(settings.BASE_DIR, 'media', 'articles')

        source_path = Path(source_dir)
        if not source_path.exists():
            self.stdout.write(self.style.ERROR(f'Source directory not found: {source_dir}'))
            return

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN — nothing will be uploaded\n'))

        # Find articles without images that match local files
        articles_without_images = Article.objects.filter(
            image='',
            author__icontains='BurundinAddis',
        )
        articles_with_images = Article.objects.exclude(image='').filter(
            author__icontains='BurundinAddis',
        )

        self.stdout.write(f'Articles without images: {articles_without_images.count()}')
        self.stdout.write(f'Articles already with images: {articles_with_images.count()}')
        self.stdout.write(f'Source directory: {source_dir}\n')

        # List available local images (skip thumbnails)
        local_images = {}
        for img_file in source_path.iterdir():
            if img_file.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp'):
                if '_thumb' not in img_file.name and '_medium' not in img_file.name and '_large' not in img_file.name:
                    # Extract tweet_id from filename like "2008758478886891537_1.jpg"
                    local_images[img_file.name] = img_file

        self.stdout.write(f'Local original images available: {len(local_images)}\n')

        uploaded = 0
        skipped = 0
        errors = 0

        # Re-upload images for articles that already have image paths
        for article in articles_with_images:
            try:
                # Check if the image file exists in storage
                image_name = os.path.basename(article.image.name) if article.image else ''
                if image_name in local_images:
                    if not dry_run:
                        local_file = local_images[image_name]
                        with open(local_file, 'rb') as f:
                            article.image.save(
                                image_name,
                                ContentFile(f.read()),
                                save=True,
                            )
                    uploaded += 1
                    self.stdout.write(f'  Uploaded: {image_name} -> {article.title[:50]}')
                else:
                    skipped += 1
            except Exception as e:
                errors += 1
                self.stdout.write(self.style.ERROR(f'  ERROR {article.title[:50]}: {e}'))

        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS(
            f'Done! Uploaded: {uploaded}, Skipped: {skipped}, Errors: {errors}'
        ))
