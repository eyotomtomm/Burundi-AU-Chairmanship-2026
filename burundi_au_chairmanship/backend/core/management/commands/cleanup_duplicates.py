"""
Remove seed_data duplicates that have no images, keeping the ones
with Spaces images from restore_from_spaces.
Also assign existing Spaces images to any remaining imageless records.

Usage: python manage.py cleanup_duplicates
"""
from django.core.management.base import BaseCommand
from django.db.models.signals import pre_save
from core.models import (
    Article, MagazineEdition, Event, LiveFeed,
    FeatureCard, HeroSlide, GalleryAlbum, GalleryPhoto,
    Video, _auto_optimize_image,
)


class Command(BaseCommand):
    help = 'Remove imageless duplicates and assign Spaces images to remaining records'

    def handle(self, *args, **options):
        # Disconnect image signal
        for model in [HeroSlide, Article, Event, FeatureCard, MagazineEdition,
                       GalleryAlbum, GalleryPhoto, LiveFeed, Video]:
            pre_save.disconnect(_auto_optimize_image, sender=model)

        # ── Hero Slides: delete ones without images ──────────────
        no_img = HeroSlide.objects.filter(image='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} hero slides without images')

        # ── Articles: delete seed_data ones without images ───────
        no_img = Article.objects.filter(image='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} articles without images')

        # ── Events: assign images to imageless events ────────────
        # seed_data created 3 events, restore created 2 with images
        # Assign the spare event image to any without
        spare_images = [
            'events/IMG_1663.jpeg',
            'events/IMG_1664.jpeg',
        ]
        imageless_events = Event.objects.filter(image='')
        for i, event in enumerate(imageless_events):
            if i < len(spare_images):
                event.image = spare_images[i]
                event.save(update_fields=['image'])
        self.stdout.write(f'  Assigned images to {min(imageless_events.count(), len(spare_images))} events')

        # ── Feature Cards: delete ones without images ────────────
        no_img = FeatureCard.objects.filter(image='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} feature cards without images')

        # ── Magazines: delete seed_data ones without covers ──────
        no_img = MagazineEdition.objects.filter(cover_image='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} magazines without cover images')

        # ── Live Feeds: delete ones without thumbnails ───────────
        no_img = LiveFeed.objects.filter(thumbnail='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} live feeds without thumbnails')

        # ── Videos: delete ones without thumbnails ───────────────
        no_img = Video.objects.filter(thumbnail='')
        count = no_img.count()
        no_img.delete()
        self.stdout.write(f'  Deleted {count} videos without thumbnails')

        # ── Gallery: delete albums/photos without images ─────────
        no_img_photos = GalleryPhoto.objects.filter(image='')
        photo_count = no_img_photos.count()
        no_img_photos.delete()

        # Delete albums that now have zero photos
        empty_albums = GalleryAlbum.objects.filter(cover_image='')
        album_count = empty_albums.count()
        empty_albums.delete()
        self.stdout.write(f'  Deleted {album_count} albums, {photo_count} photos without images')

        # ── Summary ──────────────────────────────────────────────
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('Remaining content:'))
        self.stdout.write(f'  Hero Slides: {HeroSlide.objects.count()}')
        self.stdout.write(f'  Articles:    {Article.objects.count()}')
        self.stdout.write(f'  Events:      {Event.objects.count()}')
        self.stdout.write(f'  Features:    {FeatureCard.objects.count()}')
        self.stdout.write(f'  Magazines:   {MagazineEdition.objects.count()}')
        self.stdout.write(f'  Live Feeds:  {LiveFeed.objects.count()}')
        self.stdout.write(f'  Videos:      {Video.objects.count()}')
        self.stdout.write(f'  Albums:      {GalleryAlbum.objects.count()}')
        self.stdout.write(f'  Photos:      {GalleryPhoto.objects.count()}')

        # Reconnect signal
        for model in [HeroSlide, Article, Event, FeatureCard, MagazineEdition,
                       GalleryAlbum, GalleryPhoto, LiveFeed, Video]:
            pre_save.connect(_auto_optimize_image, sender=model)

        self.stdout.write(self.style.SUCCESS('\nCleanup complete!'))
