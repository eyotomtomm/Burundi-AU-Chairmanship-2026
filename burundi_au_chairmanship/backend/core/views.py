from django.contrib.auth.models import User
from django.db.models import Count, Exists, OuterRef, F, Q
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes, action, throttle_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from config.firebase import verify_firebase_token
from .throttling import ViewCountThrottle, LikeToggleThrottle
from .models import (
    HeroSlide, MagazineEdition, MagazineLike, Article, EmbassyLocation,
    Event, LiveFeed, Resource, AppSettings,
    FeatureCard, ArticleComment, ArticleLike, Category, UserProfile,
    PriorityAgenda, GalleryAlbum, GalleryPhoto, Video, SocialMediaLink,
    Notification, HeroTextContent, QuickAccessMenuItem,
)
from .serializers import (
    HeroSlideSerializer, MagazineEditionSerializer, ArticleSerializer,
    EmbassyLocationSerializer, EventSerializer, LiveFeedSerializer,
    ResourceSerializer, AppSettingsSerializer,
    FeatureCardSerializer, RegisterSerializer, UserSerializer,
    ArticleCommentSerializer, CategorySerializer, PriorityAgendaSerializer,
    GalleryAlbumSerializer, VideoSerializer, SocialMediaLinkSerializer,
    NotificationSerializer, HeroTextContentSerializer, QuickAccessMenuItemSerializer,
)


# ── Auth Views ────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
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

    refresh = RefreshToken.for_user(user)
    return Response({
        'user': UserSerializer(user).data,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    return Response(UserSerializer(request.user).data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    serializer = UserSerializer(request.user, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    """
    Permanently delete user account and all related data.
    Required for Apple App Store compliance (Guideline 5.1.1)
    """
    user = request.user

    # Delete user (Django will cascade delete related data)
    user.delete()

    # Security: Don't leak email in response
    return Response({
        'message': 'Your account has been permanently deleted.',
        'detail': 'All associated data has been removed.'
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
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
            'user': UserSerializer(user).data,
            'message': 'User registered successfully'
        }, status=status.HTTP_201_CREATED)

    except ValueError as e:
        return Response(
            {'detail': str(e)},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except Exception as e:
        return Response(
            {'detail': f'Registration failed: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
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

        # Update email verification status from Firebase
        profile.is_email_verified = decoded_token.get('email_verified', False)
        profile.save()

        return Response({
            'user': UserSerializer(user).data,
            'message': 'Login successful',
            'is_new_user': is_new_user
        })

    except ValueError as e:
        return Response(
            {'detail': str(e)},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except Exception as e:
        return Response(
            {'detail': f'Login failed: {str(e)}'},
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
        return Response(
            {'detail': f'Failed to update FCM token: {str(e)}'},
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
        )
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

        # Basic HTML sanitization (remove tags)
        import re
        content = re.sub(r'<[^>]+>', '', content)  # Strip HTML tags
        content = content.replace('<', '&lt;').replace('>', '&gt;')  # Escape remaining brackets

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
    """Public endpoint: Anyone can view events"""
    permission_classes = [AllowAny]
    queryset = Event.objects.all()
    serializer_class = EventSerializer


class LiveFeedViewSet(viewsets.ReadOnlyModelViewSet):
    """Public endpoint: Anyone can view live feeds"""
    permission_classes = [AllowAny]
    queryset = LiveFeed.objects.all()
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
    queryset = FeatureCard.objects.filter(is_active=True)
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
    queryset = Video.objects.all()
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
    """Combined endpoint for home screen — hero slides, featured articles, feature cards, categories, and settings."""
    hero_slides = HeroSlide.objects.filter(is_active=True)

    base_articles = Article.objects.select_related('category').prefetch_related('media').annotate(
        comment_count=Count('comments', distinct=True),
        like_count=Count('likes', distinct=True),
    )
    if request.user.is_authenticated:
        base_articles = base_articles.annotate(
            is_liked=Exists(ArticleLike.objects.filter(article=OuterRef('pk'), user=request.user)),
        )
    else:
        from django.db.models import Value, BooleanField
        base_articles = base_articles.annotate(is_liked=Value(False, output_field=BooleanField()))

    featured_articles = base_articles.filter(is_featured=True)[:5]
    articles = base_articles.all()[:10]
    feature_cards = FeatureCard.objects.filter(is_active=True)
    categories = Category.objects.all()
    settings = AppSettings.objects.first()

    data = {
        'hero_slides': HeroSlideSerializer(hero_slides, many=True, context={'request': request}).data,
        'featured_articles': ArticleSerializer(featured_articles, many=True, context={'request': request}).data,
        'articles': ArticleSerializer(articles, many=True, context={'request': request}).data,
        'feature_cards': FeatureCardSerializer(feature_cards, many=True, context={'request': request}).data,
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
