"""
Admin Activity Logger middleware -- captures POST/PUT/PATCH/DELETE requests
to /admin/ paths and persists them to the AdminActivityLog model.

Only authenticated staff/superuser actions are logged.  GET (read-only)
requests are intentionally skipped to avoid flooding the log.
"""

import logging
import re

logger = logging.getLogger(__name__)

# URL patterns that map to known action types
_ACTION_PATTERNS = [
    (re.compile(r'/create/$'), 'create'),
    (re.compile(r'/edit/$'), 'update'),
    (re.compile(r'/delete/$'), 'delete'),
    (re.compile(r'/toggle-'), 'update'),
    (re.compile(r'/send/$'), 'update'),
    (re.compile(r'/review/$'), 'approve'),
    (re.compile(r'/approve/'), 'approve'),
    (re.compile(r'/reject/'), 'reject'),
    (re.compile(r'/bulk/'), 'bulk_action'),
    (re.compile(r'/export'), 'export'),
    (re.compile(r'/status/$'), 'update'),
    (re.compile(r'/reply/$'), 'update'),
    (re.compile(r'/invite/$'), 'create'),
]

# URL fragments -> model name mapping
_MODEL_PATTERNS = [
    ('hero-slides', 'HeroSlide'),
    ('hero-text', 'HeroTextContent'),
    ('articles', 'Article'),
    ('categories', 'Category'),
    ('events', 'Event'),
    ('notifications', 'Notification'),
    ('users', 'User'),
    ('admin-management', 'AdminUser'),
    ('verification-requests', 'VerificationRequest'),
    ('magazines', 'MagazineEdition'),
    ('feature-cards', 'FeatureCard'),
    ('event-registrations', 'EventRegistration'),
    ('event-submissions', 'EventSubmission'),
    ('event-speakers', 'EventSpeaker'),
    ('quick-access', 'QuickAccessMenuItem'),
    ('priority-agendas', 'PriorityAgenda'),
    ('gallery', 'GalleryAlbum'),
    ('videos', 'Video'),
    ('live-feeds', 'LiveFeed'),
    ('resources', 'Resource'),
    ('social-media', 'SocialMediaLink'),
    ('weather-cities', 'WeatherCity'),
    ('app-settings', 'AppSettings'),
    ('support', 'SupportTicket'),
    ('polls', 'Poll'),
    ('discussions', 'Discussion'),
    ('contact-directory', 'ContactDirectory'),
    ('email-templates', 'EmailTemplate'),
    ('announcements', 'AnnouncementBanner'),
    ('onboarding', 'OnboardingStep'),
    ('maintenance', 'ScheduledMaintenance'),
    ('translations', 'TranslationEntry'),
]


class AdminActivityLoggerMiddleware:
    """
    Logs admin staff actions (POST/PUT/PATCH/DELETE) on /admin/ paths
    to the AdminActivityLog model.

    Should be placed after AuthenticationMiddleware in MIDDLEWARE so that
    request.user is available.
    """

    LOGGED_METHODS = {'POST', 'PUT', 'PATCH', 'DELETE'}

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Only log mutating requests to admin paths
        if (
            request.method in self.LOGGED_METHODS
            and request.path.startswith('/admin/')
            and hasattr(request, 'user')
            and request.user.is_authenticated
            and (request.user.is_staff or request.user.is_superuser)
            and response.status_code in (200, 301, 302, 303)
        ):
            self._log_action(request)

        return response

    def _log_action(self, request):
        """Persist the admin action to AdminActivityLog."""
        try:
            from core.models import AdminActivityLog

            path = request.path

            # Skip login page POST (handled separately) and CSRF/static
            if path in ('/admin/', '/admin/logout/'):
                # Log login/logout explicitly
                action_type = 'logout' if 'logout' in path else 'login'
                AdminActivityLog.objects.create(
                    user=request.user,
                    action_type=action_type,
                    model_name='',
                    object_id=None,
                    object_repr=request.user.username,
                    changes={},
                    ip_address=request.META.get('REMOTE_ADDR', '127.0.0.1'),
                    user_agent=request.META.get('HTTP_USER_AGENT', '')[:1000],
                    path=path[:500],
                )
                return

            # Determine action type from URL
            action_type = 'update'  # default fallback
            for pattern, action in _ACTION_PATTERNS:
                if pattern.search(path):
                    action_type = action
                    break

            # Determine model name from URL
            model_name = ''
            for fragment, name in _MODEL_PATTERNS:
                if fragment in path:
                    model_name = name
                    break

            # Try to extract object ID from URL (e.g. /admin/articles/42/edit/)
            object_id = None
            object_repr = ''
            pk_match = re.search(r'/(\d+)/', path)
            if pk_match:
                object_id = int(pk_match.group(1))
                object_repr = f'{model_name} #{object_id}'
            elif model_name:
                object_repr = model_name

            AdminActivityLog.objects.create(
                user=request.user,
                action_type=action_type,
                model_name=model_name,
                object_id=object_id,
                object_repr=object_repr,
                changes={},
                ip_address=request.META.get('REMOTE_ADDR', '127.0.0.1'),
                user_agent=request.META.get('HTTP_USER_AGENT', '')[:1000],
                path=path[:500],
            )

        except Exception:
            # Never let logging break the actual response
            logger.exception('Failed to log admin activity')
