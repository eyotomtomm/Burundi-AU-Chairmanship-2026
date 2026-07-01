"""DRF permission classes.

Includes:
  - ``IsVerifiedUser`` — authenticated *and* email-verified (DRF default).
  - ``HasAdminSection`` — staff + admin-portal section check.

Usage::

    from core.permissions import IsVerifiedUser, HasAdminSection

    @api_view(['GET'])
    @permission_classes([HasAdminSection.for_section('articles_list')])
    def article_drafts(request):
        ...
"""

from rest_framework.permissions import BasePermission, IsAuthenticated


class IsVerifiedUser(IsAuthenticated):
    """Authenticated user whose email address has been verified.

    Staff and superusers bypass the email-verification check so admin
    endpoints remain accessible regardless of verification state.

    Endpoints that must work for unverified users (OTP send/verify,
    profile view, FCM token management, logout, etc.) should explicitly
    set ``permission_classes = [IsAuthenticated]`` to opt out.
    """

    message = 'Please verify your email address to perform this action.'

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        user = request.user
        # Staff/superusers bypass — admin access should never be blocked
        # by the app-level email verification flow.
        if user.is_staff:
            return True
        profile = getattr(user, 'profile', None)
        if profile is None:
            return False
        return bool(profile.is_email_verified)


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
