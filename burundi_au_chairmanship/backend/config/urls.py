from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView, RedirectView
from django.http import HttpResponse
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from core.views import verify_qr_web


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
