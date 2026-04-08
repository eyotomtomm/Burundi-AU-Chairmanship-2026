"""
Rate-limit logging middleware — captures 429 Too Many Requests responses
and persists them to the RateLimitLog model for the admin dashboard.

This middleware is intentionally lightweight: it only writes to the database
when a 429 status code is returned, so normal requests see zero overhead.
"""

import logging

logger = logging.getLogger(__name__)


class RateLimitLoggingMiddleware:
    """
    Intercepts responses with status_code == 429 and creates a RateLimitLog entry.

    Should be placed AFTER DRF throttling runs (i.e. near the end of MIDDLEWARE)
    so that the response status code has already been set by the time this
    middleware's process_response hook executes.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        if response.status_code == 429:
            self._log_throttled_request(request, response)

        return response

    def _log_throttled_request(self, request, response):
        """Persist the throttled request details asynchronously-safe."""
        try:
            from core.models import RateLimitLog

            # Extract the throttle class name from the Retry-After or
            # X-Throttle-Class header if DRF sets one; fall back to generic.
            throttle_class = ''
            if hasattr(response, 'throttle_class'):
                throttle_class = response.throttle_class
            elif hasattr(request, '_throttle_class'):
                throttle_class = request._throttle_class

            # Determine the authenticated user (if any)
            user = None
            if hasattr(request, 'user') and request.user.is_authenticated:
                user = request.user

            ip_address = request.META.get('REMOTE_ADDR', '127.0.0.1')
            endpoint = request.path[:255]
            method = request.method[:10]
            user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]

            RateLimitLog.objects.create(
                ip_address=ip_address,
                user=user,
                endpoint=endpoint,
                throttle_class=throttle_class,
                request_method=method,
                was_blocked=True,
                user_agent=user_agent,
            )
        except Exception:
            # Never let logging break the actual response
            logger.exception('Failed to log rate-limited request')
