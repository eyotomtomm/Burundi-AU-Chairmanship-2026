"""
Firebase Admin SDK initialization and utilities for the Be 4 Africa backend.

This module initializes the Firebase Admin SDK and provides functions for verifying
Firebase ID tokens sent from the Flutter mobile app.
"""

import os
import re
import json
import logging
import firebase_admin
from firebase_admin import credentials, auth, messaging
from django.conf import settings

logger = logging.getLogger(__name__)


class FirebaseTokenRevoked(Exception):
    """Raised when a Firebase ID token has been revoked (user disabled/signed out)."""

    def __init__(self, uid, message='Firebase token has been revoked'):
        self.uid = uid
        super().__init__(message)


def _parse_firebase_json(raw):
    """
    Parse Firebase credentials JSON that may have been mangled by the
    hosting platform.  DO App Platform and similar PaaS providers often
    inject real newline/tab characters into the env var value, breaking
    the JSON private_key field.  We try several repair strategies.
    """
    # Strategy 1: parse as-is
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    # Strategy 2: replace literal two-char \\n with real newlines
    try:
        return json.loads(raw.replace('\\n', '\n'))
    except json.JSONDecodeError:
        pass

    # Strategy 3: the platform turned \n inside the private_key into real
    # newlines/whitespace — extract the key, collapse it, and rebuild.
    try:
        # Find the private_key value (everything between its quotes)
        match = re.search(
            r'"private_key"\s*:\s*"(.*?)"',
            raw,
            re.DOTALL,
        )
        if match:
            broken_key = match.group(1)
            # Replace real whitespace sequences with the literal \n that
            # PEM format expects between base64 lines.
            fixed_key = re.sub(r'\s*\n\s*', '\\n', broken_key)
            fixed_json = raw[:match.start(1)] + fixed_key + raw[match.end(1):]
            return json.loads(fixed_json)
    except (json.JSONDecodeError, ValueError):
        pass

    raise json.JSONDecodeError("All Firebase JSON repair strategies failed", raw, 0)


def initialize_firebase():
    """
    Initialize Firebase Admin SDK with service account credentials.

    Supports two methods (checked in order):
    1. FIREBASE_CREDENTIALS_JSON env var — JSON string of the service account key
       (ideal for DigitalOcean App Platform and other PaaS)
    2. File path — FIREBASE_CREDENTIALS_PATH env var or default location
    """
    if not firebase_admin._apps:
        cred = None

        # Method 1: JSON string from environment variable
        cred_json = os.environ.get('FIREBASE_CREDENTIALS_JSON', '')
        if cred_json:
            try:
                cred_dict = _parse_firebase_json(cred_json)
                cred = credentials.Certificate(cred_dict)
                logger.info("Firebase Admin SDK initialized from FIREBASE_CREDENTIALS_JSON env var")
            except (json.JSONDecodeError, ValueError) as e:
                logger.warning(
                    "FIREBASE_CREDENTIALS_JSON env var failed to parse: %s — "
                    "falling back to credentials file.", e
                )

        # Method 2: File path (also used as fallback if env var is malformed)
        if cred is None:
            cred_path = os.environ.get(
                'FIREBASE_CREDENTIALS_PATH',
                os.path.join(settings.BASE_DIR, 'config', 'firebase-adminsdk.json')
            )

            if not os.path.exists(cred_path):
                raise FileNotFoundError(
                    f"Firebase credentials file not found at: {cred_path}\n"
                    f"Either set FIREBASE_CREDENTIALS_JSON env var with the JSON content,\n"
                    f"or download the service account key from Firebase Console and place it at this location."
                )

            cred = credentials.Certificate(cred_path)
            logger.info(f"Firebase Admin SDK initialized from file: {cred_path}")

        firebase_admin.initialize_app(cred)


def verify_firebase_token(id_token, check_revoked=False):
    """
    Verify a Firebase ID token and return the decoded token.

    Args:
        id_token (str): The Firebase ID token to verify
        check_revoked (bool): When True, makes an additional request to
            Firebase to verify the token has not been revoked (user signed
            out everywhere, account disabled, etc.).  Adds latency but
            closes the window where a revoked token is accepted until its
            natural expiry (~1 hour).

    Returns:
        dict: Decoded token containing uid, email, email_verified, etc.

    Raises:
        ValueError: If token is invalid, expired, revoked, or verification fails
    """
    if not firebase_admin._apps:
        raise ValueError("Firebase Admin SDK is not initialized. Check server credentials.")
    try:
        decoded_token = auth.verify_id_token(id_token, check_revoked=check_revoked)
        return decoded_token
    except auth.InvalidIdTokenError:
        raise ValueError("Invalid Firebase ID token")
    except auth.ExpiredIdTokenError:
        raise ValueError("Firebase ID token has expired")
    except auth.RevokedIdTokenError:
        # Re-verify without revocation check to extract the UID
        try:
            decoded = auth.verify_id_token(id_token, check_revoked=False)
            raise FirebaseTokenRevoked(uid=decoded['uid'])
        except FirebaseTokenRevoked:
            raise
        except Exception:
            raise ValueError("Firebase ID token has been revoked")
    except Exception as e:
        raise ValueError(f"Firebase token verification failed: {str(e)}")


def get_firebase_user(uid):
    """
    Get Firebase user record by UID.

    Args:
        uid (str): Firebase user UID

    Returns:
        UserRecord: Firebase user record

    Raises:
        ValueError: If user not found
    """
    try:
        return auth.get_user(uid)
    except auth.UserNotFoundError:
        raise ValueError(f"Firebase user not found: {uid}")
    except Exception as e:
        raise ValueError(f"Failed to get Firebase user: {str(e)}")


# Initialize Firebase when module is imported
try:
    initialize_firebase()
except FileNotFoundError as e:
    logger.warning(f"Firebase credentials missing: {e}")
    logger.warning(
        "Firebase Admin SDK will not be available until credentials are configured.\n"
        "Set FIREBASE_CREDENTIALS_JSON env var with the service account key JSON,\n"
        "or place firebase-adminsdk.json in the config/ directory."
    )
except Exception as e:
    logger.warning(f"Firebase initialization failed: {e}")
