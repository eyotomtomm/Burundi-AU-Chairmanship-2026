"""
Custom throttling classes for the Be 4 Africa API.

Provides rate limiting to prevent abuse and manipulation of analytics.
"""

from rest_framework.throttling import SimpleRateThrottle


class AuthRateThrottle(SimpleRateThrottle):
    """
    Strict throttle for authentication endpoints (login, register).
    Limits: 5 attempts per minute per IP to prevent brute-force attacks.
    """
    scope = 'auth'

    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class OTPRateThrottle(SimpleRateThrottle):
    """
    Strict throttle for OTP *send* endpoints only.
    Limits: 3 sends per minute per user to prevent OTP flooding.
    """
    scope = 'otp'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class OTPVerifyThrottle(SimpleRateThrottle):
    """
    Separate throttle for OTP *verify* endpoints.
    Limits: 10 attempts per minute per user — more generous than send
    so that a typo doesn't lock the user out.
    """
    scope = 'otp_verify'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


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


class SupportTicketThrottle(SimpleRateThrottle):
    """
    Throttle for support ticket creation to prevent spam.
    Limits: 5 tickets per hour per user.
    """
    scope = 'support'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class SearchRateThrottle(SimpleRateThrottle):
    """
    Throttle for search endpoints to prevent enumeration and DoS.
    Limits: 30 searches per minute per IP.
    """
    scope = 'search'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class ProxyRegistrationThrottle(SimpleRateThrottle):
    """
    Throttle for proxy (on-behalf-of) event registration.
    Limits: 5 proxy registrations per hour per user.

    Without this, any authenticated user can bulk-register thousands of
    arbitrary third-party emails into an event, turning the server into
    a government-branded email-spam relay.
    """
    scope = 'proxy_registration'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}
