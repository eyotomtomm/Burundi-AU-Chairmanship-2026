import logging
import threading
import urllib.request
import json as json_module
from django.contrib.auth.models import User
from django.core.mail import send_mail
from datetime import timedelta
from django.conf import settings as django_settings
from django.db import models
from django.db.models import Count, Exists, OuterRef, F, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import viewsets, status, mixins
from rest_framework.decorators import api_view, permission_classes, action, throttle_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from config.firebase import verify_firebase_token
from .throttling import ViewCountThrottle, LikeToggleThrottle, AuthRateThrottle, OTPRateThrottle, SupportTicketThrottle, SearchRateThrottle

logger = logging.getLogger(__name__)
from .models import (
    HeroSlide, MagazineEdition, MagazineLike, Article, EmbassyLocation,
    Event, LiveFeed, Resource, AppSettings,
    FeatureCard, ArticleComment, ArticleLike, Category, UserProfile,
    PriorityAgenda, GalleryAlbum, GalleryAlbumLike, GalleryPhoto, Video, VideoLike, SocialMediaLink,
    Notification, HeroTextContent, QuickAccessMenuItem, VerificationRequest,
    WeatherCity, EventRegistration, RegistrationFormField, EventSubmission,
    SupportTicket, TicketMessage, Popup,
    # New models
    LoginHistory, ActiveSession, PasswordChangeHistory, Bookmark, Reaction,
    ReadingProgress, ArticleDraft, ArticleSeries, TrendingContent,
    EventReminder, EventWaitlist, EventSpeaker, EventFeedback, EventCheckIn, EventPhoto,
    Conversation, DirectMessage, Discussion, DiscussionReply,
    Poll, PollOption, PollVote, NotificationPreference, AnnouncementBanner,
    ContactDirectory, LiveQASession, LiveQAQuestion, UserPreference, OnboardingStep,
    ScheduledMaintenance, AppRelease, ContentAnalytics,
    AuditLogEntry, TranslationEntry, ContentVersion, AccountMergeRequest,
    WeeklyReport, UserSession, FunnelStep, EngagementHeatmap,
    VideoChapter, VideoSubtitle, ArticleRevision, TranslationRequest,
    EventComment, CommentMention, NewsletterEdition,
    EventAgendaItem, LinkedAccount,
    DeviceToken,
)
from .serializers import (
    HeroSlideSerializer, MagazineEditionSerializer, ArticleSerializer,
    EmbassyLocationSerializer, EventSerializer, LiveFeedSerializer,
    ResourceSerializer, AppSettingsSerializer,
    FeatureCardSerializer, RegisterSerializer, UserSerializer,
    ArticleCommentSerializer, CategorySerializer, PriorityAgendaSerializer,
    GalleryAlbumSerializer, VideoSerializer, SocialMediaLinkSerializer,
    NotificationSerializer, HeroTextContentSerializer, QuickAccessMenuItemSerializer,
    VerificationRequestSerializer, VerificationStatusSerializer,
    VerificationAppealSerializer, AdminVerificationActionSerializer,
    WeatherCitySerializer, EventRegistrationSerializer, EventSubmissionSerializer,
    RegistrationFormFieldSerializer, ProxyRegistrationSerializer,
    SupportTicketListSerializer, SupportTicketDetailSerializer, TicketMessageSerializer,
    PopupSerializer,
    # New serializers
    LoginHistorySerializer, ActiveSessionSerializer, PasswordChangeSerializer,
    BookmarkSerializer, ReactionSerializer, ReadingProgressSerializer,
    ArticleDraftSerializer, ArticleSeriesSerializer, TrendingContentSerializer,
    EventReminderSerializer, EventWaitlistSerializer, EventSpeakerSerializer,
    EventFeedbackSerializer, EventCheckInSerializer, EventPhotoSerializer,
    ConversationSerializer, DirectMessageSerializer, DiscussionSerializer,
    DiscussionReplySerializer, PollSerializer, PollOptionSerializer,
    NotificationPreferenceSerializer, AnnouncementBannerSerializer,
    ContactDirectorySerializer, LiveQASessionSerializer, LiveQAQuestionSerializer,
    UserPreferenceSerializer, OnboardingStepSerializer, ScheduledMaintenanceSerializer,
    AppReleaseSerializer, ContentAnalyticsSerializer, WeeklyReportSerializer,
    AuditLogEntrySerializer, TranslationEntrySerializer, ContentVersionSerializer,
    AccountMergeRequestSerializer, LinkedAccountSerializer,
    ArticleRevisionSerializer, TranslationRequestSerializer,
    EventCommentSerializer, NewsletterEditionSerializer, EventAttendeeSerializer,
    EventAgendaItemSerializer, VideoChapterSerializer,
)


def _split_display_name(display_name):
    """Split a social login display name into (first_name, last_name).
    Handles long names from Google/Apple by taking the first word as first_name
    and the rest as last_name. Both fields are capped at 150 chars (Django limit).
    """
    if not display_name or not display_name.strip():
        return ('', '')
    parts = display_name.strip().split(None, 1)  # Split on first whitespace
    first_name = parts[0][:150]
    last_name = parts[1][:150] if len(parts) > 1 else ''
    return (first_name, last_name)


def _generate_unique_username(email, firebase_uid, display_name=None):
    """Generate a readable username from display name or email, falling back to Firebase UID.
    Prefers name-based usernames (e.g. 'john.doe') over email-prefix usernames.
    Username is capped at 150 chars (Django limit).
    """
    import re as _re
    base = None
    # Prefer display name (e.g. "John Doe" → "john.doe")
    if display_name and display_name.strip():
        base = display_name.strip().lower().replace(' ', '.')
        base = _re.sub(r'[^\w.\-]', '', base)[:140]
    # Fallback to email prefix
    if not base and email:
        base = email.split('@')[0]
        base = _re.sub(r'[^\w.\-]', '', base)[:140]
    if not base:
        base = firebase_uid[:150]

    # Check if base username is available
    if not User.objects.filter(username=base).exists():
        return base

    # Append numeric suffix until unique
    for i in range(1, 1000):
        candidate = f'{base}{i}'[:150]
        if not User.objects.filter(username=candidate).exists():
            return candidate

    # Ultimate fallback
    return firebase_uid[:150]


def get_client_ip(request):
    """Extract real client IP from request headers."""
    # Cloudflare
    cf_ip = request.META.get('HTTP_CF_CONNECTING_IP')
    if cf_ip:
        return cf_ip
    # Standard proxy header
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', '')


def lookup_ip_geolocation(login_history_id):
    """Look up IP geolocation in background thread."""
    try:
        from core.models import LoginHistory as LH
        entry = LH.objects.get(id=login_history_id)
        if not entry.ip_address or entry.ip_address in ('127.0.0.1', '::1', ''):
            return
        url = f'http://ip-api.com/json/{entry.ip_address}?fields=status,country,city'
        req = urllib.request.Request(url, headers={'User-Agent': 'BurundiAU/1.0'})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json_module.loads(resp.read().decode())
        if data.get('status') == 'success':
            entry.country = data.get('country', '')
            entry.city = data.get('city', '')
            entry.save(update_fields=['country', 'city'])
    except Exception:
        pass  # Non-critical, don't break login flow


# ── reCAPTCHA Verification ────────────────────────────────

