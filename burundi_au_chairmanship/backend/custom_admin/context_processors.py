"""Context processors for the custom admin portal."""
import logging

from .permissions import SECTION_KEYS

logger = logging.getLogger(__name__)


class _AllAccess:
    """Sentinel set-like object that 'contains' every section key.

    Used for superusers so sidebar `{% if 'X' in allowed_sections %}`
    checks always pass without listing every key.
    """
    def __contains__(self, item):
        return True

    def __iter__(self):
        return iter(SECTION_KEYS)

    def __bool__(self):
        return True


ALL_ACCESS = _AllAccess()


def admin_sections(request):
    """Inject `allowed_sections` into every template.

    - Anonymous / non-staff: empty set
    - Superuser: ALL_ACCESS (sentinel; `'foo' in allowed_sections` → True)
    - Staff: set(user.profile.admin_sections)
    """
    user = getattr(request, 'user', None)
    if not user or not user.is_authenticated:
        return {'allowed_sections': set()}
    if user.is_superuser:
        return {'allowed_sections': ALL_ACCESS}
    if not user.is_staff:
        return {'allowed_sections': set()}
    try:
        sections = set(user.profile.admin_sections or [])
    except Exception:
        logger.warning('Failed to load admin_sections for user %s', user.pk, exc_info=True)
        sections = set()
    # Dashboard is the landing page after login — always accessible to staff
    sections.add('dashboard')
    return {'allowed_sections': sections}
