"""
Middleware to catch S3/Spaces credential errors during file uploads and
convert them into user-friendly Django messages instead of 500 errors.
"""
import logging

from django.contrib import messages
from django.shortcuts import redirect

logger = logging.getLogger(__name__)


class S3UploadErrorMiddleware:
    """Catch S3 credential / upload errors on POST requests and show a
    friendly message instead of a 500 page."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        # Only handle POST requests (form submissions with file uploads)
        if request.method != 'POST':
            return None

        # Check for our custom S3CredentialsError
        from config.storage_backends import S3CredentialsError
        if isinstance(exception, S3CredentialsError):
            logger.error('S3 credentials error during upload: %s', exception)
            messages.error(
                request,
                'File upload failed: storage credentials are invalid or expired. '
                'Please contact the administrator to update the DigitalOcean Spaces API keys.'
            )
            return redirect(request.path)

        # Also catch raw botocore ClientError that might slip through
        try:
            from botocore.exceptions import ClientError
            if isinstance(exception, ClientError):
                error_code = exception.response.get('Error', {}).get('Code', '')
                logger.error('S3 ClientError during request: %s (code=%s)', exception, error_code)
                messages.error(
                    request,
                    'File upload failed due to a storage service error. '
                    'Please try again or contact the administrator.'
                )
                return redirect(request.path)
        except ImportError:
            pass

        return None