def verify_recaptcha(token):
    """
    Verify a reCAPTCHA token with Google's API.
    Returns True if verification succeeds or if RECAPTCHA_SECRET_KEY is not configured.
    Returns False if verification fails.
    """
    secret_key = getattr(django_settings, 'RECAPTCHA_SECRET_KEY', '')
    if not secret_key:
        return True

    try:
        import urllib.parse
        data = urllib.parse.urlencode({
            'secret': secret_key,
            'response': token,
        }).encode('utf-8')
        req = urllib.request.Request(
            'https://www.google.com/recaptcha/api/siteverify',
            data=data,
            method='POST',
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json_module.loads(resp.read().decode())
        return result.get('success', False)
    except Exception as e:
        logger.warning(f'reCAPTCHA verification failed: {e}')
        return True


# ── Auth Views ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def register(request):
    # Honeypot anti-bot check: if the hidden '_hp' field is filled, reject silently
    honeypot = request.data.get('_hp', '')
    if honeypot:
        # Bots typically fill hidden fields — return a fake success to avoid tipping them off
        return Response({
            'user': {},
            'access': '',
            'refresh': '',
            'email_verified': False,
            'requires_email_verification': True,
        }, status=status.HTTP_201_CREATED)

    # reCAPTCHA verification (optional — skipped if RECAPTCHA_SECRET_KEY is not set)
    captcha_token = request.data.get('captcha_token', '')
    if getattr(django_settings, 'RECAPTCHA_SECRET_KEY', ''):
        if not captcha_token:
            return Response(
                {'detail': 'CAPTCHA verification is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not verify_recaptcha(captcha_token):
            return Response(
                {'detail': 'CAPTCHA verification failed. Please try again.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        profile = user.profile
        return Response({
            'user': UserSerializer(user, context={'request': request}).data,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'email_verified': profile.is_email_verified,
            'requires_email_verification': not profile.is_email_verified,
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def login(request):
    email = request.data.get('email', '')
    password = request.data.get('password', '')
    ip = get_client_ip(request)
    ua = request.META.get('HTTP_USER_AGENT', '')

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        # Record failed login - user not found
        lh = LoginHistory.objects.create(
            user=None,
            email=email,
            method='email',
            ip_address=ip,
            user_agent=ua,
            success=False,
            failure_reason='User not found',
        )
        threading.Thread(target=lookup_ip_geolocation, args=(lh.id,), daemon=True).start()
        return Response(
            {'detail': 'Invalid email or password.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.check_password(password):
        # Record failed login - wrong password
        lh = LoginHistory.objects.create(
            user=user,
            email=email,
            method='email',
            ip_address=ip,
            user_agent=ua,
            success=False,
            failure_reason='Invalid password',
        )
        threading.Thread(target=lookup_ip_geolocation, args=(lh.id,), daemon=True).start()
        return Response(
            {'detail': 'Invalid email or password.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    # Handle deactivated / deletion-scheduled accounts
    profile = user.profile
    if not user.is_active and (profile.is_deactivated or profile.is_scheduled_for_deletion):
        # Check if past 30-day window
        if (profile.is_scheduled_for_deletion and
                profile.deletion_scheduled_for and
                timezone.now() > profile.deletion_scheduled_for):
            return Response(
                {'detail': 'This account has been permanently deleted and cannot be recovered.'},
                status=status.HTTP_410_GONE,
            )

        # Auto-reactivate on login
        was_scheduled = profile.is_scheduled_for_deletion
        profile.is_deactivated = False
        profile.deactivated_at = None
        profile.is_scheduled_for_deletion = False
        profile.deletion_requested_at = None
        profile.deletion_scheduled_for = None
        profile.save()

        user.is_active = True
        user.save()

        refresh = RefreshToken.for_user(user)
        message = 'Welcome back! Your account has been reactivated.'
        if was_scheduled:
            message = 'Welcome back! Your account deletion has been cancelled and your account is fully restored.'

        # Record successful login (reactivation)
        lh = LoginHistory.objects.create(
            user=user,
            email=email,
            method='email',
            ip_address=ip,
            user_agent=ua,
            success=True,
        )
        threading.Thread(target=lookup_ip_geolocation, args=(lh.id,), daemon=True).start()

        return Response({
            'user': UserSerializer(user, context={'request': request}).data,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'message': message,
            'reactivated': True,
            'was_scheduled_for_deletion': was_scheduled,
        })

    refresh = RefreshToken.for_user(user)
    profile = user.profile

    # Record successful login
    lh = LoginHistory.objects.create(
        user=user,
        email=email,
        method='email',
        ip_address=ip,
        user_agent=ua,
        success=True,
    )
    threading.Thread(target=lookup_ip_geolocation, args=(lh.id,), daemon=True).start()

    return Response({
        'user': UserSerializer(user, context={'request': request}).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'email_verified': profile.is_email_verified,
        'requires_email_verification': not profile.is_email_verified,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    return Response(UserSerializer(request.user, context={'request': request}).data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    serializer = UserSerializer(request.user, data=request.data, partial=True, context={'request': request})
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def deactivate_account(request):
    """
    Deactivate account ("Take a Break").
    Account becomes inactive until the user logs in again.
    """
    user = request.user
    profile = user.profile

    profile.is_deactivated = True
    profile.deactivated_at = timezone.now()
    profile.save()

    # Mark Django user as inactive so they can't access protected endpoints
    user.is_active = False
    user.save()

    # Send confirmation email
    try:
        send_mail(
            subject='Burundi4Africa - Account Deactivated',
            message=(
                f'Hello {user.first_name or user.username},\n\n'
                'Your Burundi AU Chairmanship 2026 account has been deactivated.\n\n'
                'Your data is safe and your account is just paused. '
                'You can reactivate it anytime by simply logging back in.\n\n'
                'If you did not request this, please contact us immediately.\n\n'
                'Best regards,\nBurundi4Africa Team'
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=True,
        )
    except Exception:
        logger.warning('Failed to send deactivation email to %s', user.email)

    return Response({
        'message': 'Your account has been deactivated.',
        'detail': 'You can reactivate it anytime by logging in again.',
    }, status=status.HTTP_200_OK)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    """
    Soft-delete: schedule account for permanent deletion in 30 days.
    User can cancel by logging back in within 30 days.
    Required for Apple App Store compliance (Guideline 5.1.1)
    """
    user = request.user
    profile = user.profile

    now = timezone.now()
    profile.is_scheduled_for_deletion = True
    profile.deletion_requested_at = now
    profile.deletion_scheduled_for = now + timezone.timedelta(days=30)
    profile.is_deactivated = True
    profile.deactivated_at = now
    profile.save()

    # Mark user as inactive
    user.is_active = False
    user.save()

    # Send confirmation email
    deletion_date = profile.deletion_scheduled_for.strftime('%B %d, %Y')
    try:
        send_mail(
            subject='Burundi4Africa - Account Deletion Scheduled',
            message=(
                f'Hello {user.first_name or user.username},\n\n'
                'Your Burundi AU Chairmanship 2026 account has been scheduled for permanent deletion.\n\n'
                f'Your data will be permanently removed on {deletion_date}.\n\n'
                'Changed your mind? Simply log back in before that date to cancel '
                'the deletion and reactivate your account.\n\n'
                'If you did not request this, please contact us immediately.\n\n'
                'Best regards,\nBurundi4Africa Team'
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=True,
        )
    except Exception:
        logger.warning('Failed to send deletion email to %s', user.email)

    return Response({
        'message': 'Your account has been scheduled for deletion.',
        'detail': 'Your data will be permanently deleted after 30 days. '
                  'Log in again within 30 days to cancel deletion and reactivate your account.',
        'deletion_scheduled_for': profile.deletion_scheduled_for.isoformat(),
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def reactivate_account(request):
    """
    Reactivate a deactivated or deletion-scheduled account.
    Called during login when user is inactive.
    """
    email = request.data.get('email', '')
    password = request.data.get('password', '')

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response(
            {'detail': 'Invalid email or password.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.check_password(password):
        return Response(
            {'detail': 'Invalid email or password.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    profile = user.profile

    # Check if account is past the 30-day deletion window
    if (profile.is_scheduled_for_deletion and
            profile.deletion_scheduled_for and
            timezone.now() > profile.deletion_scheduled_for):
        return Response(
            {'detail': 'This account has been permanently deleted and cannot be recovered.'},
            status=status.HTTP_410_GONE,
        )

    # Reactivate the account
    was_scheduled = profile.is_scheduled_for_deletion
    profile.is_deactivated = False
    profile.deactivated_at = None
    profile.is_scheduled_for_deletion = False
    profile.deletion_requested_at = None
    profile.deletion_scheduled_for = None
    profile.save()

    user.is_active = True
    user.save()

    refresh = RefreshToken.for_user(user)

    message = 'Welcome back! Your account has been reactivated.'
    if was_scheduled:
        message = 'Welcome back! Your account deletion has been cancelled and your account is fully restored.'

    return Response({
        'user': UserSerializer(user, context={'request': request}).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'message': message,
        'was_scheduled_for_deletion': was_scheduled,
    })


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def firebase_register(request):
    """
    Register a new user after Firebase Auth signup.
    Creates Django User and UserProfile with Firebase UID.
    """
    # Honeypot anti-bot check
    honeypot = request.data.get('_hp', '')
    if honeypot:
        return Response({
            'user': {},
            'message': 'User registered successfully',
            'email_verified': False,
            'requires_email_verification': True,
        }, status=status.HTTP_201_CREATED)

    id_token = request.data.get('firebase_token')
    name = request.data.get('name', '')
    phone_number = request.data.get('phone_number', '')
    gender = request.data.get('gender', '')

    if not id_token:
        return Response(
            {'detail': 'Firebase token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        firebase_uid = decoded_token['uid']
        email = decoded_token.get('email', '')

        # Check if user already exists by Firebase UID or email
        existing_user = None
        try:
            profile = UserProfile.objects.select_related('user').get(firebase_uid=firebase_uid)
            existing_user = profile.user
        except UserProfile.DoesNotExist:
            # Also check by email — link existing email accounts to Firebase
            if email:
                try:
                    existing_user = User.objects.get(email=email)
                except User.DoesNotExist:
                    pass

        if existing_user:
            # Update name if provided (split into first/last for long social names)
            if name and not existing_user.first_name:
                first_name, last_name = _split_display_name(name)
                existing_user.first_name = first_name
                existing_user.last_name = last_name
            # Fix username if it's still a Firebase UID (random string)
            if existing_user.username == firebase_uid or (
                    len(existing_user.username) > 20 and not existing_user.email):
                if email or name:
                    new_username = _generate_unique_username(email, firebase_uid, display_name=name)
                    existing_user.username = new_username
            # Update email if missing
            if email and not existing_user.email:
                existing_user.email = email
            existing_user.save()
            profile = existing_user.profile
            profile.firebase_uid = firebase_uid
            profile.is_email_verified = decoded_token.get('email_verified', False)
            if phone_number and not profile.phone_number:
                profile.phone_number = phone_number
            if gender and not profile.gender:
                profile.gender = gender
            profile.save()
            return Response({
                'user': UserSerializer(existing_user, context={'request': request}).data,
                'message': 'User registered successfully',
                'email_verified': profile.is_email_verified,
                'requires_email_verification': not profile.is_email_verified,
            }, status=status.HTTP_200_OK)

        # Split display name into first/last (handles long Google/Apple names)
        first_name, last_name = _split_display_name(name)

        # Create Django user with readable username derived from name or email
        username = _generate_unique_username(email, firebase_uid, display_name=name)
        user = User.objects.create(
            username=username,
            email=email,
            first_name=first_name,
            last_name=last_name,
        )

        # Update profile with Firebase data
        profile = user.profile
        profile.firebase_uid = firebase_uid
        profile.phone_number = phone_number
        profile.gender = gender
        profile.is_email_verified = decoded_token.get('email_verified', False)
        profile.save()

        return Response({
            'user': UserSerializer(user, context={'request': request}).data,
            'message': 'User registered successfully',
            'email_verified': profile.is_email_verified,
            'requires_email_verification': not profile.is_email_verified,
        }, status=status.HTTP_201_CREATED)

    except ValueError as e:
        return Response(
            {'detail': str(e)},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except Exception as e:
        logger.exception('Firebase registration failed')
        return Response(
            {'detail': 'Registration failed. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def firebase_login(request):
    """
    Login with Firebase ID token.
    Verifies token and returns user profile data.
    """
    id_token = request.data.get('firebase_token')

    if not id_token:
        return Response(
            {'detail': 'Firebase token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        firebase_uid = decoded_token['uid']
        email = decoded_token.get('email', '')
        name = decoded_token.get('name', email.split('@')[0] if email else 'User')

        # Find or create user by Firebase UID, then by email
        is_new_user = False
        try:
            profile = UserProfile.objects.select_related('user').get(firebase_uid=firebase_uid)
            user = profile.user
        except UserProfile.DoesNotExist:
            # Try to find existing user by email before creating a new one
            user = None
            if email:
                try:
                    user = User.objects.get(email=email)
                    profile = user.profile
                    profile.firebase_uid = firebase_uid
                except User.DoesNotExist:
                    pass

            if user is None:
                # Auto-create user if they don't exist (standard for social logins)
                first_name, last_name = _split_display_name(name)
                username = _generate_unique_username(email, firebase_uid, display_name=name)
                user = User.objects.create(
                    username=username,
                    email=email,
                    first_name=first_name,
                    last_name=last_name,
                )
                profile = user.profile
                profile.firebase_uid = firebase_uid
                is_new_user = True

        # Update email and username for existing users if needed
        if not is_new_user:
            user_changed = False
            # Update email if the user doesn't have one yet
            if email and not user.email:
                user.email = email
                user_changed = True
            # Fix username if it's still a Firebase UID (random string)
            if user.username == firebase_uid:
                if email or name:
                    new_username = _generate_unique_username(email, firebase_uid, display_name=name)
                    if new_username != firebase_uid:
                        user.username = new_username
                        user_changed = True
            # Update name if missing
            if name and not user.first_name:
                first_name, last_name = _split_display_name(name)
                user.first_name = first_name
                user.last_name = last_name
                user_changed = True
            if user_changed:
                user.save()

        # Handle deactivated / deletion-scheduled accounts
        if not is_new_user and not user.is_active and (profile.is_deactivated or profile.is_scheduled_for_deletion):
            if (profile.is_scheduled_for_deletion and
                    profile.deletion_scheduled_for and
                    timezone.now() > profile.deletion_scheduled_for):
                return Response(
                    {'detail': 'This account has been permanently deleted and cannot be recovered.'},
                    status=status.HTTP_410_GONE,
                )
            # Auto-reactivate
            was_scheduled = profile.is_scheduled_for_deletion
            profile.is_deactivated = False
            profile.deactivated_at = None
            profile.is_scheduled_for_deletion = False
            profile.deletion_requested_at = None
            profile.deletion_scheduled_for = None
            user.is_active = True
            user.save()

        # Update email verification status from Firebase
        profile.is_email_verified = decoded_token.get('email_verified', False)
        profile.save()

        return Response({
            'user': UserSerializer(user, context={'request': request}).data,
            'message': 'Login successful',
            'is_new_user': is_new_user,
            'email_verified': profile.is_email_verified,
            'requires_email_verification': not profile.is_email_verified,
        })

    except ValueError as e:
        return Response(
            {'detail': str(e)},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except Exception as e:
        logger.exception('Firebase login failed')
        return Response(
            {'detail': 'Login failed. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def register_fcm_token(request):
    """
    Register an FCM token for push notifications (no auth required).
    If user is authenticated, links the token to the user.
    If user is not authenticated, stores the token with user=None (anonymous).
    This ensures anonymous users can still receive global push notifications.
    """
    fcm_token = request.data.get('fcm_token')

    if not fcm_token:
        return Response(
            {'detail': 'FCM token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        user = request.user if request.user.is_authenticated else None

        defaults = {
            'is_active': True,
            'device_type': request.data.get('device_type', ''),
            'device_os': request.data.get('device_os', ''),
        }

        if user:
            defaults['user'] = user

        DeviceToken.objects.update_or_create(
            token=fcm_token,
            defaults=defaults,
        )

        return Response({
            'message': 'FCM token registered successfully'
        })

    except Exception as e:
        logger.exception('Failed to register FCM token')
        return Response(
            {'detail': 'Failed to register notification token. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    """
    Update user's FCM token for push notifications.
    Creates/reactivates a DeviceToken entry and also updates the legacy
    UserProfile.fcm_token for backward compatibility.
    Also links any existing anonymous token to the authenticated user.
    """
    fcm_token = request.data.get('fcm_token')

    if not fcm_token:
        return Response(
            {'detail': 'FCM token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        # Update legacy profile token for backward compatibility
        profile = request.user.profile
        profile.fcm_token = fcm_token
        profile.save(update_fields=['fcm_token'])

        # Link existing token (possibly anonymous) to the current user,
        # or create a new one. Since token is unique, use update_or_create
        # with token as the lookup field.
        DeviceToken.objects.update_or_create(
            token=fcm_token,
            defaults={
                'user': request.user,
                'is_active': True,
                'device_type': profile.device_type,
                'device_os': profile.device_os,
            }
        )

        return Response({
            'message': 'FCM token updated successfully'
        })

    except Exception as e:
        logger.exception('Failed to update FCM token')
        return Response(
            {'detail': 'Failed to update notification settings. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def deactivate_fcm_token(request):
    """
    Deactivate user's FCM token on logout.
    Does not delete the token so it can be reactivated on next login.
    """
    fcm_token = request.data.get('fcm_token')

    try:
        if fcm_token:
            DeviceToken.objects.filter(
                user=request.user,
                token=fcm_token,
            ).update(is_active=False)
        else:
            DeviceToken.objects.filter(user=request.user).update(is_active=False)

        # Clear legacy token
        profile = request.user.profile
        profile.fcm_token = ''
        profile.save(update_fields=['fcm_token'])

        return Response({'message': 'FCM token deactivated'})
    except Exception as e:
        logger.exception('Failed to deactivate FCM token')
        return Response(
            {'detail': 'Failed to deactivate token.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_language_preference(request):
    """Update user's preferred language for push notifications."""
    language = request.data.get('preferred_language', 'en')
    if language not in ('en', 'fr'):
        return Response({'error': 'Invalid language'}, status=status.HTTP_400_BAD_REQUEST)
    request.user.profile.preferred_language = language
    request.user.profile.save(update_fields=['preferred_language'])
    return Response({'preferred_language': language})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_device_info(request):
    """
    Update device info and last active timestamp.
    Called from Flutter on app startup.
    """
    profile = request.user.profile
    profile.device_type = request.data.get('device_type', '')[:50]
    profile.device_os = request.data.get('device_os', '')[:50]
    profile.app_version = request.data.get('app_version', '')[:20]
    profile.last_active = timezone.now()
    profile.save(update_fields=['device_type', 'device_os', 'app_version', 'last_active'])
    return Response({'message': 'Device info updated'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def export_user_data(request):
    """
    Export all user data in JSON format.
    Required for GDPR/data portability compliance.
    """
    user = request.user

    # Compile all user data
    user_data = {
        'account_information': {
            'user_id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'date_joined': user.date_joined.isoformat(),
            'last_login': user.last_login.isoformat() if user.last_login else None,
        },
        'profile_information': {
            'is_active': user.is_active,
            'is_staff': user.is_staff,
        },
        'data_export_info': {
            'export_date': timezone.now().isoformat(),
            'format': 'JSON',
            'version': '1.0',
        },
        'notes': {
            'content_data': 'This export includes your account information. Content you viewed (articles, magazines, etc.) is not tracked or stored.',
            'deletion': 'To delete your account and all data, use the Delete Account feature in the app.',
            'questions': 'Contact support@burundi.gov.bi for questions about your data.',
        }
    }

    return Response(user_data, status=status.HTTP_200_OK)


# ── Content ViewSets ──────────────────────────────────────

class HeroSlideViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view hero slides"""
    permission_classes = [AllowAny]
    queryset = HeroSlide.objects.filter(is_active=True)
    serializer_class = HeroSlideSerializer
    pagination_class = None


class MagazineEditionViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view magazines, but authentication required to like"""
    permission_classes = [AllowAny]
    queryset = MagazineEdition.objects.all()
    serializer_class = MagazineEditionSerializer

    def get_queryset(self):
        qs = MagazineEdition.objects.prefetch_related('images').filter(
            status='published',  # Only show published magazines in public API
        )
        user = self.request.user
        if user.is_authenticated:
            qs = qs.annotate(
                is_liked=Exists(MagazineLike.objects.filter(user=user, edition=OuterRef('pk')))
            )
        return qs

    @action(detail=True, methods=['post'], permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle], url_path='record-view')
    def record_view(self, request, pk=None):
        """
        Record a view for this magazine edition.

        Throttled to 1 view per content per minute per user/IP
        to prevent view count manipulation.
        """
        edition = self.get_object()
        MagazineEdition.objects.filter(pk=edition.pk).update(view_count=F('view_count') + 1)
        edition.refresh_from_db()
        return Response({'view_count': edition.view_count})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated], throttle_classes=[LikeToggleThrottle], url_path='toggle-like')
    def toggle_like(self, request, pk=None):
        """
        Toggle like on magazine. Requires authentication.

        Throttled to 10 toggles per minute to prevent spam.
        """
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required to like content'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        edition = self.get_object()
        like, created = MagazineLike.objects.get_or_create(
            user=request.user, edition=edition,
        )
        if not created:
            # Unlike: delete the like record
            like.delete()
            MagazineEdition.objects.filter(pk=edition.pk).update(like_count=F('like_count') - 1)
            is_liked = False
        else:
            # Like: increment count
            MagazineEdition.objects.filter(pk=edition.pk).update(like_count=F('like_count') + 1)
            is_liked = True

        edition.refresh_from_db()
        return Response({'like_count': edition.like_count, 'is_liked': is_liked})


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view categories"""
    permission_classes = [AllowAny]
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    pagination_class = None


class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can read articles, but authentication required to like/comment"""
    permission_classes = [AllowAny]
    serializer_class = ArticleSerializer
    filterset_fields = ['category', 'is_featured']

    def get_queryset(self):
        now = timezone.now()
        qs = Article.objects.select_related('category').prefetch_related('media').annotate(
            comment_count=Count('comments', distinct=True),
        ).filter(
            is_draft=False,  # Exclude legacy drafts from public API
            status='published',  # Only show published articles
        ).exclude(
            scheduled_publish_at__gt=now,  # Exclude scheduled (future) articles
        ).exclude(
            expires_at__lt=now,  # Exclude expired articles
        ).order_by('-publish_date')  # Explicitly order by newest first
        user = self.request.user
        if user.is_authenticated:
            qs = qs.annotate(
                is_liked=Exists(
                    ArticleLike.objects.filter(article=OuterRef('pk'), user=user)
                ),
            )
        else:
            from django.db.models import Value, BooleanField
            qs = qs.annotate(is_liked=Value(False, output_field=BooleanField()))
        return qs

    def retrieve(self, request, *args, **kwargs):
        """Override retrieve to increment view_count on each article view using F() for thread safety."""
        instance = self.get_object()
        Article.objects.filter(pk=instance.pk).update(view_count=F('view_count') + 1)
        instance.refresh_from_db()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=True, methods=['get'], url_path='related', permission_classes=[AllowAny])
    def related(self, request, pk=None):
        """Get related articles in the same category, excluding the current article."""
        article = self.get_object()
        now = timezone.now()
        related_qs = Article.objects.select_related('category').prefetch_related('media').filter(
            is_draft=False,
            status='published',
        ).exclude(
            scheduled_publish_at__gt=now,
        ).exclude(
            expires_at__lt=now,
        ).exclude(pk=article.pk)

        if article.category_id:
            related_qs = related_qs.filter(category=article.category)

        related_qs = related_qs.annotate(
            comment_count=Count('comments', distinct=True),
        ).order_by('-publish_date')[:5]

        if request.user.is_authenticated:
            related_qs = related_qs.annotate(
                is_liked=Exists(ArticleLike.objects.filter(article=OuterRef('pk'), user=request.user)),
            )
        else:
            from django.db.models import Value, BooleanField
            related_qs = related_qs.annotate(is_liked=Value(False, output_field=BooleanField()))

        serializer = ArticleSerializer(related_qs, many=True, context={'request': request})
        return Response(serializer.data)

    @action(detail=True, methods=['get', 'post'], url_path='reading-progress', permission_classes=[IsAuthenticated])
    def reading_progress(self, request, pk=None):
        """Get or save reading progress for an article."""
        article = self.get_object()
        if request.method == 'GET':
            try:
                progress = ReadingProgress.objects.get(user=request.user, article=article)
                return Response(ReadingProgressSerializer(progress).data)
            except ReadingProgress.DoesNotExist:
                return Response({'scroll_position': 0, 'progress_percent': 0, 'completed': False})

        # POST
        scroll_pos = request.data.get('scroll_position', 0)
        progress_pct = request.data.get('progress_percent', 0)
        obj, created = ReadingProgress.objects.update_or_create(
            user=request.user, article=article,
            defaults={
                'progress_percent': min(100, max(0, int(progress_pct))),
                'scroll_position': int(scroll_pos),
                'completed': int(progress_pct) >= 90,
            }
        )
        return Response(ReadingProgressSerializer(obj).data)

    @action(detail=True, methods=['post'], url_path='record-view', permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle])
    def record_view(self, request, pk=None):
        """
        Record a view for this article.

        Throttled to 1 view per content per minute per user/IP
        to prevent view count manipulation.
        """
        Article.objects.filter(pk=pk).update(view_count=F('view_count') + 1)
        article = self.get_object()
        return Response({'view_count': article.view_count})

    @action(detail=True, methods=['get', 'post'], url_path='comments', throttle_classes=[LikeToggleThrottle])
    def comments(self, request, pk=None):
        """
        Get or post comments on an article.

        POST is throttled to prevent spam (10/min).
        """
        article = self.get_object()
        if request.method == 'GET':
            comments = article.comments.select_related('user', 'user__profile').all()
            serializer = ArticleCommentSerializer(comments, many=True, context={'request': request})
            return Response(serializer.data)
        # POST — require auth
        if not request.user.is_authenticated:
            return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

        content = request.data.get('content', '').strip()

        # Input validation
        if not content:
            return Response({'detail': 'Content is required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Length validation (prevent spam)
        if len(content) > 5000:
            return Response({'detail': 'Comment too long (max 5000 characters).'}, status=status.HTTP_400_BAD_REQUEST)

        if len(content) < 2:
            return Response({'detail': 'Comment too short (min 2 characters).'}, status=status.HTTP_400_BAD_REQUEST)

        # HTML sanitization: escape all HTML entities (treat as plain text)
        from django.utils.html import escape
        content = escape(content)

        comment = ArticleComment.objects.create(user=request.user, article=article, content=content)
        serializer = ArticleCommentSerializer(comment, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['delete'], url_path='comments/(?P<comment_id>[0-9]+)')
    def delete_comment(self, request, pk=None, comment_id=None):
        if not request.user.is_authenticated:
            return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            comment = ArticleComment.objects.get(pk=comment_id, article_id=pk)
        except ArticleComment.DoesNotExist:
            return Response({'detail': 'Comment not found.'}, status=status.HTTP_404_NOT_FOUND)
        if comment.user != request.user:
            return Response({'detail': 'You can only delete your own comments.'}, status=status.HTTP_403_FORBIDDEN)
        comment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'], url_path='toggle-like', permission_classes=[IsAuthenticated], throttle_classes=[LikeToggleThrottle])
    def toggle_like(self, request, pk=None):
        """
        Toggle like on article. Requires authentication.

        Throttled to 10 toggles per minute to prevent spam.
        """
        article = self.get_object()
        like, created = ArticleLike.objects.get_or_create(user=request.user, article=article)
        if not created:
            like.delete()
            Article.objects.filter(pk=article.pk).update(like_count=F('like_count') - 1)
            is_liked = False
        else:
            Article.objects.filter(pk=article.pk).update(like_count=F('like_count') + 1)
            is_liked = True
        article.refresh_from_db()
        return Response({
            'is_liked': is_liked,
            'like_count': article.like_count,
        })


class EventViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view active, published events, with recurring event expansion."""
    permission_classes = [AllowAny]
    queryset = Event.objects.filter(is_active=True, status='published').prefetch_related('speakers')
    serializer_class = EventSerializer

    def list(self, request, *args, **kwargs):
        """Override list to expand recurring events into individual instances."""
        from dateutil.relativedelta import relativedelta
        from copy import copy

        response = super().list(request, *args, **kwargs)
        events_data = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data

        expanded = []
        for event_data in events_data:
            expanded.append(event_data)
            recurrence = event_data.get('recurrence_type', 'none')
            end_date_str = event_data.get('recurrence_end_date')

            if recurrence == 'none' or not end_date_str:
                continue

            try:
                from datetime import datetime
                import copy as copy_module
                event_date = datetime.fromisoformat(event_data['event_date'].replace('Z', '+00:00'))
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d').replace(
                    tzinfo=event_date.tzinfo
                )

                current_date = event_date
                max_instances = 52  # Safety limit

                for _ in range(max_instances):
                    if recurrence == 'daily':
                        current_date = current_date + timedelta(days=1)
                    elif recurrence == 'weekly':
                        current_date = current_date + timedelta(weeks=1)
                    elif recurrence == 'monthly':
                        current_date = current_date + relativedelta(months=1)
                    else:
                        break

                    if current_date.date() > end_date.date():
                        break

                    recurring_event = copy_module.deepcopy(event_data)
                    recurring_event['event_date'] = current_date.isoformat()
                    recurring_event['id'] = f"{event_data['id']}_r{_+1}"
                    expanded.append(recurring_event)
            except (ValueError, KeyError):
                continue

        if isinstance(response.data, dict) and 'results' in response.data:
            response.data['results'] = expanded
        else:
            response.data = expanded

        return response

    @action(detail=True, methods=['get'], url_path='ics', permission_classes=[AllowAny])
    def download_ics(self, request, pk=None):
        """Generate and download an ICS calendar file for the event."""
        from django.http import HttpResponse
        event = self.get_object()

        dtstart = event.event_date.strftime('%Y%m%dT%H%M%SZ')
        # Default to 1 hour if no end time
        dtend = (event.event_date + timedelta(hours=1)).strftime('%Y%m%dT%H%M%SZ')
        uid = f"event-{event.id}@burundi4africa.com"
        dtstamp = timezone.now().strftime('%Y%m%dT%H%M%SZ')

        ics_content = (
            "BEGIN:VCALENDAR\r\n"
            "VERSION:2.0\r\n"
            "PRODID:-//Burundi AU Chairmanship//Events//EN\r\n"
            "CALSCALE:GREGORIAN\r\n"
            "METHOD:PUBLISH\r\n"
            "BEGIN:VEVENT\r\n"
            f"UID:{uid}\r\n"
            f"DTSTART:{dtstart}\r\n"
            f"DTEND:{dtend}\r\n"
            f"DTSTAMP:{dtstamp}\r\n"
            f"SUMMARY:{event.name}\r\n"
            f"DESCRIPTION:{event.description[:500]}\r\n"
            f"LOCATION:{event.address}\r\n"
            "STATUS:CONFIRMED\r\n"
            "END:VEVENT\r\n"
            "END:VCALENDAR\r\n"
        )

        response = HttpResponse(ics_content, content_type='text/calendar; charset=utf-8')
        response['Content-Disposition'] = f'attachment; filename="event-{event.id}.ics"'
        return response


class LiveFeedViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view live feeds"""
    permission_classes = [AllowAny]
    queryset = LiveFeed.objects.filter(content_status='published').order_by('-created_at')
    serializer_class = LiveFeedSerializer
    filterset_fields = ['status']


class ResourceViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view published resources"""
    permission_classes = [AllowAny]
    queryset = Resource.objects.filter(status='published')
    serializer_class = ResourceSerializer
    filterset_fields = ['category', 'file_type']


class FeatureCardViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view feature cards"""
    permission_classes = [AllowAny]
    queryset = FeatureCard.objects.filter(is_active=True).prefetch_related(
        'key_point_items', 'impact_area_items', 'media',
    )
    serializer_class = FeatureCardSerializer
    pagination_class = None


class PriorityAgendaViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view priority agendas"""
    permission_classes = [AllowAny]
    queryset = PriorityAgenda.objects.filter(is_active=True).order_by('display_order')
    serializer_class = PriorityAgendaSerializer
    pagination_class = None


class GalleryAlbumViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view gallery albums, authentication required to like"""
    queryset = GalleryAlbum.objects.all()
    permission_classes = [AllowAny]
    serializer_class = GalleryAlbumSerializer

    def get_queryset(self):
        qs = GalleryAlbum.objects.prefetch_related('photos').filter(status='published')
        user = self.request.user
        if user.is_authenticated:
            qs = qs.annotate(
                is_liked=Exists(GalleryAlbumLike.objects.filter(user=user, album=OuterRef('pk')))
            )
        else:
            from django.db.models import Value, BooleanField
            qs = qs.annotate(is_liked=Value(False, output_field=BooleanField()))
        return qs

    @action(detail=True, methods=['post'], url_path='record-view', permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle])
    def record_view(self, request, pk=None):
        """Record a view for this gallery album. Throttled to prevent manipulation."""
        GalleryAlbum.objects.filter(pk=pk).update(view_count=F('view_count') + 1)
        album = self.get_object()
        return Response({'view_count': album.view_count})

    @action(detail=True, methods=['post'], url_path='toggle-like', permission_classes=[IsAuthenticated], throttle_classes=[LikeToggleThrottle])
    def toggle_like(self, request, pk=None):
        """Toggle like on gallery album. Requires authentication."""
        album = self.get_object()
        like, created = GalleryAlbumLike.objects.get_or_create(user=request.user, album=album)
        if not created:
            like.delete()
            GalleryAlbum.objects.filter(pk=album.pk).update(like_count=F('like_count') - 1)
            is_liked = False
        else:
            GalleryAlbum.objects.filter(pk=album.pk).update(like_count=F('like_count') + 1)
            is_liked = True
        album.refresh_from_db()
        return Response({'like_count': album.like_count, 'is_liked': is_liked})


class VideoViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view videos, authentication required to like"""
    permission_classes = [AllowAny]
    serializer_class = VideoSerializer
    filterset_fields = ['category', 'is_featured']

    def get_queryset(self):
        qs = Video.objects.prefetch_related(
            'chapters', 'subtitles'
        ).filter(status='published').order_by('-is_featured', '-publish_date')
        user = self.request.user
        if user.is_authenticated:
            qs = qs.annotate(
                is_liked=Exists(VideoLike.objects.filter(user=user, video=OuterRef('pk')))
            )
        else:
            from django.db.models import Value, BooleanField
            qs = qs.annotate(is_liked=Value(False, output_field=BooleanField()))
        return qs

    @action(detail=True, methods=['post'], url_path='record-view', permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle])
    def record_view(self, request, pk=None):
        """Record a view for this video. Throttled to prevent manipulation."""
        Video.objects.filter(pk=pk).update(view_count=F('view_count') + 1)
        video = self.get_object()
        return Response({'view_count': video.view_count})

    @action(detail=True, methods=['post'], url_path='toggle-like', permission_classes=[IsAuthenticated], throttle_classes=[LikeToggleThrottle])
    def toggle_like(self, request, pk=None):
        """Toggle like on video. Requires authentication."""
        video = self.get_object()
        like, created = VideoLike.objects.get_or_create(user=request.user, video=video)
        if not created:
            like.delete()
            Video.objects.filter(pk=video.pk).update(like_count=F('like_count') - 1)
            is_liked = False
        else:
            Video.objects.filter(pk=video.pk).update(like_count=F('like_count') + 1)
            is_liked = True
        video.refresh_from_db()
        return Response({'like_count': video.like_count, 'is_liked': is_liked})

    @action(detail=True, methods=['get'], url_path='chapters', permission_classes=[AllowAny])
    def chapters(self, request, pk=None):
        """Return all chapters for a specific video, ordered by timestamp."""
        video = self.get_object()
        chapters = video.chapters.all()
        serializer = VideoChapterSerializer(chapters, many=True, context={'request': request})
        return Response(serializer.data)


class SocialMediaLinkViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view social media links"""
    permission_classes = [AllowAny]
    queryset = SocialMediaLink.objects.filter(is_active=True)
    serializer_class = SocialMediaLinkSerializer
    pagination_class = None


class WeatherCityViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view weather cities"""
    permission_classes = [AllowAny]
    queryset = WeatherCity.objects.filter(is_active=True)
    serializer_class = WeatherCitySerializer
    pagination_class = None


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Read-only notifications endpoint.
    - Shows active notifications only
    - For authenticated users: shows global + targeted notifications
    - For anonymous users: shows only global notifications
    - Custom actions: mark_as_read, mark_all_as_read
    """
    permission_classes = [AllowAny]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        """Filter notifications based on user authentication"""
        qs = Notification.objects.filter(is_active=True)

        if self.request.user.is_authenticated:
            # Show global notifications + user-targeted notifications
            from django.db.models import Q
            qs = qs.filter(
                Q(is_global=True) | Q(target_users=self.request.user)
            ).distinct().prefetch_related('read_by')
        else:
            # Show only global notifications for anonymous users
            qs = qs.filter(is_global=True)

        return qs

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated], url_path='mark-as-read')
    def mark_as_read(self, request, pk=None):
        """
        Mark a single notification as read for the current user.
        Requires authentication.
        """
        notification = self.get_object()
        notification.read_by.add(request.user)

        return Response({
            'message': 'Notification marked as read',
            'is_read': True
        })

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated], url_path='mark-all-as-read')
    def mark_all_as_read(self, request):
        """
        Mark all notifications as read for the current user.
        Requires authentication.
        """
        # Get all active notifications for the user
        notifications = self.get_queryset()

        # Add user to read_by for each notification
        count = 0
        for notification in notifications:
            if not notification.read_by.filter(id=request.user.id).exists():
                notification.read_by.add(request.user)
                count += 1

        return Response({
            'message': f'{count} notification(s) marked as read',
            'marked_count': count
        })

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated], url_path='unread-count')
    def unread_count(self, request):
        """Return count of unread notifications for the current user."""
        notifications = self.get_queryset()
        count = notifications.exclude(read_by=request.user).count()
        return Response({'unread_count': count})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated], url_path='opened')
    def opened(self, request, pk=None):
        """
        Track that a user opened/tapped a push notification.
        Increments the opened_count on the Notification.
        Called from Flutter when a push notification is tapped.
        """
        notification = self.get_object()
        Notification.objects.filter(pk=notification.pk).update(
            opened_count=models.F('opened_count') + 1
        )
        return Response({
            'message': 'Notification open tracked',
            'notification_id': notification.pk,
        })


@api_view(['POST'])
@permission_classes([IsAdminUser])
def notification_target_count(request):
    """
    Preview target audience count for a notification before sending.
    Accepts same targeting fields as the notification create form.
    Returns the number of users who would receive the notification.
    """
    from core.push_service import get_target_audience_count

    # Build a temporary (unsaved) Notification from the request data
    notification = Notification(
        is_global=request.data.get('is_global', True),
        target_gender=request.data.get('target_gender', ''),
        target_nationalities=request.data.get('target_nationalities', []),
        target_age_min=request.data.get('target_age_min'),
        target_age_max=request.data.get('target_age_max'),
        target_verified_only=request.data.get('target_verified_only', False),
        target_badge_type=request.data.get('target_badge_type', ''),
        target_language=request.data.get('target_language', ''),
    )

    count = get_target_audience_count(notification)
    return Response({'target_count': count})


@api_view(['GET'])
@permission_classes([AllowAny])
def app_settings(request):
    """Public endpoint: Anyone can view app settings"""
    settings = AppSettings.objects.first()
    if settings:
        serializer = AppSettingsSerializer(settings)
        return Response(serializer.data)
    return Response({})


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """
    Enhanced health check endpoint for load balancers and monitoring.

    Returns 200 OK with detailed component statuses including database,
    cache, storage, and optional memory information.
    """
    import time
    import os
    from django.db import connection
    from django.core.cache import cache

    checks = {}
    overall_healthy = True

    # ── Database check ────────────────────────────────────────
    try:
        start = time.monotonic()
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            cursor.fetchone()
        latency = round((time.monotonic() - start) * 1000, 1)
        checks['database'] = {'status': 'up', 'latency_ms': latency}
    except Exception as e:
        checks['database'] = {'status': 'down', 'error': str(e)}
        overall_healthy = False

    # ── Cache check ───────────────────────────────────────────
    try:
        start = time.monotonic()
        cache.set('_health_check', 'ok', timeout=10)
        value = cache.get('_health_check')
        latency = round((time.monotonic() - start) * 1000, 1)
        if value == 'ok':
            checks['cache'] = {'status': 'up', 'latency_ms': latency}
        else:
            checks['cache'] = {'status': 'degraded', 'latency_ms': latency, 'error': 'value mismatch'}
            overall_healthy = False
    except Exception as e:
        checks['cache'] = {'status': 'down', 'error': str(e)}
        overall_healthy = False

    # ── Storage / disk space check ────────────────────────────
    try:
        stat = os.statvfs('/')
        free_bytes = stat.f_bavail * stat.f_frsize
        total_bytes = stat.f_blocks * stat.f_frsize
        free_gb = round(free_bytes / (1024 ** 3), 2)
        total_gb = round(total_bytes / (1024 ** 3), 2)
        checks['storage'] = {
            'status': 'up',
            'free_gb': free_gb,
            'total_gb': total_gb,
        }
        # Warn if less than 1 GB free
        if free_gb < 1.0:
            checks['storage']['status'] = 'warning'
    except Exception as e:
        checks['storage'] = {'status': 'unknown', 'error': str(e)}

    # ── Memory check (optional, requires psutil) ──────────────
    try:
        import psutil
        mem = psutil.virtual_memory()
        checks['memory'] = {
            'status': 'up',
            'used_percent': mem.percent,
            'available_mb': round(mem.available / (1024 ** 2), 1),
        }
        if mem.percent > 90:
            checks['memory']['status'] = 'warning'
    except ImportError:
        pass  # psutil not installed — skip memory check
    except Exception as e:
        checks['memory'] = {'status': 'unknown', 'error': str(e)}

    response_status = status.HTTP_200_OK if overall_healthy else status.HTTP_503_SERVICE_UNAVAILABLE

    return Response({
        'status': 'healthy' if overall_healthy else 'degraded',
        'version': '1.0.0',
        'timestamp': timezone.now().isoformat(),
        'checks': checks,
    }, status=response_status)


@api_view(['GET'])
@permission_classes([AllowAny])
def home_feed(request):
    """Combined endpoint for home screen — hero slides, featured articles, feature cards, categories, event cards, and settings."""
    hero_slides = HeroSlide.objects.filter(is_active=True)

    now = timezone.now()
    base_articles = Article.objects.select_related('category').prefetch_related('media').filter(
        is_draft=False,
    ).exclude(
        scheduled_publish_at__gt=now,
    ).exclude(
        expires_at__lt=now,
    ).annotate(
        comment_count=Count('comments', distinct=True),
    ).order_by('-publish_date')  # Explicitly order by newest first
    if request.user.is_authenticated:
        base_articles = base_articles.annotate(
            is_liked=Exists(ArticleLike.objects.filter(article=OuterRef('pk'), user=request.user)),
        )
    else:
        from django.db.models import Value, BooleanField
        base_articles = base_articles.annotate(is_liked=Value(False, output_field=BooleanField()))

    featured_articles = base_articles.filter(is_featured=True)[:5]
    articles = base_articles[:10]  # Already ordered by -publish_date
    feature_cards = FeatureCard.objects.filter(is_active=True).prefetch_related(
        'key_point_items', 'impact_area_items', 'media',
    )
    categories = Category.objects.all()
    settings = AppSettings.objects.first()

    # Combine both event types: EventRegistration (with forms) and Event (informational)
    from django.utils import timezone

    # Get events with registration
    event_registrations = EventRegistration.objects.filter(
        is_active=True
    ).prefetch_related('form_fields', 'submissions')

    # Get regular informational events (upcoming only)
    now = timezone.now()
    informational_events = Event.objects.filter(
        is_active=True,
        event_date__gte=now  # Only future events
    ).prefetch_related('speakers')

    # Serialize both types
    event_reg_data = EventRegistrationSerializer(event_registrations, many=True, context={'request': request}).data
    info_event_data = EventSerializer(informational_events, many=True, context={'request': request}).data

    # Mark which events have registration
    for event in event_reg_data:
        event['has_registration'] = True
        event['card_type'] = event.get('card_type', 'event')

    # Transform Event fields to match EventRegistration format for frontend compatibility
    for event in info_event_data:
        event['has_registration'] = False
        event['card_type'] = 'event'
        # Map Event fields to EventRegistration field names
        event['event_title'] = event.pop('name', '')
        event['event_title_fr'] = event.pop('name_fr', '')
        event['event_description'] = event.pop('description', '')
        event['event_description_fr'] = event.pop('description_fr', '')
        event['event_poster'] = event.pop('image', None)
        event['venue'] = event.pop('address', '')
        event['venue_fr'] = ''
        event['venue_address'] = event.get('venue', '')
        # Add default values for fields that Event doesn't have
        event['contact_email'] = ''
        event['contact_phone'] = ''
        event['is_registration_enabled'] = False
        event['registration_deadline'] = None
        event['max_registrations'] = 0
        event['allow_proxy_registration'] = False
        event['confirmation_message'] = ''
        event['confirmation_message_fr'] = ''
        event['is_active'] = True
        event['order'] = 0
        event['form_fields'] = []
        event['has_registered'] = False
        event['user_submission_status'] = None
        event['is_registration_open'] = False
        event['current_registration_count'] = 0
        event['event_end_date'] = None

    # Combine and sort by date
    all_event_cards = list(event_reg_data) + list(info_event_data)
    all_event_cards.sort(key=lambda x: x.get('event_date', ''))

    # Latest magazines (published only, newest first)
    magazines = MagazineEdition.objects.prefetch_related('images').filter(
        status='published',
    ).order_by('-publish_date')[:5]
    if request.user.is_authenticated:
        magazines = magazines.annotate(
            is_liked=Exists(MagazineLike.objects.filter(user=request.user, edition=OuterRef('pk')))
        )

    data = {
        'hero_slides': HeroSlideSerializer(hero_slides, many=True, context={'request': request}).data,
        'featured_articles': ArticleSerializer(featured_articles, many=True, context={'request': request}).data,
        'articles': ArticleSerializer(articles, many=True, context={'request': request}).data,
        'feature_cards': FeatureCardSerializer(feature_cards, many=True, context={'request': request}).data,
        'event_cards': all_event_cards,
        'magazines': MagazineEditionSerializer(magazines, many=True, context={'request': request}).data,
        'categories': CategorySerializer(categories, many=True).data,
        'settings': AppSettingsSerializer(settings).data if settings else {},
    }
    return Response(data)


# ── Search Endpoints ────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([SearchRateThrottle])
def search_articles(request):
    """
    Search articles by query string in both English and French.
    Query params:
      - q: search query (required, min 2 characters)
      - lang: language preference (en or fr) for display
    """
    query = request.GET.get('q', '').strip()
    lang = request.GET.get('lang', 'en')

    if not query or len(query) < 2:
        return Response({'results': [], 'count': 0})

    # Bilingual search in title and content
    articles = Article.objects.filter(
        Q(title__icontains=query) | Q(content__icontains=query) |
        Q(title_fr__icontains=query) | Q(content_fr__icontains=query)
    ).select_related('category').prefetch_related('media').annotate(
        comment_count=Count('comments', distinct=True),
    )

    # Add is_liked annotation if authenticated
    if request.user.is_authenticated:
        articles = articles.annotate(
            is_liked=Exists(ArticleLike.objects.filter(article=OuterRef('pk'), user=request.user)),
        )
    else:
        from django.db.models import Value, BooleanField
        articles = articles.annotate(is_liked=Value(False, output_field=BooleanField()))

    articles = articles[:20]  # Limit to 20 results

    serializer = ArticleSerializer(articles, many=True, context={'request': request})
    return Response({
        'results': serializer.data,
        'count': len(serializer.data)
    })


@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([SearchRateThrottle])
def search_magazines(request):
    """
    Search magazine editions by query string in both English and French.
    Query params:
      - q: search query (required, min 2 characters)
      - lang: language preference (en or fr) for display
    """
    query = request.GET.get('q', '').strip()
    lang = request.GET.get('lang', 'en')

    if not query or len(query) < 2:
        return Response({'results': [], 'count': 0})

    # Bilingual search in title and description
    magazines = MagazineEdition.objects.filter(
        Q(title__icontains=query) | Q(description__icontains=query) |
        Q(title_fr__icontains=query) | Q(description_fr__icontains=query)
    ).prefetch_related('images')[:20]  # Limit to 20 results

    serializer = MagazineEditionSerializer(magazines, many=True, context={'request': request})
    return Response({
        'results': serializer.data,
        'count': len(serializer.data)
    })


# ── Hero Text and Menu ViewSets ────────────────────────────────────────────

class HeroTextContentViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for hero text content.
    Returns active hero text items ordered by order field.
    """
    queryset = HeroTextContent.objects.filter(is_active=True)
    serializer_class = HeroTextContentSerializer
    permission_classes = [AllowAny]


class QuickAccessMenuViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for quick access menu items.
    Returns active menu items ordered by order field.
    """
    queryset = QuickAccessMenuItem.objects.filter(is_active=True)
    serializer_class = QuickAccessMenuItemSerializer
    permission_classes = [AllowAny]


# ── Verification System ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_verification_request(request):
    """
    Submit a verification request for Gold or Blue badge.
    User must provide professional email, phone, position, and optional social links.
    """
    serializer = VerificationRequestSerializer(data=request.data, context={'request': request})

    if serializer.is_valid():
        verification_request = serializer.save(user=request.user)
        return Response(
            {
                'message': 'Verification request submitted successfully! '
                          'Review typically takes up to 24 hours.',
                'request_id': verification_request.id,
                'status': verification_request.status,
            },
            status=status.HTTP_201_CREATED
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_verification_status(request):
    """
    Check current user's verification status.
    Returns latest verification request and profile verification status.
    """
    user = request.user

    # Get latest verification request
    latest_request = VerificationRequest.objects.filter(user=user).order_by('-created_at').first()

    # Check if user is verified in profile
    is_verified = user.profile.is_verified if hasattr(user, 'profile') else False
    badge_type = user.profile.badge_type if hasattr(user, 'profile') else None

    # Can appeal if latest request is rejected and no appeal yet
    can_appeal = (
        latest_request is not None and
        latest_request.status == 'rejected' and
        not latest_request.appeal_message
    )

    response_data = {
        'id': latest_request.id if latest_request else None,
        'is_verified': is_verified,
        'badge_type': badge_type,
        'has_verification_request': latest_request is not None,
        'status': latest_request.status if latest_request else None,
        'rejection_reason': latest_request.rejection_reason if latest_request else None,
        'appealed_at': latest_request.appeal_submitted_at.isoformat() if latest_request and latest_request.appeal_submitted_at else None,
        'can_appeal': can_appeal,
        'request_details': VerificationRequestSerializer(latest_request).data if latest_request else None,
    }

    return Response(response_data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_verification_appeal(request):
    """
    Submit appeal for rejected verification request.
    User must provide explanation for why they believe rejection was incorrect.
    """
    # Get latest rejected request
    latest_request = VerificationRequest.objects.filter(
        user=request.user,
        status='rejected'
    ).order_by('-created_at').first()

    if not latest_request:
        return Response(
            {'detail': 'No rejected verification request found.'},
            status=status.HTTP_404_NOT_FOUND
        )

    if latest_request.appeal_message:
        return Response(
            {'detail': 'You have already submitted an appeal for this request.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    serializer = VerificationAppealSerializer(data=request.data)

    if serializer.is_valid():
        latest_request.submit_appeal(serializer.validated_data['appeal_message'])
        return Response({
            'message': 'Appeal submitted successfully. Our team will review it shortly.',
            'status': latest_request.status,
        })

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def admin_verification_action(request, request_id):
    """
    Admin endpoint to approve or reject verification requests.
    Requires staff/admin permissions.
    """
    # Require superuser for verification badge management
    if not request.user.is_superuser:
        return Response(
            {'detail': 'Superuser permissions required.'},
            status=status.HTTP_403_FORBIDDEN
        )

    try:
        verification_request = VerificationRequest.objects.get(id=request_id)
    except VerificationRequest.DoesNotExist:
        return Response(
            {'detail': 'Verification request not found.'},
            status=status.HTTP_404_NOT_FOUND
        )

    if verification_request.status not in ['pending', 'appealed']:
        return Response(
            {'detail': 'Can only act on pending or appealed requests.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    serializer = AdminVerificationActionSerializer(data=request.data)

    if serializer.is_valid():
        action = serializer.validated_data['action']

        if action == 'approve':
            badge_type = serializer.validated_data['badge_type']
            verification_request.approve(admin_user=request.user, badge_type=badge_type)
            message = f'Verification request approved with {badge_type} badge.'
        else:  # reject
            reason = serializer.validated_data['rejection_reason']
            verification_request.reject(admin_user=request.user, reason=reason)
            message = 'Verification request rejected.'

        return Response({
            'message': message,
            'status': verification_request.status,
            'badge_type': verification_request.badge_type,
        })

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class EventRegistrationViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: View standalone event registrations"""
    permission_classes = [AllowAny]
    serializer_class = EventRegistrationSerializer

    def get_queryset(self):
        return EventRegistration.objects.filter(
            is_active=True
        ).prefetch_related('form_fields', 'submissions')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    @action(detail=True, methods=['get'], url_path='ics', permission_classes=[AllowAny])
    def download_ics(self, request, pk=None):
        """Generate and download an ICS calendar file for the event registration."""
        from django.http import HttpResponse
        event_reg = self.get_object()

        if not event_reg.event_date:
            return Response({'detail': 'No event date set.'}, status=400)

        dtstart = event_reg.event_date.strftime('%Y%m%dT%H%M%SZ')
        if event_reg.event_end_date:
            dtend = event_reg.event_end_date.strftime('%Y%m%dT%H%M%SZ')
        else:
            dtend = (event_reg.event_date + timedelta(hours=2)).strftime('%Y%m%dT%H%M%SZ')
        uid = f"event-reg-{event_reg.id}@burundi4africa.com"
        dtstamp = timezone.now().strftime('%Y%m%dT%H%M%SZ')

        # Escape special chars in ICS text
        summary = event_reg.event_title.replace(',', '\\,').replace(';', '\\;')
        description = event_reg.event_description[:500].replace('\n', '\\n').replace(',', '\\,')
        location = event_reg.venue.replace(',', '\\,') if event_reg.venue else ''

        ics_content = (
            "BEGIN:VCALENDAR\r\n"
            "VERSION:2.0\r\n"
            "PRODID:-//Burundi AU Chairmanship//Events//EN\r\n"
            "CALSCALE:GREGORIAN\r\n"
            "METHOD:PUBLISH\r\n"
            "BEGIN:VEVENT\r\n"
            f"UID:{uid}\r\n"
            f"DTSTART:{dtstart}\r\n"
            f"DTEND:{dtend}\r\n"
            f"DTSTAMP:{dtstamp}\r\n"
            f"SUMMARY:{summary}\r\n"
            f"DESCRIPTION:{description}\r\n"
            f"LOCATION:{location}\r\n"
            "STATUS:CONFIRMED\r\n"
            "END:VEVENT\r\n"
            "END:VCALENDAR\r\n"
        )

        response = HttpResponse(ics_content, content_type='text/calendar; charset=utf-8')
        response['Content-Disposition'] = f'attachment; filename="event-{event_reg.id}.ics"'
        return response


class EventSubmissionViewSet(mixins.CreateModelMixin, mixins.ListModelMixin,
                             mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """User submissions for event registrations (create/list/retrieve only)"""
    permission_classes = [IsAuthenticated]
    serializer_class = EventSubmissionSerializer

    def get_queryset(self):
        # Users can only see their own submissions
        return EventSubmission.objects.filter(
            user=self.request.user
        ).select_related('event_registration', 'user')

    def perform_create(self, serializer):
        event_reg = serializer.validated_data['event_registration']
        user = self.request.user
        # Enforce one self-registration per user per event
        if not serializer.validated_data.get('is_proxy', False):
            if EventSubmission.objects.filter(event_registration=event_reg, user=user, is_proxy=False).exists():
                from rest_framework.exceptions import ValidationError
                raise ValidationError({'detail': 'You have already registered for this event.'})

        # Check capacity and auto-waitlist if full
        is_waitlisted = False
        if event_reg.max_registrations > 0:
            current_count = event_reg.submissions.filter(is_waitlisted=False).count()
            if current_count >= event_reg.max_registrations:
                is_waitlisted = True

        submission = serializer.save(
            user=user,
            is_waitlisted=is_waitlisted,
            status='waitlist' if is_waitlisted else 'pending',
        )

        # Also create EventWaitlist entry for waitlisted submissions
        if is_waitlisted:
            position = EventWaitlist.objects.filter(event_registration=event_reg).count() + 1
            EventWaitlist.objects.get_or_create(
                user=user,
                event_registration=event_reg,
                defaults={'position': position},
            )

        # Send confirmation email
        if event_reg.send_confirmation_email and user.email:
            try:
                from django.core.mail import send_mail
                from django.conf import settings as django_settings

                subject = f'Registration Confirmation: {event_reg.event_title}'

                # Build HTML email
                html_message = f'''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:600px;margin:0 auto;padding:40px 20px;">
  <div style="background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
    <div style="background:linear-gradient(135deg,#101c2e 0%,#1a2d47 100%);padding:40px 32px;text-align:center;">
      <div style="width:60px;height:60px;background:white;border-radius:12px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;">
        <span style="font-size:28px;font-weight:900;color:#101c2e;">B</span>
      </div>
      <h1 style="color:white;font-size:22px;margin:0 0 8px;font-weight:700;">Registration Confirmed</h1>
      <p style="color:#a0aec0;font-size:14px;margin:0;">African Union Chairmanship 2026-2027</p>
    </div>
    <div style="padding:32px;">
      <p style="color:#2d3748;font-size:16px;line-height:1.6;margin:0 0 20px;">
        Dear <strong>{user.get_full_name() or user.username}</strong>,
      </p>
      <p style="color:#4a5568;font-size:15px;line-height:1.6;margin:0 0 24px;">
        Thank you for registering for <strong>{event_reg.event_title}</strong>. Your registration has been received and is being processed.
      </p>
      <div style="background:#f7fafc;border-radius:12px;padding:20px;margin:0 0 24px;">
        <h3 style="color:#2d3748;font-size:14px;margin:0 0 12px;text-transform:uppercase;letter-spacing:0.5px;">Event Details</h3>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Event</td><td style="padding:6px 0;color:#2d3748;font-size:14px;font-weight:600;">{event_reg.event_title}</td></tr>'''

                if event_reg.event_date:
                    html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Date</td><td style="padding:6px 0;color:#2d3748;font-size:14px;">{event_reg.event_date.strftime("%B %d, %Y at %H:%M")}</td></tr>'''
                if event_reg.venue:
                    html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Venue</td><td style="padding:6px 0;color:#2d3748;font-size:14px;">{event_reg.venue}</td></tr>'''
                if is_waitlisted:
                    html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Status</td><td style="padding:6px 0;color:#e53e3e;font-size:14px;font-weight:600;">Waitlisted</td></tr>'''
                else:
                    html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Status</td><td style="padding:6px 0;color:#38a169;font-size:14px;font-weight:600;">Registered</td></tr>'''

                html_message += '''
        </table>
      </div>'''

                if event_reg.confirmation_message:
                    html_message += f'''
      <div style="background:#fffff0;border-left:4px solid #ecc94b;padding:16px 20px;border-radius:0 8px 8px 0;margin:0 0 24px;">
        <p style="color:#744210;font-size:14px;line-height:1.6;margin:0;">{event_reg.confirmation_message}</p>
      </div>'''

                html_message += f'''
      <p style="color:#718096;font-size:13px;line-height:1.6;margin:0;">
        If you have any questions, please contact us at <a href="mailto:{event_reg.contact_email or "info@burundi4africa.com"}" style="color:#3182ce;">{event_reg.contact_email or "info@burundi4africa.com"}</a>
      </p>
    </div>
    <div style="background:#f7fafc;padding:20px 32px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="color:#a0aec0;font-size:12px;margin:0;">Republic of Burundi &mdash; African Union Chairmanship 2026-2027</p>
    </div>
  </div>
</div>
</body>
</html>'''

                plain_message = f"Dear {user.get_full_name() or user.username},\n\nThank you for registering for {event_reg.event_title}.\n\n"
                if event_reg.confirmation_message:
                    plain_message += f"{event_reg.confirmation_message}\n\n"
                plain_message += "Best regards,\nBurundi AU Chairmanship Team"

                send_mail(
                    subject=subject,
                    message=plain_message,
                    from_email=django_settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    html_message=html_message,
                    fail_silently=True,
                )
            except Exception:
                pass  # Don't fail registration if email fails

    @action(detail=True, methods=['get'], url_path='qr-ticket')
    def qr_ticket(self, request, pk=None):
        """Generate QR ticket data for a submission."""
        import hashlib
        submission = self.get_object()

        # Ensure only the owner can view their ticket
        if submission.user != request.user:
            return Response({'detail': 'Not your submission.'}, status=status.HTTP_403_FORBIDDEN)

        # Ensure QR hash exists
        if not submission.qr_ticket_hash:
            submission.generate_qr_hash()
            EventSubmission.objects.filter(pk=submission.pk).update(qr_ticket_hash=submission.qr_ticket_hash)

        event_reg = submission.event_registration
        attendee_name = submission.proxy_name if submission.is_proxy else (
            submission.user.first_name or submission.user.username
        )

        ticket_data = {
            'ticket_id': f'TKT-{submission.id:06d}',
            'submission_id': submission.id,
            'event_name': event_reg.event_title,
            'event_date': event_reg.event_date.isoformat() if event_reg.event_date else None,
            'event_end_date': event_reg.event_end_date.isoformat() if event_reg.event_end_date else None,
            'venue': event_reg.venue,
            'venue_address': event_reg.venue_address,
            'attendee_name': attendee_name,
            'attendee_email': submission.proxy_email if submission.is_proxy else submission.user.email,
            'status': submission.status,
            'is_waitlisted': submission.is_waitlisted,
            'checked_in_at': submission.checked_in_at.isoformat() if submission.checked_in_at else None,
            'qr_data': f'{submission.id}:{submission.qr_ticket_hash}',
            'qr_hash': submission.qr_ticket_hash,
            'event_poster': event_reg.event_poster.url if event_reg.event_poster else None,
        }
        return Response(ticket_data)

    @action(detail=True, methods=['post'], url_path='check-in')
    def check_in(self, request, pk=None):
        """Check in a submission using QR code data (admin/staff use)."""
        submission = self.get_object()
        qr_data = request.data.get('qr_data', '')

        if not qr_data:
            return Response({'detail': 'qr_data field is required.'}, status=400)

        # Parse qr_data format: "submission_id:hash"
        parts = qr_data.split(':')
        if len(parts) != 2:
            return Response({'detail': 'Invalid QR code format.'}, status=400)

        qr_sub_id, qr_hash = parts
        try:
            qr_sub_id = int(qr_sub_id)
        except ValueError:
            return Response({'detail': 'Invalid QR code.'}, status=400)

        if qr_sub_id != submission.id or qr_hash != submission.qr_ticket_hash:
            return Response({'detail': 'QR code validation failed.'}, status=400)

        if submission.checked_in_at:
            return Response({
                'detail': 'Already checked in.',
                'checked_in_at': submission.checked_in_at.isoformat(),
            }, status=400)

        submission.checked_in_at = timezone.now()
        submission.save(update_fields=['checked_in_at'])

        # Also update EventCheckIn if exists
        EventCheckIn.objects.filter(submission=submission).update(
            checked_in=True,
            checked_in_at=submission.checked_in_at,
            checked_in_by=request.user,
        )

        return Response({
            'message': 'Check-in successful.',
            'checked_in_at': submission.checked_in_at.isoformat(),
            'attendee': submission.user.first_name or submission.user.username,
            'event': submission.event_registration.event_title,
        })

    @action(detail=False, methods=['post'], url_path='register-proxy')
    def register_proxy(self, request):
        """Register on behalf of someone else"""
        serializer = ProxyRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            event_reg = EventRegistration.objects.get(pk=data['event_registration'])
        except EventRegistration.DoesNotExist:
            return Response({'detail': 'Event not found.'}, status=status.HTTP_404_NOT_FOUND)

        if not event_reg.allow_proxy_registration:
            return Response({'detail': 'Proxy registration is not allowed for this event.'}, status=status.HTTP_400_BAD_REQUEST)

        submission = EventSubmission.objects.create(
            event_registration=event_reg,
            user=request.user,
            is_proxy=True,
            proxy_name=data['proxy_name'],
            proxy_email=data['proxy_email'],
            proxy_phone=data.get('proxy_phone', ''),
            form_data=data.get('form_data', {}),
        )
        return Response(EventSubmissionSerializer(submission).data, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_event_registrations(request):
    """Return all event submissions for the current user"""
    submissions = EventSubmission.objects.filter(user=request.user).select_related('event_registration')
    serializer = EventSubmissionSerializer(submissions, many=True, context={'request': request})
    return Response(serializer.data)


  # Duplicate delete_account and export_user_data removed — canonical versions are above (lines ~96-304)


# ── Sign-Up Email Verification OTP Endpoints ─────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPRateThrottle])
def send_signup_otp(request):
    """Send OTP to user's registration email for sign-up verification"""
    from .otp_utils import send_email_otp as _send_email_otp

    email = request.user.email
    if not email:
        return Response(
            {'detail': 'No email associated with this account'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Already verified
    if request.user.profile.is_email_verified:
        return Response({
            'message': 'Email already verified',
            'email_verified': True,
        })

    success, message, otp_id = _send_email_otp(request.user, email)

    if success:
        return Response({
            'message': message,
            'otp_id': otp_id,
            'email': email,
        })
    else:
        return Response(
            {'detail': message},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPRateThrottle])
def verify_signup_otp(request):
    """Verify sign-up email OTP and mark user as email-verified"""
    from .otp_utils import verify_email_otp as _verify_email_otp

    otp_code = request.data.get('otp_code')
    if not otp_code:
        return Response(
            {'detail': 'OTP code is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    email = request.user.email
    success, message = _verify_email_otp(request.user, email, otp_code)

    if success:
        # Mark profile as email verified
        profile = request.user.profile
        profile.is_email_verified = True
        profile.email_verified_at = timezone.now()
        profile.save()

        return Response({
            'message': message,
            'email_verified': True,
        })
    else:
        return Response(
            {'detail': message},
            status=status.HTTP_400_BAD_REQUEST
        )


# ── OTP Verification Endpoints ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPRateThrottle])
def send_email_otp(request):
    """Send OTP to user's email for verification (work email only)"""
    from .otp_utils import send_email_otp
    from .validators import validate_professional_email
    from django.core.exceptions import ValidationError as DjangoValidationError

    email = request.data.get('email')
    if not email:
        return Response(
            {'detail': 'Email is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Block consumer emails (gmail, yahoo, etc.) — verification requires work email
    try:
        validate_professional_email(email)
    except DjangoValidationError as e:
        return Response(
            {'detail': e.message},
            status=status.HTTP_400_BAD_REQUEST
        )

    success, message, otp_id = send_email_otp(request.user, email)

    if success:
        return Response({
            'message': message,
            'otp_id': otp_id
        })
    else:
        return Response(
            {'detail': message},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPRateThrottle])
def verify_email_otp(request):
    """Verify email OTP code"""
    from .otp_utils import verify_email_otp

    email = request.data.get('email')
    otp_code = request.data.get('otp_code')

    if not email or not otp_code:
        return Response(
            {'detail': 'Email and OTP code are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    success, message = verify_email_otp(request.user, email, otp_code)

    if success:
        return Response({'message': message})
    else:
        return Response(
            {'detail': message},
            status=status.HTTP_400_BAD_REQUEST
        )





# ── Support Ticket System ────────────────────────────────────────────

class SupportTicketViewSet(viewsets.ModelViewSet):
    """
    Support ticket endpoints for authenticated users.
    - GET  /api/support/tickets/          — list user's tickets
    - POST /api/support/tickets/          — create new ticket (subject + message)
    - GET  /api/support/tickets/{id}/     — ticket detail with all messages
    - POST /api/support/tickets/{id}/reply/     — add a message to ticket
    - POST /api/support/tickets/{id}/mark_read/ — mark all admin replies as read
    """
    permission_classes = [IsAuthenticated]
    throttle_classes = [SupportTicketThrottle]
    http_method_names = ['get', 'post']

    def get_serializer_class(self):
        if self.action == 'list':
            return SupportTicketListSerializer
        return SupportTicketDetailSerializer

    def get_queryset(self):
        return SupportTicket.objects.filter(
            user=self.request.user
        ).select_related('user', 'assigned_to').prefetch_related(
            'messages', 'messages__sender'
        )

    def create(self, request, *args, **kwargs):
        """Create a new ticket with the first message."""
        subject = request.data.get('subject', '').strip()
        message_text = request.data.get('message', '').strip()

        if not subject:
            return Response(
                {'detail': 'Subject is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if not message_text:
            return Response(
                {'detail': 'Message is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        ticket = SupportTicket.objects.create(
            user=request.user,
            subject=subject,
        )

        TicketMessage.objects.create(
            ticket=ticket,
            sender=request.user,
            message=message_text,
            is_admin_reply=False,
            is_read=True,
        )

        serializer = SupportTicketDetailSerializer(ticket)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def reply(self, request, pk=None):
        """User adds a message to an existing ticket."""
        ticket = self.get_object()

        # Block replies on closed tickets
        if ticket.status == 'closed':
            return Response(
                {'detail': 'This ticket is closed. Please create a new ticket.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        message_text = request.data.get('message', '').strip()

        if not message_text:
            return Response(
                {'detail': 'Message is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        TicketMessage.objects.create(
            ticket=ticket,
            sender=request.user,
            message=message_text,
            is_admin_reply=False,
            is_read=True,
        )

        # Reopen ticket if it was resolved
        if ticket.status == 'resolved':
            ticket.status = 'open'
            ticket.save(update_fields=['status'])

        serializer = SupportTicketDetailSerializer(ticket)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def rate(self, request, pk=None):
        """User submits a rating for a resolved/closed ticket."""
        ticket = self.get_object()

        if ticket.status not in ('resolved', 'closed'):
            return Response(
                {'detail': 'You can only rate resolved or closed tickets.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        rating = request.data.get('rating')
        try:
            rating = int(rating)
            if rating < 1 or rating > 5:
                raise ValueError
        except (TypeError, ValueError):
            return Response(
                {'detail': 'Rating must be between 1 and 5.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        ticket.rating = rating
        ticket.rating_comment = request.data.get('comment', '').strip()
        ticket.status = 'closed'
        ticket.save(update_fields=['rating', 'rating_comment', 'status'])

        serializer = SupportTicketDetailSerializer(ticket)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Mark all admin replies in this ticket as read."""
        ticket = self.get_object()
        count = ticket.messages.filter(
            is_admin_reply=True, is_read=False
        ).update(is_read=True)

        return Response({
            'message': f'{count} message(s) marked as read',
            'marked_count': count,
        })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def support_unread_count(request):
    """Total unread support message count across all tickets (for bell badge)."""
    count = TicketMessage.objects.filter(
        ticket__user=request.user,
        is_admin_reply=True,
        is_read=False,
    ).count()
    return Response({'unread_count': count})


# ── Popup/Announcement System ────────────────────────────────────────────

class PopupViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for Popup/Announcement system.
    GET /api/popups/active/ - returns active popups for current user
    """
    serializer_class = PopupSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Filter active and non-expired popups"""
        # Base filter: active and not expired
        queryset = Popup.objects.filter(is_active=True)

        # Filter by expiry
        from django.utils import timezone
        now = timezone.now()
        queryset = queryset.filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))

        # Order by priority (highest first), then by creation date
        return queryset.order_by('-priority', '-created_at')

    @action(detail=False, methods=['get'], url_path='active')
    def active(self, request):
        """Get all active popups for the current user"""
        popups = self.get_queryset()
        serializer = self.get_serializer(popups, many=True)
        return Response(serializer.data)


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — Authentication & Security
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def login_history(request):
    """Return login history for the current user."""
    entries = LoginHistory.objects.filter(user=request.user)[:50]
    serializer = LoginHistorySerializer(entries, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def active_sessions(request):
    """Return active sessions for the current user."""
    sessions = ActiveSession.objects.filter(user=request.user)
    serializer = ActiveSessionSerializer(sessions, many=True)
    return Response(serializer.data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def revoke_session(request, session_id):
    """Revoke (terminate) a specific active session."""
    try:
        session = ActiveSession.objects.get(pk=session_id, user=request.user)
        session.delete()
        return Response({'message': 'Session revoked successfully'})
    except ActiveSession.DoesNotExist:
        return Response({'detail': 'Session not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """Change user password."""
    serializer = PasswordChangeSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        user = request.user
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        # Log password change
        PasswordChangeHistory.objects.create(
            user=user,
            ip_address=request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip(),
        )
        # Generate new tokens
        refresh = RefreshToken.for_user(user)
        return Response({
            'message': 'Password changed successfully',
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        })
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — Content Features
# ══════════════════════════════════════════════════════════════

class BookmarkViewSet(viewsets.ModelViewSet):
    """CRUD bookmarks for authenticated users."""
    permission_classes = [IsAuthenticated]
    serializer_class = BookmarkSerializer
    http_method_names = ['get', 'post', 'delete']

    def get_queryset(self):
        qs = Bookmark.objects.filter(user=self.request.user).select_related('user')
        content_type = self.request.query_params.get('content_type')
        if content_type:
            qs = qs.filter(content_type=content_type)
        return qs

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'], url_path='check')
    def check_bookmark(self, request):
        """Check if content is bookmarked."""
        ct = request.query_params.get('content_type')
        cid = request.query_params.get('content_id')
        if not ct or not cid:
            return Response({'detail': 'content_type and content_id required'}, status=400)
        exists = Bookmark.objects.filter(user=request.user, content_type=ct, content_id=cid).exists()
        return Response({'is_bookmarked': exists})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_reaction(request):
    """Toggle a reaction on content."""
    content_type = request.data.get('content_type')
    content_id = request.data.get('content_id')
    reaction_type = request.data.get('reaction_type')

    if not all([content_type, content_id, reaction_type]):
        return Response({'detail': 'content_type, content_id, and reaction_type required'},
                        status=status.HTTP_400_BAD_REQUEST)

    existing = Reaction.objects.filter(
        user=request.user, content_type=content_type, content_id=content_id
    ).first()

    if existing:
        if existing.reaction_type == reaction_type:
            existing.delete()
            return Response({'removed': True, 'reaction_type': None})
        else:
            existing.reaction_type = reaction_type
            existing.save()
            return Response({'changed': True, 'reaction_type': reaction_type})
    else:
        Reaction.objects.create(
            user=request.user, content_type=content_type,
            content_id=content_id, reaction_type=reaction_type
        )
        return Response({'added': True, 'reaction_type': reaction_type})


@api_view(['GET'])
@permission_classes([AllowAny])
def get_reactions(request):
    """Get reaction counts for a piece of content."""
    content_type = request.query_params.get('content_type')
    content_id = request.query_params.get('content_id')
    if not content_type or not content_id:
        return Response({'detail': 'content_type and content_id required'}, status=400)

    from django.db.models import Count
    counts = Reaction.objects.filter(
        content_type=content_type, content_id=content_id
    ).values('reaction_type').annotate(count=Count('id'))

    result = {r['reaction_type']: r['count'] for r in counts}
    user_reaction = None
    if request.user.is_authenticated:
        r = Reaction.objects.filter(
            user=request.user, content_type=content_type, content_id=content_id
        ).first()
        user_reaction = r.reaction_type if r else None

    return Response({'reactions': result, 'user_reaction': user_reaction})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_reading_progress(request):
    """Update reading progress for an article."""
    article_id = request.data.get('article_id')
    progress = request.data.get('progress_percent', 0)
    scroll_pos = request.data.get('scroll_position', 0)

    if not article_id:
        return Response({'detail': 'article_id required'}, status=400)

    obj, created = ReadingProgress.objects.update_or_create(
        user=request.user, article_id=article_id,
        defaults={
            'progress_percent': min(100, max(0, int(progress))),
            'scroll_position': int(scroll_pos),
            'completed': int(progress) >= 90,
        }
    )
    return Response(ReadingProgressSerializer(obj).data)


class ArticleSeriesViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: View article series."""
    permission_classes = [AllowAny]
    queryset = ArticleSeries.objects.filter(is_active=True).prefetch_related('articles')
    serializer_class = ArticleSeriesSerializer
    pagination_class = None

    @action(detail=True, methods=['get'])
    def articles(self, request, pk=None):
        """Get articles in this series."""
        series = self.get_object()
        articles = series.articles.select_related('category').prefetch_related('media').annotate(
            comment_count=Count('comments', distinct=True),
        )
        if request.user.is_authenticated:
            articles = articles.annotate(
                is_liked=Exists(ArticleLike.objects.filter(article=OuterRef('pk'), user=request.user)),
            )
        serializer = ArticleSerializer(articles, many=True, context={'request': request})
        return Response(serializer.data)


@api_view(['GET'])
@permission_classes([AllowAny])
def trending_content(request):
    """Get currently trending content."""
    content_type = request.query_params.get('type', 'article')
    limit = min(int(request.query_params.get('limit', 10)), 50)
    items = TrendingContent.objects.filter(content_type=content_type)[:limit]
    serializer = TrendingContentSerializer(items, many=True)
    return Response(serializer.data)


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — Events & Calendar
# ══════════════════════════════════════════════════════════════

class EventReminderViewSet(viewsets.ModelViewSet):
    """Manage event reminders for authenticated users."""
    permission_classes = [IsAuthenticated]
    serializer_class = EventReminderSerializer
    http_method_names = ['get', 'post', 'delete']

    def get_queryset(self):
        return EventReminder.objects.filter(
            user=self.request.user
        ).select_related('event', 'event_registration')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class EventSpeakerViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: View event speakers."""
    permission_classes = [AllowAny]
    queryset = EventSpeaker.objects.filter(is_active=True)
    serializer_class = EventSpeakerSerializer
    pagination_class = None

    def get_queryset(self):
        qs = EventSpeaker.objects.filter(is_active=True)
        event_id = self.request.query_params.get('event')
        event_reg_id = self.request.query_params.get('event_registration')
        if event_id:
            qs = qs.filter(events__id=event_id)
        elif event_reg_id:
            qs = qs.filter(event_registrations__id=event_reg_id)
        return qs


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_event_feedback(request):
    """Submit post-event feedback."""
    serializer = EventFeedbackSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save(user=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def event_checkin(request):
    """Check in to an event using QR code."""
    qr_code = request.data.get('qr_code')
    if not qr_code:
        return Response({'detail': 'QR code required'}, status=400)

    try:
        checkin = EventCheckIn.objects.get(qr_code=qr_code)
        if checkin.checked_in:
            return Response({'detail': 'Already checked in', 'checked_in_at': checkin.checked_in_at})
        checkin.checked_in = True
        checkin.checked_in_at = timezone.now()
        checkin.checked_in_by = request.user
        checkin.save()
        return Response({'message': 'Check-in successful', 'checked_in_at': checkin.checked_in_at})
    except EventCheckIn.DoesNotExist:
        return Response({'detail': 'Invalid QR code'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def join_event_waitlist(request):
    """Join a waitlist for a full event."""
    event_reg_id = request.data.get('event_registration')
    if not event_reg_id:
        return Response({'detail': 'event_registration required'}, status=400)

    try:
        event_reg = EventRegistration.objects.get(pk=event_reg_id)
    except EventRegistration.DoesNotExist:
        return Response({'detail': 'Event not found'}, status=404)

    if EventWaitlist.objects.filter(user=request.user, event_registration=event_reg).exists():
        return Response({'detail': 'Already on waitlist'}, status=400)

    position = EventWaitlist.objects.filter(event_registration=event_reg).count() + 1
    waitlist = EventWaitlist.objects.create(
        user=request.user, event_registration=event_reg, position=position
    )
    return Response(EventWaitlistSerializer(waitlist).data, status=201)


class EventPhotoViewSet(viewsets.ModelViewSet):
    """User-uploaded event photos."""
    permission_classes = [IsAuthenticated]
    serializer_class = EventPhotoSerializer
    http_method_names = ['get', 'post']

    def get_queryset(self):
        qs = EventPhoto.objects.filter(is_approved=True).select_related(
            'user', 'event', 'event_registration'
        )
        event_id = self.request.query_params.get('event')
        event_reg_id = self.request.query_params.get('event_registration')
        if event_id:
            qs = qs.filter(event_id=event_id)
        elif event_reg_id:
            qs = qs.filter(event_registration_id=event_reg_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — Communication & Social
# ══════════════════════════════════════════════════════════════

class ConversationViewSet(viewsets.ModelViewSet):
    """In-app messaging conversations."""
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationSerializer
    http_method_names = ['get', 'post']

    def get_queryset(self):
        return Conversation.objects.filter(
            participants=self.request.user
        ).prefetch_related('participants', 'messages', 'messages__sender')

    def create(self, request, *args, **kwargs):
        """Start a new conversation with another user."""
        recipient_id = request.data.get('recipient_id')
        if not recipient_id:
            return Response({'detail': 'recipient_id required'}, status=400)
        try:
            recipient = User.objects.get(pk=recipient_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found'}, status=404)

        # Check for existing conversation between these two users
        existing = Conversation.objects.filter(
            participants=request.user
        ).filter(participants=recipient)
        if existing.exists():
            serializer = self.get_serializer(existing.first())
            return Response(serializer.data)

        convo = Conversation.objects.create()
        convo.participants.add(request.user, recipient)
        serializer = self.get_serializer(convo)
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['get', 'post'])
    def messages(self, request, pk=None):
        """Get or send messages in a conversation."""
        convo = self.get_object()
        if request.method == 'GET':
            msgs = convo.messages.select_related('sender').all()
            # Mark messages as read
            msgs.filter(is_read=False).exclude(sender=request.user).update(is_read=True, read_at=timezone.now())
            serializer = DirectMessageSerializer(msgs, many=True, context={'request': request})
            return Response(serializer.data)

        content = request.data.get('content', '').strip()
        if not content:
            return Response({'detail': 'Message content required'}, status=400)

        from django.utils.html import escape
        msg = DirectMessage.objects.create(
            conversation=convo, sender=request.user, content=escape(content)
        )
        convo.last_message_at = msg.created_at
        convo.save(update_fields=['last_message_at'])
        return Response(DirectMessageSerializer(msg, context={'request': request}).data, status=201)


class DiscussionViewSet(viewsets.ModelViewSet):
    """Forum discussions."""
    permission_classes = [AllowAny]
    serializer_class = DiscussionSerializer
    filterset_fields = ['category']

    def get_queryset(self):
        return Discussion.objects.select_related('author', 'author__profile').all()

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update']:
            return [IsAuthenticated()]
        return [AllowAny()]

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    @action(detail=True, methods=['get', 'post'])
    def replies(self, request, pk=None):
        """Get or post replies to a discussion."""
        discussion = self.get_object()
        if request.method == 'GET':
            replies = discussion.replies.select_related('author').all()
            serializer = DiscussionReplySerializer(replies, many=True, context={'request': request})
            return Response(serializer.data)

        if not request.user.is_authenticated:
            return Response({'detail': 'Authentication required'}, status=401)
        if discussion.is_locked:
            return Response({'detail': 'Discussion is locked'}, status=400)

        from django.utils.html import escape
        content = escape(request.data.get('content', '').strip())
        if not content:
            return Response({'detail': 'Content required'}, status=400)

        parent_id = request.data.get('parent')
        reply = DiscussionReply.objects.create(
            discussion=discussion, author=request.user, content=content,
            parent_id=parent_id
        )
        discussion.reply_count = discussion.replies.count()
        discussion.last_reply_at = reply.created_at
        discussion.save(update_fields=['reply_count', 'last_reply_at'])

        return Response(DiscussionReplySerializer(reply, context={'request': request}).data, status=201)

    @action(detail=True, methods=['post'], url_path='record-view', permission_classes=[AllowAny])
    def record_view(self, request, pk=None):
        """Record a view on a discussion."""
        Discussion.objects.filter(pk=pk).update(view_count=F('view_count') + 1)
        return Response({'message': 'View recorded'})


class PollViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: View active polls. Auth required to vote."""
    permission_classes = [AllowAny]
    serializer_class = PollSerializer

    def get_queryset(self):
        return Poll.objects.filter(is_active=True).prefetch_related(
            'options', 'votes'
        )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def vote(self, request, pk=None):
        """Vote on a poll."""
        poll = self.get_object()
        option_id = request.data.get('option_id')

        if not option_id:
            return Response({'detail': 'option_id required'}, status=400)

        if poll.expires_at and timezone.now() > poll.expires_at:
            return Response({'detail': 'Poll has expired'}, status=400)

        try:
            option = PollOption.objects.get(pk=option_id, poll=poll)
        except PollOption.DoesNotExist:
            return Response({'detail': 'Invalid option'}, status=404)

        if not poll.multiple_choice:
            # Single choice - remove existing votes
            existing = PollVote.objects.filter(user=request.user, poll=poll)
            if existing.exists():
                for v in existing:
                    PollOption.objects.filter(pk=v.option_id).update(vote_count=F('vote_count') - 1)
                    Poll.objects.filter(pk=poll.pk).update(total_votes=F('total_votes') - 1)
                existing.delete()

        if PollVote.objects.filter(user=request.user, option=option).exists():
            return Response({'detail': 'Already voted for this option'}, status=400)

        PollVote.objects.create(user=request.user, poll=poll, option=option)
        PollOption.objects.filter(pk=option.pk).update(vote_count=F('vote_count') + 1)
        Poll.objects.filter(pk=poll.pk).update(total_votes=F('total_votes') + 1)

        poll.refresh_from_db()
        return Response(PollSerializer(poll, context={'request': request}).data)


@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
def notification_preferences(request):
    """Get or update notification preferences."""
    prefs, _ = NotificationPreference.objects.get_or_create(user=request.user)
    if request.method == 'GET':
        return Response(NotificationPreferenceSerializer(prefs).data)
    serializer = NotificationPreferenceSerializer(prefs, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=400)


class AnnouncementBannerViewSet(viewsets.ReadOnlyModelViewSet):
    """Active announcement banners."""
    permission_classes = [AllowAny]
    serializer_class = AnnouncementBannerSerializer
    pagination_class = None

    def get_queryset(self):
        now = timezone.now()
        return AnnouncementBanner.objects.filter(
            is_active=True
        ).filter(
            Q(starts_at__isnull=True) | Q(starts_at__lte=now)
        ).filter(
            Q(expires_at__isnull=True) | Q(expires_at__gt=now)
        )


class ContactDirectoryViewSet(viewsets.ReadOnlyModelViewSet):
    """Public contact directory."""
    permission_classes = [AllowAny]
    serializer_class = ContactDirectorySerializer
    filterset_fields = ['category', 'country']

    def get_queryset(self):
        return ContactDirectory.objects.filter(is_active=True).order_by('order', 'name')


class LiveQAViewSet(viewsets.ReadOnlyModelViewSet):
    """Live Q&A sessions and questions."""
    permission_classes = [AllowAny]
    serializer_class = LiveQASessionSerializer

    def get_queryset(self):
        return LiveQASession.objects.filter(is_active=True).select_related(
            'event', 'event_registration', 'moderator'
        ).prefetch_related('questions')

    @action(detail=True, methods=['get', 'post'])
    def questions(self, request, pk=None):
        """Get approved questions or submit a new question."""
        session = self.get_object()
        if request.method == 'GET':
            questions = session.questions.filter(is_approved=True).select_related('user')
            return Response(LiveQAQuestionSerializer(questions, many=True, context={'request': request}).data)

        if not request.user.is_authenticated:
            return Response({'detail': 'Authentication required'}, status=401)

        question_text = request.data.get('question', '').strip()
        if not question_text:
            return Response({'detail': 'Question text required'}, status=400)

        from django.utils.html import escape
        q = LiveQAQuestion.objects.create(
            session=session, user=request.user, question=escape(question_text)
        )
        return Response(LiveQAQuestionSerializer(q, context={'request': request}).data, status=201)

    @action(detail=True, methods=['post'], url_path='questions/(?P<question_id>[0-9]+)/upvote',
            permission_classes=[IsAuthenticated])
    def upvote_question(self, request, pk=None, question_id=None):
        """Upvote a Q&A question."""
        LiveQAQuestion.objects.filter(pk=question_id, session_id=pk).update(
            upvote_count=F('upvote_count') + 1
        )
        return Response({'message': 'Upvoted'})


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — User Preferences & Onboarding
# ══════════════════════════════════════════════════════════════

@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
def user_preferences(request):
    """Get or update user preferences."""
    prefs, _ = UserPreference.objects.get_or_create(user=request.user)
    if request.method == 'GET':
        return Response(UserPreferenceSerializer(prefs).data)
    serializer = UserPreferenceSerializer(prefs, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=400)


class OnboardingStepViewSet(viewsets.ReadOnlyModelViewSet):
    """Onboarding walkthrough steps."""
    permission_classes = [AllowAny]
    queryset = OnboardingStep.objects.filter(is_active=True)
    serializer_class = OnboardingStepSerializer
    pagination_class = None


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_onboarding(request):
    """Mark onboarding as completed."""
    prefs, _ = UserPreference.objects.get_or_create(user=request.user)
    prefs.onboarding_completed = True
    prefs.save(update_fields=['onboarding_completed'])
    return Response({'message': 'Onboarding completed'})


# ══════════════════════════════════════════════════════════════
# NEW VIEWS — Infrastructure
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([AllowAny])
def maintenance_status(request):
    """Check if there's an active or upcoming maintenance window."""
    now = timezone.now()
    active = ScheduledMaintenance.objects.filter(
        is_active=True, starts_at__lte=now, ends_at__gt=now
    ).first()
    upcoming = ScheduledMaintenance.objects.filter(
        is_active=True, show_banner=True, starts_at__gt=now
    ).order_by('starts_at').first()
    return Response({
        'in_maintenance': active is not None,
        'active': ScheduledMaintenanceSerializer(active).data if active else None,
        'upcoming': ScheduledMaintenanceSerializer(upcoming).data if upcoming else None,
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def check_app_update(request):
    """Check if an app update is available."""
    current_version = request.query_params.get('version_code', 0)
    try:
        current_version = int(current_version)
    except (TypeError, ValueError):
        current_version = 0

    latest = AppRelease.objects.order_by('-version_code').first()
    if not latest:
        return Response({'update_available': False})

    return Response({
        'update_available': latest.version_code > current_version,
        'force_update': latest.is_force_update and latest.version_code > current_version,
        'latest_version': latest.version,
        'latest_version_code': latest.version_code,
        'release_notes': latest.release_notes,
        'release_notes_fr': latest.release_notes_fr,
        'android_url': latest.android_url,
        'ios_url': latest.ios_url,
    })


# ══════════════════════════════════════════════════════════════
# Admin Audit Trail
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_audit_log(request):
    """Get admin audit trail entries."""
    logs = AuditLogEntry.objects.select_related('user').order_by('-created_at')
    user_id = request.query_params.get('user_id')
    action = request.query_params.get('action')
    model = request.query_params.get('model')
    if user_id:
        logs = logs.filter(user_id=user_id)
    if action:
        logs = logs.filter(action=action)
    if model:
        logs = logs.filter(model_name=model)
    paginator = PageNumberPagination()
    paginator.page_size = 50
    page = paginator.paginate_queryset(logs, request)
    serializer = AuditLogEntrySerializer(page, many=True)
    return paginator.get_paginated_response(serializer.data)


# ══════════════════════════════════════════════════════════════
# Translation Management
# ══════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAdminUser])
def translation_entries(request):
    """List or create translation entries."""
    if request.method == 'GET':
        entries = TranslationEntry.objects.all().order_by('key', 'language')
        lang = request.query_params.get('language')
        if lang:
            entries = entries.filter(language=lang)
        serializer = TranslationEntrySerializer(entries, many=True)
        return Response(serializer.data)
    serializer = TranslationEntrySerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['PUT', 'DELETE'])
@permission_classes([IsAdminUser])
def translation_entry_detail(request, pk):
    """Update or delete a translation entry."""
    entry = get_object_or_404(TranslationEntry, pk=pk)
    if request.method == 'DELETE':
        entry.delete()
        return Response(status=204)
    serializer = TranslationEntrySerializer(entry, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=400)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def auto_translate(request):
    """Auto-translate text using Google Gemini API."""
    text = request.data.get('text', '')
    source_lang = request.data.get('source', 'en')
    target_lang = request.data.get('target', 'fr')
    if not text:
        return Response({'error': 'No text provided'}, status=400)

    # Use Google Gemini for translation
    import requests as ext_requests
    api_key = getattr(django_settings, 'GEMINI_API_KEY', '')
    if not api_key:
        return Response({'error': 'Translation service not configured'}, status=503)

    try:
        lang_names = {'en': 'English', 'fr': 'French', 'rn': 'Kirundi', 'sw': 'Swahili'}
        source_name = lang_names.get(source_lang, source_lang)
        target_name = lang_names.get(target_lang, target_lang)

        resp = ext_requests.post(
            f'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}',
            json={
                'contents': [{'parts': [{'text': f'Translate the following text from {source_name} to {target_name}. Return ONLY the translated text, nothing else.\n\n{text}'}]}],
                'generationConfig': {'temperature': 0.1}
            },
            timeout=30,
        )
        resp.raise_for_status()
        result = resp.json()
        translated = result['candidates'][0]['content']['parts'][0]['text'].strip()
        return Response({'translated_text': translated, 'source': source_lang, 'target': target_lang})
    except Exception as e:
        return Response({'error': f'Translation failed: {str(e)}'}, status=500)


# ══════════════════════════════════════════════════════════════
# Account Merge
# ══════════════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def request_account_merge(request):
    """Request to merge another account into the current one."""
    secondary_email = request.data.get('email')
    if not secondary_email:
        return Response({'error': 'Email of account to merge is required'}, status=400)
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        secondary = User.objects.get(email=secondary_email)
    except User.DoesNotExist:
        return Response({'error': 'Account not found'}, status=404)
    if secondary == request.user:
        return Response({'error': 'Cannot merge with yourself'}, status=400)
    merge, created = AccountMergeRequest.objects.get_or_create(
        primary_user=request.user, secondary_user=secondary,
        defaults={'status': 'pending'}
    )
    if not created and merge.status == 'pending':
        return Response({'message': 'Merge request already pending'})
    return Response({'message': 'Merge request submitted', 'id': merge.id}, status=201)


# ══════════════════════════════════════════════════════════════
# Account Linking — multi-provider auth
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def linked_accounts_list(request):
    """List all auth providers linked to the current user's account."""
    accounts = LinkedAccount.objects.filter(user=request.user)
    serializer = LinkedAccountSerializer(accounts, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def link_account(request):
    """Link a new auth provider to the current user's account.

    Expects: provider, provider_uid, email (optional), display_name (optional)
    """
    provider = request.data.get('provider')
    provider_uid = request.data.get('provider_uid')

    if not provider or not provider_uid:
        return Response(
            {'error': 'Both provider and provider_uid are required'},
            status=400
        )

    valid_providers = [c[0] for c in LinkedAccount.PROVIDER_CHOICES]
    if provider not in valid_providers:
        return Response(
            {'error': f'Invalid provider. Must be one of: {", ".join(valid_providers)}'},
            status=400
        )

    # Check if this provider+uid is already linked to another user
    existing = LinkedAccount.objects.filter(
        provider=provider,
        provider_uid=provider_uid
    ).exclude(user=request.user).first()

    if existing:
        return Response(
            {'error': 'This account is already linked to a different user. '
                      'Please unlink it from the other account first or use account merge.'},
            status=409
        )

    # Check if this user already has this provider linked
    already_linked = LinkedAccount.objects.filter(
        user=request.user,
        provider=provider,
        provider_uid=provider_uid
    ).first()

    if already_linked:
        return Response(
            {'message': 'This provider is already linked to your account'},
            status=200
        )

    email = request.data.get('email', '')
    display_name = request.data.get('display_name', '')

    # Determine if this should be primary (first linked account)
    is_primary = not LinkedAccount.objects.filter(user=request.user).exists()

    linked = LinkedAccount.objects.create(
        user=request.user,
        provider=provider,
        provider_uid=provider_uid,
        email=email,
        display_name=display_name,
        is_primary=is_primary,
    )

    serializer = LinkedAccountSerializer(linked)
    return Response(serializer.data, status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unlink_account(request):
    """Unlink an auth provider from the current user's account.

    Must keep at least one linked account.
    Expects: provider (required), provider_uid (optional for specificity)
    """
    provider = request.data.get('provider')
    if not provider:
        return Response({'error': 'Provider is required'}, status=400)

    # Find linked accounts for this provider
    query = LinkedAccount.objects.filter(user=request.user, provider=provider)
    provider_uid = request.data.get('provider_uid')
    if provider_uid:
        query = query.filter(provider_uid=provider_uid)

    account_to_unlink = query.first()
    if not account_to_unlink:
        return Response({'error': 'No linked account found for this provider'}, status=404)

    # Ensure at least one account remains
    total_linked = LinkedAccount.objects.filter(user=request.user).count()
    if total_linked <= 1:
        return Response(
            {'error': 'Cannot unlink your only authentication method. '
                      'Link another provider before unlinking this one.'},
            status=400
        )

    was_primary = account_to_unlink.is_primary
    account_to_unlink.delete()

    # If we removed the primary, promote the next one
    if was_primary:
        next_account = LinkedAccount.objects.filter(user=request.user).first()
        if next_account:
            next_account.is_primary = True
            next_account.save(update_fields=['is_primary'])

    return Response({'message': f'{provider} account unlinked successfully'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def merge_accounts(request):
    """Merge another user's data into the current user's account.

    Moves all linked accounts, bookmarks, reactions, comments, etc.
    from the source account to the current user, then deactivates the source.

    Expects: source_user_id (the account to absorb)
    """
    source_user_id = request.data.get('source_user_id')
    if not source_user_id:
        return Response({'error': 'source_user_id is required'}, status=400)

    try:
        source_user = User.objects.get(id=source_user_id)
    except User.DoesNotExist:
        return Response({'error': 'Source account not found'}, status=404)

    if source_user == request.user:
        return Response({'error': 'Cannot merge with yourself'}, status=400)

    target_user = request.user

    # Transfer linked accounts (skip duplicates)
    for la in LinkedAccount.objects.filter(user=source_user):
        if not LinkedAccount.objects.filter(
            user=target_user, provider=la.provider, provider_uid=la.provider_uid
        ).exists():
            la.user = target_user
            la.is_primary = False
            la.save(update_fields=['user', 'is_primary'])

    # Transfer bookmarks
    Bookmark.objects.filter(user=source_user).update(user=target_user)

    # Transfer reactions (skip duplicates)
    for reaction in Reaction.objects.filter(user=source_user):
        if not Reaction.objects.filter(
            user=target_user,
            content_type=reaction.content_type,
            content_id=reaction.content_id,
            reaction_type=reaction.reaction_type,
        ).exists():
            reaction.user = target_user
            reaction.save(update_fields=['user'])

    # Transfer reading progress
    ReadingProgress.objects.filter(user=source_user).update(user=target_user)

    # Transfer support tickets
    SupportTicket.objects.filter(user=source_user).update(user=target_user)

    # Transfer event submissions
    EventSubmission.objects.filter(user=source_user).update(user=target_user)

    # Transfer discussions & replies
    Discussion.objects.filter(author=source_user).update(author=target_user)
    DiscussionReply.objects.filter(author=source_user).update(author=target_user)

    # Transfer poll votes
    for vote in PollVote.objects.filter(user=source_user):
        if not PollVote.objects.filter(user=target_user, poll=vote.poll).exists():
            vote.user = target_user
            vote.save(update_fields=['user'])

    # Transfer notification preferences
    NotificationPreference.objects.filter(user=source_user).update(user=target_user)

    # Deactivate source account
    source_user.is_active = False
    source_user.save(update_fields=['is_active'])

    # Update source profile
    try:
        source_profile = source_user.profile
        source_profile.is_deactivated = True
        source_profile.deactivated_at = timezone.now()
        source_profile.save(update_fields=['is_deactivated', 'deactivated_at'])
    except UserProfile.DoesNotExist:
        pass

    # Record the merge
    AccountMergeRequest.objects.create(
        primary_user=target_user,
        secondary_user=source_user,
        status='approved',
        resolved_at=timezone.now(),
    )

    return Response({
        'message': f'Account {source_user.email} merged successfully. '
                   f'All data has been transferred to your account.',
    })


# ══════════════════════════════════════════════════════════════
# Article Drafts
# ══════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAdminUser])
def article_drafts(request):
    """List or create article drafts."""
    if request.method == 'GET':
        drafts = ArticleDraft.objects.filter(
            author=request.user
        ).select_related('category', 'created_by', 'last_edited_by').order_by('-updated_at')
        serializer = ArticleDraftSerializer(drafts, many=True)
        return Response(serializer.data)
    serializer = ArticleDraftSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save(author=request.user)
        return Response(serializer.data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsAdminUser])
def article_draft_detail(request, pk):
    """Get, update, or delete a specific draft."""
    draft = get_object_or_404(ArticleDraft, pk=pk, author=request.user)
    if request.method == 'GET':
        return Response(ArticleDraftSerializer(draft).data)
    if request.method == 'DELETE':
        draft.delete()
        return Response(status=204)
    serializer = ArticleDraftSerializer(draft, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=400)


# ══════════════════════════════════════════════════════════════
# Content Versioning
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAdminUser])
def content_versions(request):
    """Get version history for a content item."""
    content_type = request.query_params.get('content_type')
    content_id = request.query_params.get('content_id')
    if not content_type or not content_id:
        return Response({'error': 'content_type and content_id required'}, status=400)
    versions = ContentVersion.objects.filter(
        content_type=content_type, content_id=content_id
    ).select_related('changed_by').order_by('-version_number')
    serializer = ContentVersionSerializer(versions, many=True)
    return Response(serializer.data)


# ══════════════════════════════════════════════════════════════
# Password Strength Validation
# ══════════════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([AllowAny])
def validate_password_strength(request):
    """Validate password strength and return score."""
    password = request.data.get('password', '')
    score = 0
    feedback = []
    if len(password) >= 8:
        score += 1
    else:
        feedback.append('At least 8 characters')
    if any(c.isupper() for c in password):
        score += 1
    else:
        feedback.append('Add uppercase letter')
    if any(c.islower() for c in password):
        score += 1
    else:
        feedback.append('Add lowercase letter')
    if any(c.isdigit() for c in password):
        score += 1
    else:
        feedback.append('Add a number')
    if any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?' for c in password):
        score += 1
    else:
        feedback.append('Add a special character')

    strength = 'weak'
    if score >= 4:
        strength = 'strong'
    elif score >= 3:
        strength = 'medium'

    return Response({'score': score, 'max_score': 5, 'strength': strength, 'feedback': feedback})


# ══════════════════════════════════════════════════════════════
# Profile Completion
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_completion(request):
    """Calculate profile completion percentage."""
    user = request.user
    profile = getattr(user, 'profile', None)
    fields_check = {
        'name': bool(user.first_name or user.last_name),
        'email': bool(user.email),
        'profile_picture': bool(profile and profile.profile_picture),
        'nationality': bool(profile and profile.nationality),
        'gender': bool(profile and profile.gender),
        'date_of_birth': bool(profile and profile.date_of_birth),
        'bio': bool(profile and hasattr(profile, 'bio') and profile.bio),
        'phone': bool(profile and profile.phone_number),
        'verified': bool(profile and profile.is_verified),
    }
    completed = sum(1 for v in fields_check.values() if v)
    total = len(fields_check)
    return Response({
        'percentage': round((completed / total) * 100),
        'completed_fields': completed,
        'total_fields': total,
        'fields': fields_check,
    })


# ══════════════════════════════════════════════════════════════
# What's New / App Releases
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([AllowAny])
def whats_new(request):
    """Get recent app releases / changelog."""
    releases = AppRelease.objects.order_by('-released_at')[:10]
    serializer = AppReleaseSerializer(releases, many=True)
    return Response(serializer.data)


# ══════════════════════════════════════════════════════════════
# Event Comments
# ══════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
def event_comments(request, event_id):
    """Get or post comments on an event. Supports nested replies (1 level deep) and @mentions."""
    import re
    event = get_object_or_404(Event, pk=event_id)

    if request.method == 'GET':
        comments = EventComment.objects.filter(
            event=event, parent__isnull=True, is_approved=True
        ).select_related('user', 'user__profile').prefetch_related(
            'replies', 'replies__user', 'replies__user__profile'
        ).order_by('-created_at')
        serializer = EventCommentSerializer(comments, many=True, context={'request': request})
        return Response({
            'count': comments.count(),
            'results': serializer.data
        })

    # POST - create a comment
    if not request.user.is_authenticated:
        return Response({'error': 'Login required'}, status=401)

    content = request.data.get('content', '').strip()
    if not content:
        return Response({'error': 'Content is required'}, status=400)

    parent_id = request.data.get('parent')
    parent = None
    if parent_id:
        parent = get_object_or_404(EventComment, pk=parent_id, event=event)
        if parent.parent is not None:
            parent = parent.parent

    comment = EventComment.objects.create(
        event=event, user=request.user, parent=parent, content=content,
    )

    # Parse @mentions
    mention_pattern = re.compile(r'@(\w+)')
    usernames = mention_pattern.findall(content)
    if usernames:
        mentioned_users = User.objects.filter(username__in=usernames)
        for mu in mentioned_users:
            if mu != request.user:
                CommentMention.objects.get_or_create(comment=comment, mentioned_user=mu)
                try:
                    from .tasks import send_push_notification_async
                    name = request.user.get_full_name() or request.user.username
                    send_push_notification_async.delay(
                        user_ids=[mu.id],
                        title=f'{name} mentioned you',
                        body=f'"{content[:80]}..." in {event.name}',
                        data={'type': 'event_comment', 'event_id': str(event.id)}
                    )
                except Exception:
                    pass

    serializer = EventCommentSerializer(comment, context={'request': request})
    return Response(serializer.data, status=201)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def event_comment_delete(request, event_id, comment_id):
    """Delete own comment on an event."""
    comment = get_object_or_404(EventComment, pk=comment_id, event_id=event_id)
    if comment.user != request.user and not request.user.is_staff:
        return Response({'error': 'Permission denied'}, status=403)
    comment.delete()
    return Response({'message': 'Comment deleted'}, status=204)


@api_view(['GET'])
def event_attendees(request, event_id):
    """List attendees for event networking (name, badge, nationality only - no email/phone)."""
    get_object_or_404(Event, pk=event_id)
    submissions = EventSubmission.objects.filter(
        status__in=['pending', 'approved']
    )
    attendee_users = User.objects.filter(
        id__in=submissions.values_list('user_id', flat=True)
    ).select_related('profile').distinct()
    serializer = EventAttendeeSerializer(attendee_users, many=True, context={'request': request})
    return Response({'count': attendee_users.count(), 'results': serializer.data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_newsletter(request):
    """Toggle newsletter subscription for the authenticated user."""
    profile = request.user.profile
    receives = request.data.get('receives_newsletter')
    if receives is not None:
        profile.receives_newsletter = bool(receives)
        profile.save(update_fields=['receives_newsletter'])
    return Response({'receives_newsletter': profile.receives_newsletter})


# ══════════════════════════════════════════════════════════════
# Weekly Report Generation
# ══════════════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([IsAdminUser])
def generate_weekly_report(request):
    """Generate a weekly analytics report."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    now = timezone.now()
    week_start = now - timedelta(days=7)

    report = WeeklyReport.objects.create(
        week_start=week_start,
        week_end=now,
        new_users=User.objects.filter(date_joined__gte=week_start).count(),
        active_users=UserSession.objects.filter(last_activity__gte=week_start).values('user').distinct().count(),
        total_views=ContentAnalytics.objects.filter(date__gte=week_start.date()).aggregate(total=models.Sum('views'))['total'] or 0,
        total_engagements=ContentAnalytics.objects.filter(date__gte=week_start.date()).aggregate(total=models.Sum('likes') + models.Sum('shares') + models.Sum('comments'))['total'] or 0,
        top_content={},
    )
    return Response(WeeklyReportSerializer(report).data, status=201)


# ══════════════════════════════════════════════════════════════
# Event Agenda Items ViewSet
# ══════════════════════════════════════════════════════════════

class EventAgendaItemViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: list agenda items for events, filterable by event."""
    permission_classes = [AllowAny]
    serializer_class = EventAgendaItemSerializer

    def get_queryset(self):
        qs = EventAgendaItem.objects.select_related('speaker').all()
        event_id = self.request.query_params.get('event')
        if event_id:
            qs = qs.filter(event_id=event_id)
        return qs


# ══════════════════════════════════════════════════════════════
# Article Share Cards (#34) - OG meta tags for social sharing
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([AllowAny])
def article_share_card(request, pk):
    """Return an HTML page with Open Graph meta tags for article sharing."""
    from django.http import HttpResponse
    import re

    article = get_object_or_404(Article, pk=pk)

    # Strip HTML tags from content for description
    clean_content = re.sub(r'<[^>]+>', '', article.content)
    description = clean_content[:160].strip()
    if len(clean_content) > 160:
        description += '...'

    # Build absolute image URL
    image_url = ''
    if article.image:
        image_url = request.build_absolute_uri(article.image.url)

    share_url = f'https://burundi4africa.com/articles/{article.pk}/share/'

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{article.title}</title>

    <!-- Open Graph Meta Tags -->
    <meta property="og:title" content="{article.title}" />
    <meta property="og:description" content="{description}" />
    <meta property="og:image" content="{image_url}" />
    <meta property="og:url" content="{share_url}" />
    <meta property="og:type" content="article" />
    <meta property="og:site_name" content="Burundi AU Chairmanship" />

    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="{article.title}" />
    <meta name="twitter:description" content="{description}" />
    <meta name="twitter:image" content="{image_url}" />

    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f8f9fa;
            color: #333;
        }}
        .header {{ text-align: center; padding: 20px 0; }}
        .header img {{ max-width: 100%; border-radius: 12px; }}
        h1 {{ font-size: 28px; line-height: 1.3; color: #1a1a1a; }}
        .meta {{ color: #666; font-size: 14px; margin: 10px 0 20px; }}
        .content {{ font-size: 16px; line-height: 1.7; }}
        .cta {{
            display: inline-block;
            margin-top: 24px;
            padding: 12px 24px;
            background: #1EB53A;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
        }}
    </style>
</head>
<body>
    <div class="header">
        {"<img src='" + image_url + "' alt='" + article.title + "' />" if image_url else ""}
    </div>
    <h1>{article.title}</h1>
    <div class="meta">By {article.author} | {article.publish_date.strftime('%B %d, %Y')}</div>
    <div class="content">{clean_content[:500]}{"..." if len(clean_content) > 500 else ""}</div>
    <a href="https://burundi4africa.com" class="cta">Read more in the app</a>
</body>
</html>"""

    return HttpResponse(html, content_type='text/html')


# ══════════════════════════════════════════════════════════════
# Article Revisions (#40) - Content versioning with rollback
# ══════════════════════════════════════════════════════════════

@api_view(['GET'])
@permission_classes([IsAdminUser])
def article_revisions(request, pk):
    """List all revisions for an article."""
    article = get_object_or_404(Article, pk=pk)
    revisions = article.revisions.select_related('edited_by').order_by('-revision_number')
    serializer = ArticleRevisionSerializer(revisions, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def article_revision_restore(request, pk, revision_id):
    """Restore an article to a specific revision."""
    article = get_object_or_404(Article, pk=pk)
    revision = get_object_or_404(ArticleRevision, pk=revision_id, article=article)

    # Create a new revision to preserve current state before restoring
    current_max = article.revisions.aggregate(
        max_num=models.Max('revision_number')
    )['max_num'] or 0
    ArticleRevision.objects.create(
        article=article,
        revision_number=current_max + 1,
        title=article.title,
        content=article.content,
        edited_by=request.user,
        change_summary=f'Auto-saved before restoring to revision {revision.revision_number}',
    )

    # Restore article to the selected revision
    article.title = revision.title
    article.content = revision.content
    article.save()

    return Response({
        'detail': f'Article restored to revision {revision.revision_number}.',
        'article': ArticleSerializer(article, context={'request': request}).data,
    })


# ══════════════════════════════════════════════════════════════
# Translation Queue (#46) - EN->FR workflow
# ══════════════════════════════════════════════════════════════

@api_view(['GET', 'POST'])
@permission_classes([IsAdminUser])
def translation_queue(request):
    """List all translation requests or create a new one."""
    if request.method == 'GET':
        status_filter = request.query_params.get('status')
        qs = TranslationRequest.objects.select_related('assigned_to').all()
        if status_filter:
            qs = qs.filter(status=status_filter)
        serializer = TranslationRequestSerializer(qs, many=True)
        return Response(serializer.data)

    serializer = TranslationRequestSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET', 'PUT'])
@permission_classes([IsAdminUser])
def translation_queue_detail(request, pk):
    """Get or update a specific translation request."""
    tr = get_object_or_404(TranslationRequest, pk=pk)
    if request.method == 'GET':
        return Response(TranslationRequestSerializer(tr).data)

    old_status = tr.status
    serializer = TranslationRequestSerializer(tr, data=request.data, partial=True)
    if serializer.is_valid():
        # Auto-set completed_at when status changes to completed
        if request.data.get('status') == 'completed' and old_status != 'completed':
            serializer.save(completed_at=timezone.now())
        else:
            serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
