import logging
from datetime import timedelta
from django.utils import timezone

logger = logging.getLogger(__name__)


class SessionTrackingMiddleware:
    """
    Tracks user sessions with geolocation data for analytics.

    - Only tracks /api/ requests (not admin or static)
    - Only tracks successful responses (status < 400)
    - Throttled: max 1 session record per user/IP per hour
    - Gracefully fails (logs warning, doesn't crash request)
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Only track API requests
        if not request.path.startswith('/api/'):
            return response

        # Only track successful responses
        if response.status_code >= 400:
            return response

        try:
            self._track_session(request)
        except Exception as e:
            logger.warning('Session tracking failed: %s', e)

        return response

    def _track_session(self, request):
        from core.geo_utils import get_client_ip, get_country_from_ip
        from core.models import UserSession

        ip = get_client_ip(request)
        if not ip:
            return

        user = request.user if hasattr(request, 'user') and request.user.is_authenticated else None

        # Throttle: max 1 session per user/IP per hour
        one_hour_ago = timezone.now() - timedelta(hours=1)
        existing = UserSession.objects.filter(
            ip_address=ip,
            created_at__gte=one_hour_ago,
        )
        if user:
            existing = existing.filter(user=user)
        else:
            existing = existing.filter(user__isnull=True)

        if existing.exists():
            return

        # Geolocate IP
        country_code, country_name, city = get_country_from_ip(ip)

        # Get user nationality snapshot
        user_nationality = ''
        device_type = ''
        device_os = ''
        app_version = ''
        if user and hasattr(user, 'profile'):
            profile = user.profile
            user_nationality = profile.nationality or ''
            device_type = profile.device_type or ''
            device_os = profile.device_os or ''
            app_version = profile.app_version or ''

        UserSession.objects.create(
            user=user,
            ip_address=ip,
            country_code=country_code,
            country_name=country_name,
            city=city,
            user_nationality=user_nationality,
            device_type=device_type,
            device_os=device_os,
            app_version=app_version,
        )
