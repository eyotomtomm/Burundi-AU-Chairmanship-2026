import sys
import traceback
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView, RedirectView
from django.http import HttpResponse


def handler500_view(request):
    """Show actual error details for staff users, generic message for others."""
    exc_type, exc_value, exc_tb = sys.exc_info()
    if request.user.is_authenticated and request.user.is_staff:
        tb = traceback.format_exception(exc_type, exc_value, exc_tb)
        return HttpResponse(
            '<h1>Server Error (500)</h1><pre>' + ''.join(tb) + '</pre>',
            status=500,
            content_type='text/html',
        )
    return HttpResponse('<h1>Server Error (500)</h1>', status=500)


handler500 = 'config.urls.handler500_view'

urlpatterns = [
    # Root redirects to admin panel
    path('', RedirectView.as_view(url='/admin/', permanent=False)),
    path('admin/', include('custom_admin.urls')),
    path('api/', include('core.urls')),
    # Public legal pages (for Play Store / App Store listing)
    path('privacy-policy/', TemplateView.as_view(template_name='legal/privacy_policy.html'), name='privacy-policy'),
    path('terms-of-service/', TemplateView.as_view(template_name='legal/terms_of_service.html'), name='terms-of-service'),
    path('support/', TemplateView.as_view(template_name='legal/support.html'), name='support'),
    path('delete-account/', TemplateView.as_view(template_name='legal/delete_account.html'), name='delete-account'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
