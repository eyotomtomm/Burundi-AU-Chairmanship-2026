import sys
import traceback
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView, RedirectView
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from graphene_django.views import GraphQLView


def handler500_view(request):
    """Show actual error details for staff users, generic message for others."""
    from django.utils.html import escape as html_escape
    exc_type, exc_value, exc_tb = sys.exc_info()
    if request.user.is_authenticated and request.user.is_staff:
        tb = traceback.format_exception(exc_type, exc_value, exc_tb)
        return HttpResponse(
            '<h1>Server Error (500)</h1><pre>' + html_escape(''.join(tb)) + '</pre>',
            status=500,
            content_type='text/html',
        )
    return HttpResponse('<h1>Server Error (500)</h1>', status=500)


handler500 = 'config.urls.handler500_view'


def _s3_diag(request):
    """Temporary diagnostic: test DigitalOcean Spaces connectivity."""
    import json as _json
    result = {}
    key = settings.AWS_ACCESS_KEY_ID if hasattr(settings, 'AWS_ACCESS_KEY_ID') else ''
    secret = settings.AWS_SECRET_ACCESS_KEY if hasattr(settings, 'AWS_SECRET_ACCESS_KEY') else ''
    bucket = getattr(settings, 'AWS_STORAGE_BUCKET_NAME', '')
    endpoint = getattr(settings, 'AWS_S3_ENDPOINT_URL', '')
    result['env'] = {
        'DO_SPACES_KEY': f'{key[:4]}...{key[-4:]}' if len(key) > 8 else f'(len={len(key)})',
        'DO_SPACES_SECRET': f'{secret[:4]}...{secret[-4:]}' if len(secret) > 8 else f'(len={len(secret)})',
        'DO_SPACES_BUCKET': bucket,
        'DO_SPACES_ENDPOINT': endpoint,
        'DEFAULT_FILE_STORAGE': getattr(settings, 'DEFAULT_FILE_STORAGE', 'default'),
        'DEBUG': settings.DEBUG,
    }
    # Test actual S3 connection
    try:
        import boto3
        session = boto3.session.Session()
        client = session.client(
            's3',
            region_name='fra1',
            endpoint_url=endpoint,
            aws_access_key_id=key,
            aws_secret_access_key=secret,
        )
        resp = client.list_objects_v2(Bucket=bucket, MaxKeys=1)
        result['s3_test'] = 'OK'
        result['s3_key_count'] = resp.get('KeyCount', 0)
    except Exception as e:
        result['s3_test'] = 'FAILED'
        result['s3_error'] = str(e)
        result['s3_error_type'] = type(e).__name__
    return HttpResponse(
        _json.dumps(result, indent=2),
        content_type='application/json',
    )


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
    # Temporary S3 diagnostic (remove after fixing)
    path('api/s3-diag/', _s3_diag, name='s3-diag'),
    # OpenAPI schema & documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
    # GraphQL API (graphiql only in DEBUG; auth required via DRF LoginRequiredMiddleware)
    path('api/graphql/', csrf_exempt(GraphQLView.as_view(graphiql=settings.DEBUG)), name='graphql'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
