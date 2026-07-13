from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView, RedirectView
from django.http import HttpResponse, HttpResponseRedirect
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from core.views import verify_qr_web


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
    # Smart app redirect — detects iOS/Android and opens the right store
    path('app', open_app, name='open-app'),
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
