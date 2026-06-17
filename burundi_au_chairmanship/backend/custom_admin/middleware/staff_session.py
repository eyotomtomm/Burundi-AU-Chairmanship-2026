"""
Enforce a hard maximum lifetime on staff/admin sessions.

SESSION_SAVE_EVERY_REQUEST refreshes the cookie Max-Age on every hit, which
means an active admin user's session never expires.  This middleware stamps
the session at login time and flushes it once the absolute lifetime is
exceeded — regardless of activity.
"""

import time
import logging

from django.conf import settings
from django.contrib.auth import logout
from django.shortcuts import redirect

logger = logging.getLogger('custom_admin')

# 24 hours — override in settings with STAFF_SESSION_MAX_AGE if needed
DEFAULT_MAX_AGE = 60 * 60 * 24

SESSION_CREATED_KEY = '_staff_session_created'


class StaffSessionLifetimeMiddleware:
    """Flush staff sessions that exceed the hard lifetime cap."""

    def __init__(self, get_response):
        self.get_response = get_response
        self.max_age = getattr(settings, 'STAFF_SESSION_MAX_AGE', DEFAULT_MAX_AGE)

    def __call__(self, request):
        # Only enforce on authenticated staff users with a session
        if (
            hasattr(request, 'user')
            and request.user.is_authenticated
            and request.user.is_staff
            and hasattr(request, 'session')
        ):
            created = request.session.get(SESSION_CREATED_KEY)

            if created is None:
                # Legacy session created before this middleware existed —
                # stamp it now so it expires max_age from *this* request,
                # giving the user one more window instead of locking them out
                # immediately on deploy.
                request.session[SESSION_CREATED_KEY] = time.time()
            elif time.time() - created > self.max_age:
                logger.info(
                    'Staff session expired (hard cap %ds) for user %s',
                    self.max_age,
                    request.user.username,
                )
                logout(request)
                return redirect('custom_admin:login')

        return self.get_response(request)
