"""
Firebase Admin SDK initialization and utilities for the Burundi AU Chairmanship backend.

This module initializes the Firebase Admin SDK and provides functions for verifying
Firebase ID tokens sent from the Flutter mobile app.
"""

import os
import firebase_admin
from firebase_admin import credentials, auth
from django.conf import settings


def initialize_firebase():
    """
    Initialize Firebase Admin SDK with service account credentials.
    This should be called once when Django starts up.
    """
    if not firebase_admin._apps:
        # Get credentials path from environment variable or use default
        cred_path = os.environ.get(
            'FIREBASE_CREDENTIALS_PATH',
            os.path.join(settings.BASE_DIR, 'config', 'firebase-adminsdk.json')
        )

        if not os.path.exists(cred_path):
            raise FileNotFoundError(
                f"Firebase credentials file not found at: {cred_path}\n"
                f"Please download the service account key from Firebase Console and place it at this location.\n"
                f"See FIREBASE_SETUP_GUIDE.md for instructions."
            )

        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        print(f"Firebase Admin SDK initialized with credentials from: {cred_path}")


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
    print(f"WARNING: {e}")
    print("Firebase Admin SDK will not be available until credentials are configured.")
