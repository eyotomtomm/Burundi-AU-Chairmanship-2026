from django.contrib.auth.models import User
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .models import (
    HeroSlide, MagazineEdition, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard,
)
from .serializers import (
    HeroSlideSerializer, MagazineEditionSerializer, ArticleSerializer,
    EmbassyLocationSerializer, EventSerializer, LiveFeedSerializer,
    ResourceSerializer, EmergencyContactSerializer, AppSettingsSerializer,
    FeatureCardSerializer, RegisterSerializer, UserSerializer,
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
    user_email = user.email

    # Delete user (Django will cascade delete related data)
    user.delete()

    return Response({
        'message': f'Account {user_email} has been permanently deleted.',
        'detail': 'Your account and all associated data have been removed.'
    }, status=status.HTTP_200_OK)


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
    queryset = HeroSlide.objects.filter(is_active=True)
    serializer_class = HeroSlideSerializer
    pagination_class = None


class MagazineEditionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = MagazineEdition.objects.all()
    serializer_class = MagazineEditionSerializer


class ArticleViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Article.objects.all()
    serializer_class = ArticleSerializer
    filterset_fields = ['category', 'is_featured']


class EmbassyLocationViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EmbassyLocation.objects.all()
    serializer_class = EmbassyLocationSerializer
    filterset_fields = ['type', 'country']


class EventViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Event.objects.all()
    serializer_class = EventSerializer


class LiveFeedViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = LiveFeed.objects.all()
    serializer_class = LiveFeedSerializer
    filterset_fields = ['status']


class ResourceViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Resource.objects.all()
    serializer_class = ResourceSerializer
    filterset_fields = ['category', 'file_type']


class EmergencyContactViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = EmergencyContactSerializer
    pagination_class = None


class FeatureCardViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = FeatureCard.objects.filter(is_active=True)
    serializer_class = FeatureCardSerializer
    pagination_class = None


@api_view(['GET'])
def app_settings(request):
    settings = AppSettings.objects.first()
    if settings:
        serializer = AppSettingsSerializer(settings)
        return Response(serializer.data)
    return Response({})


@api_view(['GET'])
def home_feed(request):
    """Combined endpoint for home screen — hero slides, featured articles, feature cards, and settings."""
    hero_slides = HeroSlide.objects.filter(is_active=True)
    featured_articles = Article.objects.filter(is_featured=True)[:5]
    articles = Article.objects.all()[:10]
    feature_cards = FeatureCard.objects.filter(is_active=True)
    settings = AppSettings.objects.first()

    data = {
        'hero_slides': HeroSlideSerializer(hero_slides, many=True, context={'request': request}).data,
        'featured_articles': ArticleSerializer(featured_articles, many=True, context={'request': request}).data,
        'articles': ArticleSerializer(articles, many=True, context={'request': request}).data,
        'feature_cards': FeatureCardSerializer(feature_cards, many=True, context={'request': request}).data,
        'settings': AppSettingsSerializer(settings).data if settings else {},
    }
    return Response(data)
