"""DRF permission classes that enforce the same section-based access control
used by the custom admin HTML portal.

Usage::

    from core.permissions import HasAdminSection

    @api_view(['GET'])
    @permission_classes([HasAdminSection.for_section('articles_list')])
    def article_drafts(request):
        ...
"""

from rest_framework.permissions import BasePermission


class HasAdminSection(BasePermission):
    """Require ``is_staff`` *and* the specified admin-portal section.

    Superusers bypass the section check.  The required section is set via
    the ``for_section()`` class method which returns a one-off subclass
    with ``required_section`` baked in.
    """

    required_section: str | None = None

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_superuser:
            return True
        if not user.is_staff:
            return False
        if self.required_section is None:
            # No section specified — fall back to plain is_staff check.
            return True
        try:
            allowed = user.profile.admin_sections or []
        except Exception:
            allowed = []
        return self.required_section in allowed

    @classmethod
    def for_section(cls, section_key: str):
        """Return a permission class bound to a specific admin section."""
        return type(
            f"HasAdminSection_{section_key}",
            (cls,),
            {"required_section": section_key},
        )
