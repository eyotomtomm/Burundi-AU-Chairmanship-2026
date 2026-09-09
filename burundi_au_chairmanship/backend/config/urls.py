import os
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView, RedirectView
from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from core.views import verify_qr_web, register_web, share_card, share_card_image


def open_app(request):
    """Try to open the app via deep link, fall back to the correct app store."""
    ua = (request.META.get('HTTP_USER_AGENT', '') or '').lower()
    deep_link = 'b4africa://youth-dialogue'
    ios_store = 'https://apps.apple.com/app/b4africa-burundi-chairmanship/id6740047505'
    android_store = 'https://play.google.com/store/apps/details?id=com.b4africa.app'

    if 'android' in ua:
        fallback = android_store
    else:
        fallback = ios_store

    # Serve a small page that tries the deep link first, then falls back to the store
    html = f'''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Opening B4Africa...</title></head>
<body style="margin:0;display:flex;align-items:center;justify-content:center;height:100vh;
font-family:-apple-system,sans-serif;background:#f0f4f0;color:#333;text-align:center;">
<div><p style="font-size:18px;font-weight:600;">Opening B4Africa...</p>
<p style="font-size:14px;color:#718096;">If the app doesn't open, <a href="{fallback}" style="color:#409843;font-weight:700;">download it here</a>.</p></div>
<script>
window.location.href = "{deep_link}";
setTimeout(function() {{ window.location.href = "{fallback}"; }}, 2500);
</script>
</body></html>'''
    return HttpResponse(html)



# ══════════════════════════════════════════════════════════════
# Universal Links (iOS) / App Links (Android) site association
# Both platforms fetch these over HTTPS with no redirects; they must be
# served as JSON from the apex domain itself.
# ══════════════════════════════════════════════════════════════

APPLE_APP_ID = '4P52QG4BDR.com.b4africa.app'
ANDROID_PACKAGE = 'com.b4africa.app'
# Both certificates must be listed: releases are signed with the upload key,
# then Play re-signs the store build with the Play App Signing key, and that is
# the signature devices actually verify. Both fingerprints are public — they are
# served from this file at /.well-known/assetlinks.json — so they live in source
# rather than in secrets. Verified against Play Console → App signing on
# 2026-09-03. ANDROID_PLAY_SIGNING_SHA256 (comma-separated) appends any extra
# certificate, e.g. during a key rotation, without a code change.
ANDROID_SHA256_FINGERPRINTS = [
    # Upload key (signs what we send to Play).
    '2E:76:17:60:16:F9:E0:31:54:64:0F:47:91:12:C0:5F:45:AD:C6:B5:18:A0:D9:4B:A4:6E:FD:9D:E0:DC:D0:67',
    # Play App Signing key (signs what users install) — required for verification.
    'A6:A6:09:FB:77:77:FE:20:CF:BC:9A:51:19:9E:87:28:39:7E:E2:35:71:0A:4F:1E:7B:D6:D4:07:7B:1A:DF:6B',
    *[f.strip().upper() for f in os.environ.get('ANDROID_PLAY_SIGNING_SHA256', '').split(',') if f.strip()],
]


def apple_app_site_association(request):
    """Claim /<kind>/<id>/share/ for the iOS app; the rest of the site stays web."""
    return JsonResponse({
        'applinks': {
            'details': [{
                'appIDs': [APPLE_APP_ID],
                'components': [
                    {'/': '/*/*/share/', 'comment': 'Shared content opens in the app'},
                    {'/': '/*/*/share', 'comment': 'Shared content opens in the app'},
                ],
            }],
        },
    }, content_type='application/json')


def android_assetlinks(request):
    """Same claim for Android App Links verification."""
    return JsonResponse([{
        'relation': ['delegate_permission/common.handle_all_urls'],
        'target': {
            'namespace': 'android_app',
            'package_name': ANDROID_PACKAGE,
            'sha256_cert_fingerprints': ANDROID_SHA256_FINGERPRINTS,
        },
    }], safe=False, content_type='application/json')


def handler500_view(request):
    """Generic 500 error page. Detailed tracebacks are handled by Sentry."""
    return HttpResponse('<h1>Server Error (500)</h1>', status=500)


handler500 = 'config.urls.handler500_view'


urlpatterns = [
    # Public landing page
    path('', TemplateView.as_view(template_name='landing.html'), name='landing'),
    path('admin/', include('custom_admin.urls')),
    path('api/', include('core.urls')),
    path('api/v1/', include('core.urls')),  # Versioned API alias
    # Public legal pages (for Play Store / App Store listing)
    path('privacy-policy/', TemplateView.as_view(template_name='legal/privacy_policy.html'), name='privacy-policy'),
    path('terms-of-service/', TemplateView.as_view(template_name='legal/terms_of_service.html'), name='terms-of-service'),
    path('support/', TemplateView.as_view(template_name='legal/support.html'), name='support'),
    path('delete-account/', TemplateView.as_view(template_name='legal/delete_account.html'), name='delete-account'),
    # Public QR verification page (scanned by any phone camera)
    path('verify', verify_qr_web, name='verify-qr-web'),
    # Public web registration for Continental Dialogue
    path('register', register_web, name='register-web'),
    # Smart app redirect — detects iOS/Android and opens the right store
    path('app', open_app, name='open-app'),
    # App/site association for Universal Links and App Links
    path('.well-known/apple-app-site-association', apple_app_site_association),
    path('apple-app-site-association', apple_app_site_association),
    path('.well-known/assetlinks.json', android_assetlinks),
    # Public share cards: /articles/5/share/, /magazines/2/share/, /events/7/share/, ...
    path('<slug:kind>/<int:pk>/share/', share_card, name='share-card'),
    # Rendered 1200x630 preview image referenced by the share page's og:image.
    path('<slug:kind>/<int:pk>/card.jpg', share_card_image, name='share-card-image'),
]

# OpenAPI schema & documentation — staff-only in production, open in DEBUG
if settings.DEBUG:
    urlpatterns += [
        path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
        path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
        path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    ]
else:
    from rest_framework.permissions import IsAdminUser
    urlpatterns += [
        path('api/schema/', SpectacularAPIView.as_view(permission_classes=[IsAdminUser]), name='schema'),
        path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema', permission_classes=[IsAdminUser]), name='swagger-ui'),
        path('api/redoc/', SpectacularRedocView.as_view(url_name='schema', permission_classes=[IsAdminUser]), name='redoc'),
    ]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
