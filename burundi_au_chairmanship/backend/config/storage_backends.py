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


class SpacesMediaStorage(S3Boto3Storage):
    def exists(self, name):
        try:
            return super().exists(name)
        except ClientError as e:
            error_code = int(e.response['ResponseMetadata']['HTTPStatusCode'])
            if error_code == 403:
                logger.warning(
                    "S3 head_object returned 403 for '%s'; assuming file does not exist.",
                    name,
                )
                return False
            raise
