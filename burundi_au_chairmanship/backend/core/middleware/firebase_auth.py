"""
Firebase Authentication Middleware for Django REST Framework

This middleware authenticates users by verifying Firebase ID tokens
sent in the Authorization header. It works alongside the existing
JWT authentication for backward compatibility during migration.
"""

from django.contrib.auth.models import AnonymousUser
from config.firebase import verify_firebase_token
from core.models import UserProfile


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

        # Check if it's a Bearer token
        if auth_header.startswith('Bearer '):
            id_token = auth_header.split('Bearer ')[1].strip()

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
                    # Firebase user exists but not in Django - set AnonymousUser
                    request.user = AnonymousUser()

            except (ValueError, Exception):
                # Invalid token or verification failed - set AnonymousUser
                # This allows the request to proceed but as anonymous
                request.user = AnonymousUser()

        response = self.get_response(request)
        return response
