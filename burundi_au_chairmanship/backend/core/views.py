import logging
from django.contrib.auth.models import User
from django.db.models import Count, Exists, OuterRef, F, Q
from django.utils import timezone
from rest_framework import viewsets, status, mixins
from rest_framework.decorators import api_view, permission_classes, action, throttle_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from config.firebase import verify_firebase_token
from .throttling import ViewCountThrottle, LikeToggleThrottle, AuthRateThrottle, OTPRateThrottle

logger = logging.getLogger(__name__)
from .models import (
    HeroSlide, MagazineEdition, MagazineLike, Article, EmbassyLocation,
    Event, LiveFeed, Resource, AppSettings,
    FeatureCard, ArticleComment, ArticleLike, Category, UserProfile,
    PriorityAgenda, GalleryAlbum, GalleryPhoto, Video, SocialMediaLink,
    Notification, HeroTextContent, QuickAccessMenuItem, VerificationRequest,
    WeatherCity, EventRegistration, RegistrationFormField, EventSubmission,
    SupportTicket, TicketMessage,
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
)


# ── Auth Views ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([AuthRateThrottle])
def register(request):
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

        # Check if user already exists
        if User.objects.filter(username=firebase_uid).exists():
            return Response(
                {'detail': 'User already registered'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create Django user with Firebase UID as username
        user = User.objects.create(
            username=firebase_uid,
            email=email,
            first_name=name,
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

        # Find or create user by Firebase UID
        try:
            profile = UserProfile.objects.select_related('user').get(firebase_uid=firebase_uid)
            user = profile.user
            is_new_user = False
        except UserProfile.DoesNotExist:
            # Auto-create user if they don't exist (standard for social logins)
            user = User.objects.create(
                username=firebase_uid,
                email=email,
                first_name=name,
            )
            profile = user.profile
            profile.firebase_uid = firebase_uid
            is_new_user = True

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
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    """
    Update user's FCM token for push notifications.
    """
    fcm_token = request.data.get('fcm_token')

    if not fcm_token:
        return Response(
            {'detail': 'FCM token is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        profile = request.user.profile
        profile.fcm_token = fcm_token
        profile.save()

        return Response({
            'message': 'FCM token updated successfully'
        })

    except Exception as e:
        logger.exception('Failed to update FCM token')
        return Response(
            {'detail': 'Failed to update notification settings. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


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
            'export_date': user.date_joined.now().isoformat(),
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
        qs = MagazineEdition.objects.all()
        user = self.request.user
        if user.is_authenticated:
            qs = qs.annotate(
                is_liked=Exists(MagazineLike.objects.filter(user=user, edition=OuterRef('pk')))
            )
        return qs

    @action(detail=True, methods=['post'], permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle])
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

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated], throttle_classes=[LikeToggleThrottle])
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
        qs = Article.objects.select_related('category').prefetch_related('media').annotate(
            comment_count=Count('comments', distinct=True),
            like_count=Count('likes', distinct=True),
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
        return Response({
            'is_liked': created,
            'like_count': article.likes.count(),
        })


class EmbassyLocationViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view embassy locations"""
    permission_classes = [AllowAny]
    queryset = EmbassyLocation.objects.all()
    serializer_class = EmbassyLocationSerializer
    filterset_fields = ['type', 'country']


class EventViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view active events"""
    permission_classes = [AllowAny]
    queryset = Event.objects.filter(is_active=True)
    serializer_class = EventSerializer


class LiveFeedViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view live feeds"""
    permission_classes = [AllowAny]
    queryset = LiveFeed.objects.all().order_by('-created_at')  # Show newest first
    serializer_class = LiveFeedSerializer
    filterset_fields = ['status']


class ResourceViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view resources"""
    permission_classes = [AllowAny]
    queryset = Resource.objects.all()
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
    """Public endpoint: Anyone can view gallery albums"""
    permission_classes = [AllowAny]
    queryset = GalleryAlbum.objects.prefetch_related('photos').all()
    serializer_class = GalleryAlbumSerializer


class VideoViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view videos"""
    permission_classes = [AllowAny]
    queryset = Video.objects.all().order_by('-is_featured', '-publish_date')  # Featured first, then newest
    serializer_class = VideoSerializer
    filterset_fields = ['category', 'is_featured']

    @action(detail=True, methods=['post'], url_path='record-view', permission_classes=[AllowAny], throttle_classes=[ViewCountThrottle])
    def record_view(self, request, pk=None):
        """
        Record a view for this video.

        Throttled to 1 view per content per minute per user/IP
        to prevent view count manipulation.
        """
        Video.objects.filter(pk=pk).update(view_count=F('view_count') + 1)
        video = self.get_object()
        return Response({'view_count': video.view_count})


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
            ).distinct()
        else:
            # Show only global notifications for anonymous users
            qs = qs.filter(is_global=True)

        return qs

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
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

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
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
    Health check endpoint for load balancers and monitoring.

    Returns 200 OK if the service is healthy.
    """
    from django.db import connection

    # Check database connection
    try:
        connection.ensure_connection()
        db_status = 'healthy'
    except Exception:
        db_status = 'unhealthy'

    return Response({
        'status': 'healthy' if db_status == 'healthy' else 'degraded',
        'database': db_status,
        'timestamp': timezone.now().isoformat(),
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def home_feed(request):
    """Combined endpoint for home screen — hero slides, featured articles, feature cards, categories, event cards, and settings."""
    hero_slides = HeroSlide.objects.filter(is_active=True)

    base_articles = Article.objects.select_related('category').prefetch_related('media').annotate(
        comment_count=Count('comments', distinct=True),
        like_count=Count('likes', distinct=True),
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

    # Standalone event cards
    event_cards = EventRegistration.objects.filter(
        is_active=True
    ).prefetch_related('form_fields')

    data = {
        'hero_slides': HeroSlideSerializer(hero_slides, many=True, context={'request': request}).data,
        'featured_articles': ArticleSerializer(featured_articles, many=True, context={'request': request}).data,
        'articles': ArticleSerializer(articles, many=True, context={'request': request}).data,
        'feature_cards': FeatureCardSerializer(feature_cards, many=True, context={'request': request}).data,
        'event_cards': EventRegistrationSerializer(event_cards, many=True, context={'request': request}).data,
        'categories': CategorySerializer(categories, many=True).data,
        'settings': AppSettingsSerializer(settings).data if settings else {},
    }
    return Response(data)


# ── Search Endpoints ────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([AllowAny])
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
        like_count=Count('likes', distinct=True),
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
        'is_verified': is_verified,
        'badge_type': badge_type,
        'has_verification_request': latest_request is not None,
        'status': latest_request.status if latest_request else None,
        'rejection_reason': latest_request.rejection_reason if latest_request else None,
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
        ).prefetch_related('form_fields')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class EventSubmissionViewSet(mixins.CreateModelMixin, mixins.ListModelMixin,
                             mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """User submissions for event registrations (create/list/retrieve only)"""
    permission_classes = [IsAuthenticated]
    serializer_class = EventSubmissionSerializer

    def get_queryset(self):
        # Users can only see their own submissions
        return EventSubmission.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        event_reg = serializer.validated_data['event_registration']
        user = self.request.user
        # Enforce one self-registration per user per event
        if not serializer.validated_data.get('is_proxy', False):
            if EventSubmission.objects.filter(event_registration=event_reg, user=user, is_proxy=False).exists():
                from rest_framework.exceptions import ValidationError
                raise ValidationError({'detail': 'You have already registered for this event.'})
        serializer.save(user=user)

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
    """Send OTP to user's email for verification"""
    from .otp_utils import send_email_otp

    email = request.data.get('email')
    if not email:
        return Response(
            {'detail': 'Email is required'},
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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPRateThrottle])
def send_phone_otp(request):
    """Send OTP to user's phone via Twilio SMS or WhatsApp"""
    from .otp_utils import send_phone_otp_twilio

    country_code = request.data.get('country_code')
    phone_number = request.data.get('phone_number')
    channel = request.data.get('channel', 'sms')  # 'sms' or 'whatsapp'

    if not country_code or not phone_number:
        return Response(
            {'detail': 'Country code and phone number are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    success, message, otp_id = send_phone_otp_twilio(
        request.user,
        country_code,
        phone_number,
        channel=channel
    )

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
def verify_phone_otp(request):
    """Verify phone OTP code"""
    from .otp_utils import verify_phone_otp

    country_code = request.data.get('country_code')
    phone_number = request.data.get('phone_number')
    otp_code = request.data.get('otp_code')

    if not country_code or not phone_number or not otp_code:
        return Response(
            {'detail': 'Country code, phone number, and OTP code are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    success, message = verify_phone_otp(
        request.user,
        country_code,
        phone_number,
        otp_code
    )

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
    http_method_names = ['get', 'post']

    def get_serializer_class(self):
        if self.action == 'list':
            return SupportTicketListSerializer
        return SupportTicketDetailSerializer

    def get_queryset(self):
        return SupportTicket.objects.filter(
            user=self.request.user
        ).prefetch_related('messages')

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

        # Reopen ticket if it was resolved/closed
        if ticket.status in ('resolved', 'closed'):
            ticket.status = 'open'
            ticket.save(update_fields=['status'])

        serializer = SupportTicketDetailSerializer(ticket)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
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
