"""
Post-save signals for multi-size WebP thumbnail generation.

When an image field changes on any of the tracked models, three WebP
variants (_thumb, _medium, _large) are written alongside the original
file on disk.

The pre_save optimiser in models.py already converts uploads to WebP;
this module runs *after* the row is saved so it can read the final
file path from storage and generate the extra sizes.
"""
import logging
import os

from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver

logger = logging.getLogger(__name__)

# ── Models we generate thumbnails for ───────────────────────────
# Imported lazily inside ready() / the handler to avoid circular imports.

# We keep a per-instance cache of the "old" image name so we only
# regenerate thumbnails when the field actually changed.
_TRACKED_IMAGE_FIELDS = {}  # populated by register_thumbnail_signals()


def _get_image_field_names(model):
    """Return a list of ImageField names for *model*."""
    return [
        f.name
        for f in model._meta.get_fields()
        if isinstance(f, models.ImageField)
    ]


def _on_post_save(sender, instance, created, **kwargs):
    """Generate multi-size thumbnails when an image field changes."""
    from .image_utils import generate_thumbnails_on_disk

    field_names = _get_image_field_names(sender)
    if not field_names:
        return

    for field_name in field_names:
        image = getattr(instance, field_name, None)
        if not image or not image.name:
            continue

        # Build an instance-level cache key to remember the "old" name.
        cache_attr = f'_prev_image_{field_name}'

        # On creation every image is "new"; on update only regenerate when
        # the file name changed (which means a new upload happened).
        old_name = getattr(instance, cache_attr, None)
        if not created and old_name == image.name:
            continue

        # Remember current name for subsequent saves within same process.
        setattr(instance, cache_attr, image.name)

        # Resolve to an absolute filesystem path.
        try:
            full_path = image.path  # works for default FileSystemStorage
        except NotImplementedError:
            # Remote storage (S3, etc.) -- skip disk-based generation.
            logger.debug(
                "Skipping thumbnail generation for %s.%s (remote storage)",
                sender.__name__, field_name,
            )
            continue

        if not os.path.isfile(full_path):
            continue

        logger.info(
            "Generating thumbnails for %s.%s (pk=%s): %s",
            sender.__name__, field_name, instance.pk, image.name,
        )
        generate_thumbnails_on_disk(full_path)


def register_thumbnail_signals():
    """
    Connect the post_save signal for all core models that have ImageFields.

    Called from ``CoreConfig.ready()`` so Django has finished model loading.
    """
    from . import models as m  # noqa: N812 — short alias is fine here

    target_models = [
        m.HeroSlide,
        m.Article,
        m.ArticleMedia,
        m.GalleryPhoto,
        m.GalleryAlbum,
        m.MagazineEdition,
        m.MagazineImage,
        m.FeatureCard,
        m.FeatureCardMedia,
        m.Event,
        m.EventRegistration,
        m.LiveFeed,
        m.Video,
        m.EmbassyLocation,
        m.PriorityAgenda,
        m.Notification,
        m.Popup,
        m.WeatherCity,
        m.UserProfile,
        m.VerificationRequest,
    ]

    for model in target_models:
        # Only connect if the model actually has image fields.
        if _get_image_field_names(model):
            post_save.connect(
                _on_post_save,
                sender=model,
                dispatch_uid=f'thumbnail_gen_{model.__name__}',
            )
            logger.debug("Registered thumbnail signal for %s", model.__name__)
