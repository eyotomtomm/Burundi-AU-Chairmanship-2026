import os
from pathlib import Path
from datetime import timedelta
import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv(BASE_DIR / '.env')

# Security: DEBUG should default to False (fail-secure)
# Explicitly set DJANGO_DEBUG=True for development
DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')

# Security: SECRET_KEY MUST be set via environment variable
# No fallback value to prevent accidentally running with known key
try:
    SECRET_KEY = os.environ['DJANGO_SECRET_KEY']
except KeyError:
    raise RuntimeError(
        "CRITICAL: DJANGO_SECRET_KEY environment variable is not set.\n"
        "This is required for security (session cookies, CSRF tokens, JWT signatures).\n\n"
        "Generate a secure key with:\n"
        "  python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'\n\n"
        "Then set it:\n"
        "  export DJANGO_SECRET_KEY='your-generated-key-here'\n\n"
        "For local development, create a .env file or add to your shell profile."
    )

# Security: ALLOWED_HOSTS must be explicitly set
# No default to '*' to prevent Host header attacks
allowed_hosts_env = os.environ.get('DJANGO_ALLOWED_HOSTS', '')
if allowed_hosts_env:
    ALLOWED_HOSTS = [host.strip() for host in allowed_hosts_env.split(',') if host.strip()]
elif DEBUG:
    # Only allow localhost in development
    ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]']
else:
    # Production MUST have explicit ALLOWED_HOSTS
    raise RuntimeError(
        "CRITICAL: DJANGO_ALLOWED_HOSTS environment variable is not set.\n"
        "This is required in production to prevent HTTP Host header attacks.\n\n"
        "Set it to your domain(s):\n"
        "  export DJANGO_ALLOWED_HOSTS='api.burundi4africa.com,burundi4africa.com'\n\n"
        "Multiple hosts should be comma-separated."
    )

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Third party
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',  # For token revocation
    'corsheaders',
    'storages',
    # Local
    'core',
    'custom_admin',
]

MIDDLEWARE = [
    'core.middleware.cloudflare.CloudflareProxyMiddleware',  # Must be first — sets real client IP
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'core.middleware.firebase_auth.FirebaseAuthenticationMiddleware',  # Firebase auth
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ─── Database ──────────────────────────────────────────────────
# Uses PostgreSQL in production (via DATABASE_URL), SQLite locally
DATABASE_URL = os.environ.get('DATABASE_URL')
if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.parse(DATABASE_URL, conn_max_age=600)
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Africa/Bujumbura'
USE_I18N = True
USE_TZ = True

# ─── Static Files (WhiteNoise for production) ─────────────────
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATICFILES_STORAGE = 'whitenoise.storage.CompressedStaticFilesStorage'

# ─── Media Files ───────────────────────────────────────────────
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Absolute base URL for building full media URLs (e.g. push notification images)
SITE_URL = os.environ.get('SITE_URL', 'http://127.0.0.1:8000' if DEBUG else '')

# DigitalOcean Spaces for media files (production only)
if not DEBUG:
    AWS_ACCESS_KEY_ID = os.environ.get('DO_SPACES_KEY')
    AWS_SECRET_ACCESS_KEY = os.environ.get('DO_SPACES_SECRET')
    AWS_STORAGE_BUCKET_NAME = os.environ.get('DO_SPACES_BUCKET')
    AWS_S3_ENDPOINT_URL = os.environ.get('DO_SPACES_ENDPOINT')
    AWS_S3_OBJECT_PARAMETERS = {'CacheControl': 'max-age=86400'}
    AWS_DEFAULT_ACL = 'public-read'
    AWS_QUERYSTRING_AUTH = False
    AWS_S3_FILE_OVERWRITE = False
    AWS_LOCATION = 'media'
    DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
    MEDIA_URL = f'{AWS_S3_ENDPOINT_URL}/{AWS_STORAGE_BUCKET_NAME}/media/'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── Logging ──────────────────────────────────────────────────
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'WARNING',
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'ERROR',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['console'],
            'level': 'ERROR',
            'propagate': False,
        },
        'custom_admin': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
}

# ─── File Upload Settings ──────────────────────────────────────
# Maximum file sizes
DATA_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50 MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50 MB

# Allowed file types for uploads
ALLOWED_IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp']
ALLOWED_DOCUMENT_EXTENSIONS = ['pdf', 'doc', 'docx', 'zip']
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_DOCUMENT_SIZE = 50 * 1024 * 1024  # 50 MB

