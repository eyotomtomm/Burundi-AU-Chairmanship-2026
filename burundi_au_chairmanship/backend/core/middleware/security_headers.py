"""
Middleware that injects Permissions-Policy and Content-Security-Policy headers.

- Permissions-Policy applies to ALL responses (disables unused browser APIs).
- CSP is scoped to the admin panel only (/admin/ paths) because the JSON API
  doesn't serve HTML and doesn't benefit from CSP.

Configuration lives in settings.PERMISSIONS_POLICY (dict mapping feature → allowlist).
"""

from django.conf import settings


class SecurityHeadersMiddleware:
    """Add Permissions-Policy to every response and CSP to admin responses."""

    def __init__(self, get_response):
        self.get_response = get_response
        # Pre-build the Permissions-Policy header value once at startup.
        policy_dict = getattr(settings, 'PERMISSIONS_POLICY', {})
        parts = []
        for feature, allowlist in policy_dict.items():
            if not allowlist:
                parts.append(f'{feature}=()')
            else:
                sources = ' '.join(f'"{s}"' for s in allowlist)
                parts.append(f'{feature}=({sources})')
        self._permissions_policy = ', '.join(parts)

        # CSP for admin panel — allow same-origin styles/scripts/images plus
        # inline styles (Django admin uses them) and the Spaces CDN for media.
        spaces_cdn = getattr(settings, 'DO_SPACES_ENDPOINT', '')
        img_src = f"'self' data: {spaces_cdn}" if spaces_cdn else "'self' data:"
        self._admin_csp = (
            "default-src 'self'; "
            f"script-src 'self'; "
            f"style-src 'self' 'unsafe-inline'; "
            f"img-src {img_src}; "
            "font-src 'self'; "
            "frame-ancestors 'self'; "
            "form-action 'self'; "
            "base-uri 'self'"
        )

    def __call__(self, request):
        response = self.get_response(request)

        if self._permissions_policy:
            response['Permissions-Policy'] = self._permissions_policy

        # Only apply CSP to admin HTML pages, not to API JSON responses.
        if request.path.startswith('/admin/'):
            response['Content-Security-Policy'] = self._admin_csp

        return response
