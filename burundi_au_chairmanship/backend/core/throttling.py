"""
Custom throttling classes for the Burundi AU Chairmanship API.

Provides rate limiting to prevent abuse and manipulation of analytics.
"""

from rest_framework.throttling import SimpleRateThrottle


class ViewCountThrottle(SimpleRateThrottle):
    """
    Throttle for view count endpoints to prevent manipulation.

    Limits: 1 view per content item per minute per user/IP.

    This prevents users from inflating view counts by repeatedly
    calling the record_view endpoint.
    """

    scope = 'view_count'

    def get_cache_key(self, request, view):
        """
        Generate cache key based on user/IP + content ID.

        This ensures the same user can't record multiple views
        for the same content within the rate limit window.
        """
        # Get content ID from URL
        content_id = view.kwargs.get('pk')

        if request.user and request.user.is_authenticated:
            # For authenticated users: user_id + content_id
            ident = str(request.user.pk)
        else:
            # For anonymous users: IP + content_id
            ident = self.get_ident(request)

        return self.cache_format % {
            'scope': self.scope,
            'ident': f'{ident}:{content_id}'
        }


class LikeToggleThrottle(SimpleRateThrottle):
    """
    Throttle for like/unlike endpoints to prevent rapid toggling.

    Limits: 10 toggles per minute per user.

    This prevents users from rapidly liking/unliking to manipulate
    like counts or spam the database with writes.
    """

    scope = 'like_toggle'
    rate = '10/min'

    def get_cache_key(self, request, view):
        """
        Generate cache key based on user only.

        Allows user to like different items but prevents rapid spam.
        """
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            # Anonymous users get IP-based throttle
            ident = self.get_ident(request)

        return self.cache_format % {
            'scope': self.scope,
            'ident': ident
        }