# ─── CORS — allow Flutter app to connect ──────────────────────
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [
    'https://burundi4africa.com',
    'https://www.burundi4africa.com',
    'https://api.burundi4africa.com',
]
if DEBUG:
    CORS_ALLOWED_ORIGINS += [
        'http://localhost:3000',
        'http://127.0.0.1:8000',
    ]
# ─── DRF settings ─────────────────────────────────────────────
REST_FRAMEWORK = {
    # Security: Default to requiring authentication (fail-secure)
    # Public endpoints must explicitly set permission_classes = [AllowAny]
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'core.authentication.FirebaseAuthentication',  # Try Firebase first
        'rest_framework_simplejwt.authentication.JWTAuthentication',  # Fallback to JWT
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour',
        'view_count': '1/min',  # 1 view per content item per minute (prevents manipulation)
        'like_toggle': '10/min',  # 10 like toggles per minute (prevents spam)
        'auth': '5/min',  # Strict limit on login/register to prevent brute-force
        'otp': '1/min',  # Strict: 1 OTP per minute to prevent abuse
        'otp_verify': '5/min',  # 5 verify attempts per minute before lockout
        'support': '5/hour',  # 5 support tickets per hour per user
        'search': '30/min',  # 30 search requests per minute per user/IP
    },
    # Use real client IP behind Cloudflare / reverse proxies
    'NUM_PROXIES': 1,
}

# ─── JWT settings with auto-logout ────────────────────────────
SIMPLE_JWT = {
    # Security: Short access token lifetime (industry standard: 15-60 minutes)
    # Limits exposure if token is stolen, forces regular re-authentication
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),  # 15 minutes (secure)
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),  # 7 days (good UX for mobile)
    'ROTATE_REFRESH_TOKENS': True,  # Auto-rotate on refresh
    'BLACKLIST_AFTER_ROTATION': True,  # Invalidate old refresh tokens
    'UPDATE_LAST_LOGIN': True,  # Track last login time
    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_TOKEN_CLASSES': ('rest_framework_simplejwt.tokens.AccessToken',),
}

# ─── Custom Admin Settings ────────────────────────────────────
CUSTOM_ADMIN_SITE_TITLE = 'Burundi AU Chairmanship 2026'
CUSTOM_ADMIN_SITE_HEADER = 'Content Management System'

# ─── Security Headers (always active) ────────────────────────
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
CSRF_COOKIE_HTTPONLY = True

# ─── Production Security ──────────────────────────────────────
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    # Cloudflare sends the original host in X-Forwarded-Host
    USE_X_FORWARDED_HOST = True
    USE_X_FORWARDED_PORT = True
    # Django 4.2+ requires explicit trusted origins for HTTPS CSRF checks
    CSRF_TRUSTED_ORIGINS = [
        'https://api.burundi4africa.com',
        'https://burundi4africa.com',
        'https://www.burundi4africa.com',
        'https://burundi-au-api-mgo34.ondigitalocean.app',
    ]
# ─── Twilio SMS Configuration ─────────────────────────────────
# For OTP verification via SMS
# SECURITY: All Twilio credentials MUST be set via environment variables
TWILIO_ACCOUNT_SID = os.environ.get('TWILIO_ACCOUNT_SID', '')
TWILIO_AUTH_TOKEN = os.environ.get('TWILIO_AUTH_TOKEN', '')
TWILIO_VERIFY_SERVICE_SID = os.environ.get('TWILIO_VERIFY_SERVICE_SID', '')
TWILIO_PHONE_NUMBER = os.environ.get('TWILIO_PHONE_NUMBER', '')
TWILIO_SENDER_ID = os.environ.get('TWILIO_SENDER_ID', 'B4africa')

# ─── Email Configuration ──────────────────────────────────────
# For email OTP verification
# Uses SMTP in production (Google Workspace), console backend for local dev
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend'  # Fallback for local dev
)
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() in ('true', '1', 'yes')
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.environ.get(
    'DEFAULT_FROM_EMAIL',
    'Burundi AU Chairmanship <info@burundi4africa.com>'
)

# ─── Sentry Error Tracking ───────────────────────────────────
SENTRY_DSN = os.environ.get('SENTRY_DSN', '')
if SENTRY_DSN:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[DjangoIntegration()],
        traces_sample_rate=float(os.environ.get('SENTRY_TRACES_SAMPLE_RATE', '0.2')),
        profiles_sample_rate=float(os.environ.get('SENTRY_PROFILES_SAMPLE_RATE', '0.1')),
        send_default_pii=True,
        environment=os.environ.get('SENTRY_ENVIRONMENT', 'development' if DEBUG else 'production'),
        release=os.environ.get('SENTRY_RELEASE', 'burundi-au-backend@1.0.0'),
    )
