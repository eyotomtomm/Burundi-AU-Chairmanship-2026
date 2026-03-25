"""
File upload validators for the Burundi AU Chairmanship backend.
"""
from django.core.exceptions import ValidationError
from django.conf import settings
import os


def validate_image_file(file):
    """
    Validate uploaded image file size, extension, and content type.
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

    # Validate actual file content (magic bytes)
    VALID_IMAGE_MIMES = {
        b'\xff\xd8\xff': 'jpg',       # JPEG
        b'\x89PNG': 'png',            # PNG
        b'GIF87a': 'gif',             # GIF87a
        b'GIF89a': 'gif',             # GIF89a
        b'RIFF': 'webp',             # WebP (starts with RIFF)
    }
    file.seek(0)
    header = file.read(8)
    file.seek(0)

    valid_content = False
    for magic, _ in VALID_IMAGE_MIMES.items():
        if header[:len(magic)] == magic:
            valid_content = True
            break

    if not valid_content:
        raise ValidationError('File content does not match a valid image format.')

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


def validate_professional_email(email):
    """
    Validate that email is from a professional/organizational domain.
    Blocks consumer email providers (gmail, yahoo, outlook, hotmail, etc.)
    """
    if not email:
        raise ValidationError('Email cannot be empty')

    # List of blocked consumer email domains
    BLOCKED_DOMAINS = [
        'gmail.com', 'googlemail.com',
        'yahoo.com', 'yahoo.co.uk', 'yahoo.fr', 'yahoo.de', 'yahoo.ca', 'yahoo.in',
        'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
        'aol.com',
        'icloud.com', 'me.com', 'mac.com',
        'protonmail.com', 'proton.me',
        'mail.com',
        'zoho.com',
        'yandex.com', 'yandex.ru',
        'gmx.com', 'gmx.de',
        'mail.ru',
        'qq.com',
        '163.com',
        '126.com',
    ]

    # Extract domain from email
    try:
        domain = email.split('@')[1].lower()
    except IndexError:
        raise ValidationError('Invalid email format')

    # Check if domain is blocked
    if domain in BLOCKED_DOMAINS:
        raise ValidationError(
            f'Please use a professional/organizational email address. '
            f'Consumer email providers like {domain} are not accepted for verification.'
        )

    return email
