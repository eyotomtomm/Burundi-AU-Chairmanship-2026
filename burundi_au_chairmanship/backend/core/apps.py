from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'core'

    def ready(self):
        # Register post_save signals for multi-size thumbnail generation.
        from .signals import register_thumbnail_signals
        register_thumbnail_signals()

        # Register signals that auto-create AdminNotification entries.
        from .signals import register_admin_notification_signals
        register_admin_notification_signals()

        # Drop cached API responses when their source rows change.
        from .signals import register_cache_invalidation_signals
        register_cache_invalidation_signals()
