"""
Maintenance mode middleware — blocks API requests with 503 when maintenance
is active, while still allowing the maintenance-status endpoint itself,
the admin panel, and static/media files.
"""

import logging

from django.http import JsonResponse
from django.utils import timezone
from django.db.models import Q

logger = logging.getLogger(__name__)

# Paths that are always allowed through, even during maintenance.
ALLOWED_PATHS = (
    '/api/maintenance/',       # App checks this to know if maintenance is on
    '/api/v1/maintenance/',    # Versioned alias
    '/admin/',                 # Django admin panel
    '/static/',                # Static assets
    '/media/',                 # Uploaded files
)


class MaintenanceMiddleware:
    """
    Returns 503 Service Unavailable for API requests when a maintenance
    window is currently active.

    - The maintenance-status endpoint is always allowed so the app can
      detect when maintenance ends.
    - The admin panel is always allowed so staff can manage the site.
    - Non-API paths (landing page, legal pages) are allowed through.
    """

    def __init__(self, get_response):
        self.get_response = get_response
        self._cached_active = None
        self._cache_expires = 0

    def __call__(self, request):
        path = request.path

        # Fast-path: skip check for non-API requests and allowed paths
        if not path.startswith('/api/'):
            return self.get_response(request)

        for allowed in ALLOWED_PATHS:
            if path.startswith(allowed):
                return self.get_response(request)

        # Check maintenance status (cached for 10 seconds to avoid
        # hitting the DB on every single request)
        if self._is_maintenance_active():
            response = JsonResponse(
                {
                    'detail': 'The app is currently under maintenance. Please try again later.',
                    'code': 'maintenance_mode',
                },
                status=503,
            )
            # Custom header so the app can detect maintenance even if a
            # proxy (e.g. Cloudflare) replaces the JSON body with HTML.
            response['X-Maintenance-Mode'] = '1'
            response['Cache-Control'] = 'no-store'
            return response

        return self.get_response(request)

    def _is_maintenance_active(self):
        """Check DB with a short TTL cache to avoid per-request queries."""
        now_ts = timezone.now().timestamp()

        if now_ts < self._cache_expires:
            return self._cached_active

        try:
            from core.models import ScheduledMaintenance

            now = timezone.now()
            active = ScheduledMaintenance.objects.filter(
                is_active=True,
                starts_at__lte=now,
            ).filter(
                Q(ends_at__gt=now) | Q(ends_at__isnull=True),
            ).exists()

            self._cached_active = active
            self._cache_expires = now_ts + 10  # Cache for 10 seconds
            return active
        except Exception:
            # If anything goes wrong (e.g. table doesn't exist yet),
            # don't block requests.
            logger.exception('Maintenance check failed')
            return False
