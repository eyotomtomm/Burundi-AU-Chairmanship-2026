"""
Middleware that keeps ``UserProfile.last_active`` fresh on every authenticated
API request.

This is the signal the admin dashboard uses for "users online now". Updating
it on every request would be expensive, so we throttle writes to at most one
per user per 60 seconds using Django's cache as a lightweight mutex.

Anonymous devices are handled separately by the ``/api/heartbeat/`` endpoint,
which bumps ``DeviceToken.updated_at`` based on the ``X-FCM-Token`` header.
"""

import logging

from django.core.cache import cache
from django.utils import timezone

logger = logging.getLogger(__name__)

# Minimum interval between writes for the same user, in seconds.
THROTTLE_SECONDS = 60


class LastActiveMiddleware:
    """Throttled writer for ``UserProfile.last_active``.

    Skips unauthenticated requests, non-/api/ paths, and error responses.
    Uses a per-user cache key so parallel requests from the same user
    collapse into a single DB write.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Fast-path out on non-API paths
        if not request.path.startswith('/api/'):
            return response

        # Skip unauthenticated and error responses
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return response
        if response.status_code >= 400:
            return response

        cache_key = f'last_active_bumped:{user.pk}'
        if cache.get(cache_key):
            return response

        try:
            # Deferred import to avoid circular imports at app startup
            from core.models import UserProfile
            UserProfile.objects.filter(user_id=user.pk).update(
                last_active=timezone.now()
            )
            cache.set(cache_key, 1, THROTTLE_SECONDS)
        except Exception:
            # Analytics-style middleware must never break a request.
            logger.warning('LastActiveMiddleware failed to update', exc_info=True)

        return response
