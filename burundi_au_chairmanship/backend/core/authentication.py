import logging
from rest_framework import authentication
from rest_framework import exceptions
from django.contrib.auth.models import User
from config.firebase import verify_firebase_token
from .models import UserProfile

logger = logging.getLogger(__name__)


class FirebaseAuthentication(authentication.BaseAuthentication):
    """
    Custom authentication backend for Firebase ID tokens.
    Verifies Firebase tokens and returns the associated Django user.
    """

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')

        if not auth_header.startswith('Bearer '):
            return None

        token = auth_header.split('Bearer ')[1]

        try:
            # Verify Firebase token
            decoded_token = verify_firebase_token(token)
            firebase_uid = decoded_token['uid']

            # Find user by Firebase UID
            try:
                profile = UserProfile.objects.select_related('user').get(firebase_uid=firebase_uid)
                return (profile.user, None)
            except UserProfile.DoesNotExist:
                raise exceptions.AuthenticationFailed('User not found')

        except ValueError:
            # Invalid Firebase token
            return None  # Let other auth backends try
        except exceptions.AuthenticationFailed:
            raise
        except Exception as e:
            logger.exception('Firebase authentication error')
            raise exceptions.AuthenticationFailed('Authentication failed')

    def authenticate_header(self, request):
        return 'Bearer'
