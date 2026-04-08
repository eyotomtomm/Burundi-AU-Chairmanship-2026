"""
Management command to optimize all uploaded images.

Converts images to WebP format and resizes them for faster loading.
Usage: python manage.py optimize_images [--dry-run]
"""
from django.core.management.base import BaseCommand
from django.apps import apps
from django.db import models as django_models
from core.image_utils import optimize_image


class Command(BaseCommand):
    help = 'Optimize all uploaded images by converting to WebP and resizing'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be optimized without making changes',
        )
        parser.add_argument(
            '--max-width',
            type=int,
            default=1200,
            help='Maximum image width in pixels (default: 1200)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        max_width = options['max_width']
        total_optimized = 0
        total_skipped = 0

        # Find all models with ImageField
        for model in apps.get_models():
            if model._meta.app_label != 'core':
                continue

            image_fields = [
                f for f in model._meta.get_fields()
                if isinstance(f, django_models.ImageField)
            ]

            if not image_fields:
                continue

            model_name = model.__name__
            self.stdout.write(f'\nProcessing {model_name}...')

            for obj in model.objects.all():
                for field in image_fields:
                    image = getattr(obj, field.name)
                    if not image or not image.name:
                        continue

                    # Skip already optimized (WebP) images
                    if image.name.endswith('.webp'):
                        total_skipped += 1
                        continue

                    if dry_run:
                        self.stdout.write(f'  Would optimize: {image.name}')
                        total_optimized += 1
                        continue

                    try:
                        optimize_image(image, max_width=max_width)
                        obj.save(update_fields=[field.name])
                        total_optimized += 1
                        self.stdout.write(f'  Optimized: {image.name}')
                    except Exception as e:
                        self.stderr.write(f'  Error optimizing {image.name}: {e}')

        action = 'Would optimize' if dry_run else 'Optimized'
        self.stdout.write(self.style.SUCCESS(
            f'\n{action} {total_optimized} images, skipped {total_skipped} (already WebP)'
        ))
