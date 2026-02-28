"""
Firebase Authentication Middleware for Django REST Framework

This middleware authenticates users by verifying Firebase ID tokens
sent in the Authorization header. It works alongside the existing
JWT authentication for backward compatibility during migration.
"""

from django.contrib.auth.models import AnonymousUser
from django.http import JsonResponse
from config.firebase import verify_firebase_token
from core.models import UserProfile
import logging

logger = logging.getLogger(__name__)


class FirebaseAuthenticationMiddleware:
    """
    Middleware to authenticate requests using Firebase ID tokens.

    Extracts the Firebase ID token from the Authorization header,
    verifies it, and sets request.user to the authenticated user.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Get Authorization header
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')

        # Check if it's a Bearer token (could be Firebase or JWT)
        if auth_header.startswith('Bearer '):
            id_token = auth_header.split('Bearer ')[1].strip()

            # Only try Firebase auth if token looks like Firebase token
            # JWT tokens start with 'eyJ', Firebase tokens are longer (~900+ chars)
            # Skip Firebase verification for short tokens (likely JWT)
            if len(id_token) < 100:
                # Likely a JWT token, let JWTAuthentication handle it
                response = self.get_response(request)
                return response

            # Try to verify Firebase token
            try:
                decoded_token = verify_firebase_token(id_token)
                firebase_uid = decoded_token['uid']

                # Find user by Firebase UID
                try:
                    profile = UserProfile.objects.select_related('user').get(
                        firebase_uid=firebase_uid
                    )
                    request.user = profile.user

                    # Update email verification status if changed
                    email_verified = decoded_token.get('email_verified', False)
                    if profile.is_email_verified != email_verified:
                        profile.is_email_verified = email_verified
                        profile.save(update_fields=['is_email_verified'])

                except UserProfile.DoesNotExist:
                    # Firebase user exists but not registered in Django
                    logger.warning(f'Firebase user {firebase_uid} not found in database')
                    return JsonResponse({
                        'detail': 'User not found. Please register first.'
                    }, status=401)

            except ValueError as e:
                # Invalid Firebase token (expired, malformed, wrong signature)
                logger.warning(f'Invalid Firebase token: {str(e)}')
                return JsonResponse({
                    'detail': 'Invalid or expired authentication token.'
                }, status=401)

            except Exception as e:
                # Unexpected error during Firebase auth
                logger.error(f'Firebase authentication error: {str(e)}')
                return JsonResponse({
                    'detail': 'Authentication failed.'
                }, status=401)

        response = self.get_response(request)
        return response
