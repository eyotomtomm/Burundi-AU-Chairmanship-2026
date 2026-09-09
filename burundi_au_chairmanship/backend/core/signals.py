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
    from .image_utils import generate_thumbnails_on_disk, generate_thumbnails_to_storage

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

        logger.info(
            "Generating thumbnails for %s.%s (pk=%s): %s",
            sender.__name__, field_name, instance.pk, image.name,
        )

        # Resolve to an absolute filesystem path if possible;
        # fall back to remote (S3) generation otherwise.
        try:
            full_path = image.path  # works for default FileSystemStorage
        except NotImplementedError:
            # Remote storage (S3, Spaces, etc.)
            generate_thumbnails_to_storage(image)
            continue

        if not os.path.isfile(full_path):
            continue

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


# ── Admin Notification signals ───────────────────────────────────
# Auto-create AdminNotification entries when key events happen.

def _on_support_ticket_created(sender, instance, created, **kwargs):
    """Create an admin notification when a new support ticket is submitted."""
    if not created:
        return
    from .models import AdminNotification
    try:
        AdminNotification.objects.create(
            notification_type='new_ticket',
            title='New support ticket',
            message=instance.subject,
            link=f'/admin/support/{instance.pk}/',
            icon='support_agent',
        )
    except Exception:
        logger.exception("Failed to create admin notification for SupportTicket %s", instance.pk)


def _on_verification_request_created(sender, instance, created, **kwargs):
    """Create an admin notification when a new verification request is submitted."""
    if not created:
        return
    from .models import AdminNotification
    try:
        username = instance.user.username if instance.user else 'Unknown'
        AdminNotification.objects.create(
            notification_type='new_verification',
            title='New verification request',
            message=f'from {username}',
            link=f'/admin/verification-requests/{instance.pk}/review/',
            icon='verified',
        )
    except Exception:
        logger.exception("Failed to create admin notification for VerificationRequest %s", instance.pk)


def _on_user_created(sender, instance, created, **kwargs):
    """Create an admin notification when a new user registers."""
    if not created:
        return
    from .models import AdminNotification
    try:
        AdminNotification.objects.create(
            notification_type='new_user',
            title='New user registered',
            message=instance.username,
            link=f'/admin/users/{instance.pk}/edit/',
            icon='person_add',
        )
    except Exception:
        logger.exception("Failed to create admin notification for User %s", instance.pk)


def register_admin_notification_signals():
    """
    Connect post_save signals to auto-create AdminNotification entries.

    Called from ``CoreConfig.ready()`` after model loading is complete.
    """
    from . import models as m
    from django.contrib.auth import get_user_model
    User = get_user_model()

    post_save.connect(
        _on_support_ticket_created,
        sender=m.SupportTicket,
        dispatch_uid='admin_notif_support_ticket',
    )
    post_save.connect(
        _on_verification_request_created,
        sender=m.VerificationRequest,
        dispatch_uid='admin_notif_verification_request',
    )
    post_save.connect(
        _on_user_created,
        sender=User,
        dispatch_uid='admin_notif_user_created',
    )


# ── Cache invalidation ───────────────────────────────────────────
# Views cache whole responses under fixed keys; drop them when the source
# rows change. home_feed has one key per user, so it is versioned instead:
# bumping home_feed:ver retires every variant at once (views.home_feed).

def _bump_home_feed_version(**kwargs):
    from django.core.cache import cache
    try:
        cache.incr('home_feed:ver')
    except ValueError:
        cache.set('home_feed:ver', 1, None)


def _invalidate_cache_keys(*keys):
    def handler(**kwargs):
        from django.core.cache import cache
        cache.delete_many(keys)
    return handler


def register_cache_invalidation_signals():
    from django.db.models.signals import post_delete
    from . import models as m

    key_map = {
        m.Category: ('categories:v1',),
        m.AppSettings: ('app_settings:v1',),
        m.QuickAccessMenuItem: ('quick_access_menu:v2',),
        m.EmergencyContact: ('emergency_contacts:v1',),
        m.YouthDialogueEvent: ('yd_settings:v1',),
    }
    for model, keys in key_map.items():
        handler = _invalidate_cache_keys(*keys)
        for signal in (post_save, post_delete):
            signal.connect(handler, sender=model, weak=False,
                           dispatch_uid=f'cache_inv_{model.__name__}_{signal.__class__.__name__}_{id(signal)}')

    home_feed_sources = (
        m.HeroSlide, m.Article, m.FeatureCard, m.Category, m.AppSettings,
        m.EventRegistration, m.Event,
    )
    for model in home_feed_sources:
        for signal in (post_save, post_delete):
            signal.connect(_bump_home_feed_version, sender=model, weak=False,
                           dispatch_uid=f'home_feed_ver_{model.__name__}_{id(signal)}')
