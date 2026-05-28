"""
Custom S3 storage backend that handles DigitalOcean Spaces permission issues.

Spaces returns 403 Forbidden on head_object calls, which Django's default
S3 storage uses in exists() to check for filename collisions. This backend
catches that error and falls back to assuming the file doesn't exist, allowing
uploads to proceed.
"""

import logging

from botocore.exceptions import ClientError
from storages.backends.s3boto3 import S3Boto3Storage

logger = logging.getLogger(__name__)


class S3CredentialsError(OSError):
    """Raised when S3/Spaces credentials are invalid or expired."""
    pass


class SpacesMediaStorage(S3Boto3Storage):
    # Auth-related S3 error codes that indicate bad credentials
    _AUTH_ERROR_CODES = {'InvalidAccessKeyId', 'SignatureDoesNotMatch', 'AccessDenied'}

    def exists(self, name):
        try:
            return super().exists(name)
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            http_status = int(e.response['ResponseMetadata']['HTTPStatusCode'])
            if http_status == 403 or error_code in self._AUTH_ERROR_CODES:
                logger.warning(
                    "S3 head_object returned %s/%s for '%s'; assuming file does not exist.",
                    http_status, error_code, name,
                )
                return False
            raise

    def _save(self, name, content):
        try:
            return super()._save(name, content)
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            if error_code in self._AUTH_ERROR_CODES:
                logger.error(
                    "S3 upload failed for '%s' — credentials error: %s",
                    name, error_code,
                )
                raise S3CredentialsError(
                    'File upload failed: storage credentials are invalid or expired. '
                    'An administrator needs to update the DigitalOcean Spaces API keys '
                    'in the App Platform environment variables.'
                ) from e
            raise
