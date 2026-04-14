"""
Firebase Admin SDK initialization and utilities for the Burundi Chairmanship backend.

This module initializes the Firebase Admin SDK and provides functions for verifying
Firebase ID tokens sent from the Flutter mobile app.
"""

import os
import json
import logging
import firebase_admin
from firebase_admin import credentials, auth, messaging
from django.conf import settings

logger = logging.getLogger(__name__)


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
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                logger.info("Firebase Admin SDK initialized from FIREBASE_CREDENTIALS_JSON env var")
            except (json.JSONDecodeError, ValueError) as e:
                raise ValueError(
                    f"Invalid FIREBASE_CREDENTIALS_JSON: {e}\n"
                    f"Ensure the env var contains valid JSON from your Firebase service account key."
                )

        # Method 2: File path
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


def verify_firebase_token(id_token):
    """
    Verify a Firebase ID token and return the decoded token.

    Args:
        id_token (str): The Firebase ID token to verify

    Returns:
        dict: Decoded token containing uid, email, email_verified, etc.

    Raises:
        ValueError: If token is invalid, expired, or verification fails
    """
    if not firebase_admin._apps:
        raise ValueError("Firebase Admin SDK is not initialized. Check server credentials.")
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except auth.InvalidIdTokenError:
        raise ValueError("Invalid Firebase ID token")
    except auth.ExpiredIdTokenError:
        raise ValueError("Firebase ID token has expired")
    except auth.RevokedIdTokenError:
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
