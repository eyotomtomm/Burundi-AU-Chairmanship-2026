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

        # CSP for admin panel — allow same-origin plus CDNs used by the
        # admin templates (Tailwind, Chart.js, Google Fonts, Cropper.js)
        # and the Spaces CDN for media uploads.
        spaces_cdn = getattr(settings, 'DO_SPACES_ENDPOINT', '')
        spaces_bucket = getattr(settings, 'MEDIA_URL', '')
        img_sources = "'self' data:"
        if spaces_cdn:
            img_sources += f" {spaces_cdn}"
        if spaces_bucket and spaces_bucket.startswith('http'):
            img_sources += f" {spaces_bucket.rstrip('/')}"
        self._admin_csp = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' "
            "cdn.tailwindcss.com cdn.jsdelivr.net; "
            "style-src 'self' 'unsafe-inline' "
            "fonts.googleapis.com cdn.jsdelivr.net; "
            f"img-src {img_sources}; "
            "font-src 'self' fonts.gstatic.com; "
            "connect-src 'self'; "
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
