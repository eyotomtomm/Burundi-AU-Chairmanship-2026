from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'core'

    def ready(self):
        # Register post_save signals for multi-size thumbnail generation.
        from .signals import register_thumbnail_signals
        register_thumbnail_signals()
