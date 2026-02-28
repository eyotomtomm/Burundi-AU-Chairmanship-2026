"""
File upload validators for the Burundi AU Chairmanship backend.
"""
from django.core.exceptions import ValidationError
from django.conf import settings
import os


def validate_image_file(file):
    """
    Validate uploaded image file size and extension.
    """
    # Check file size
    if file.size > settings.MAX_IMAGE_SIZE:
        raise ValidationError(
            f'Image file too large. Maximum size is {settings.MAX_IMAGE_SIZE / (1024 * 1024)}MB.'
        )

    # Check extension
    ext = os.path.splitext(file.name)[1][1:].lower()
    if ext not in settings.ALLOWED_IMAGE_EXTENSIONS:
        raise ValidationError(
            f'Invalid image format. Allowed formats: {", ".join(settings.ALLOWED_IMAGE_EXTENSIONS)}'
        )

    return file


def validate_document_file(file):
    """
    Validate uploaded document file size and extension.
    """
    # Check file size
    if file.size > settings.MAX_DOCUMENT_SIZE:
        raise ValidationError(
            f'Document file too large. Maximum size is {settings.MAX_DOCUMENT_SIZE / (1024 * 1024)}MB.'
        )

    # Check extension
    ext = os.path.splitext(file.name)[1][1:].lower()
    if ext not in settings.ALLOWED_DOCUMENT_EXTENSIONS:
        raise ValidationError(
            f'Invalid document format. Allowed formats: {", ".join(settings.ALLOWED_DOCUMENT_EXTENSIONS)}'
        )

    return file


def validate_fcm_token(token):
    """
    Validate Firebase Cloud Messaging token format.
    """
    if not token:
        raise ValidationError('FCM token cannot be empty')

    if not isinstance(token, str):
        raise ValidationError('FCM token must be a string')

    # FCM tokens are typically 152-163 characters
    if len(token) < 100 or len(token) > 200:
        raise ValidationError('Invalid FCM token format')

    return token
