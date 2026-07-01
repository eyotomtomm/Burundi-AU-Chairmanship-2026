import logging
from rest_framework import authentication
from rest_framework import exceptions
from django.contrib.auth.models import User
from config.firebase import verify_firebase_token, FirebaseTokenRevoked
from .models import UserProfile

logger = logging.getLogger(__name__)


class FirebaseAuthentication(authentication.BaseAuthentication):
    """
    DRF authentication backend for Firebase ID tokens.

    This is the single layer that verifies Firebase tokens for API
    requests.  It checks token revocation so that disabled / signed-out
    Firebase accounts are rejected immediately rather than riding a
    stale token for up to an hour.

    The companion JWTAuthentication backend in DEFAULT_AUTHENTICATION_CLASSES
    handles SimpleJWT tokens — when a token fails Firebase verification this
    class returns None so the next backend can try.
    """

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')

        if not auth_header.startswith('Bearer '):
            return None

        token = auth_header.split('Bearer ')[1].strip()

        try:
            decoded_token = verify_firebase_token(token, check_revoked=True)
            firebase_uid = decoded_token['uid']

            try:
                profile = UserProfile.objects.select_related('user').get(
                    firebase_uid=firebase_uid,
                )

                # Sync email-verification from Firebase — only UPGRADE
                # (False→True), never downgrade.  The app uses its own
                # OTP-based email verification flow; if Firebase's
                # email_verified claim is False that does NOT mean the
                # user hasn't verified via OTP.
                fb_email_verified = decoded_token.get('email_verified', False)
                if fb_email_verified and not profile.is_email_verified:
                    profile.is_email_verified = True
                    profile.save(update_fields=['is_email_verified'])

                return (profile.user, decoded_token)
            except UserProfile.DoesNotExist:
                raise exceptions.AuthenticationFailed('User not found')

        except FirebaseTokenRevoked as e:
            # Firebase account revoked — cascade to Django: deactivate user
            # and blacklist all outstanding JWT refresh tokens.
            try:
                profile = UserProfile.objects.select_related('user').get(
                    firebase_uid=e.uid,
                )
                user = profile.user
                user.is_active = False
                user.save(update_fields=['is_active'])
                # Blacklist all outstanding refresh tokens
                from rest_framework_simplejwt.token_blacklist.models import (
                    OutstandingToken, BlacklistedToken,
                )
                for token in OutstandingToken.objects.filter(user=user):
                    BlacklistedToken.objects.get_or_create(token=token)
                logger.warning(
                    'Deactivated user %s (firebase_uid=%s) due to revoked Firebase token',
                    user.pk, e.uid,
                )
            except UserProfile.DoesNotExist:
                logger.warning(
                    'Revoked Firebase token for unknown uid=%s', e.uid,
                )
            raise exceptions.AuthenticationFailed('Account has been disabled')
        except ValueError:
            # Not a valid Firebase token — let the next auth backend
            # (JWTAuthentication) try instead.
            return None
        except exceptions.AuthenticationFailed:
            raise
        except Exception as e:
            logger.exception('Firebase authentication error')
            raise exceptions.AuthenticationFailed('Authentication failed')

    def authenticate_header(self, request):
        return 'Bearer'
