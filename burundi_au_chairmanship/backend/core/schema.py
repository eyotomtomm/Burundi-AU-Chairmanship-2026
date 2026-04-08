import graphene
from graphene_django import DjangoObjectType
from django.utils import timezone
from django.db.models import Q

from .models import (
    Article, Category, Event, LiveFeed,
    GalleryAlbum, GalleryPhoto, Notification,
)


# ─── GraphQL Types ────────────────────────────────────────────

class CategoryType(DjangoObjectType):
    class Meta:
        model = Category
        fields = ('id', 'name', 'name_fr', 'color', 'order')


class ArticleType(DjangoObjectType):
    category = graphene.Field(CategoryType)

    class Meta:
        model = Article
        fields = (
            'id', 'title', 'title_fr', 'content', 'content_fr',
            'image', 'author', 'category', 'publish_date',
            'is_featured', 'view_count', 'like_count', 'created_at',
        )


class EventType(DjangoObjectType):
    class Meta:
        model = Event
        fields = (
            'id', 'name', 'name_fr', 'description', 'description_fr',
            'address', 'latitude', 'longitude', 'event_date',
            'image', 'is_active', 'created_at',
        )


class LiveFeedType(DjangoObjectType):
    class Meta:
        model = LiveFeed
        fields = (
            'id', 'title', 'title_fr', 'description', 'description_fr',
            'stream_url', 'stream_type', 'meeting_id', 'passcode',
            'thumbnail', 'status', 'viewer_count', 'duration',
            'scheduled_time', 'created_at',
        )


class GalleryPhotoType(DjangoObjectType):
    class Meta:
        model = GalleryPhoto
        fields = (
            'id', 'image', 'caption', 'caption_fr',
            'photographer', 'taken_date', 'order',
        )


class GalleryAlbumType(DjangoObjectType):
    photos = graphene.List(GalleryPhotoType)

    class Meta:
        model = GalleryAlbum
        fields = (
            'id', 'title', 'title_fr', 'description', 'description_fr',
            'cover_image', 'photo_count', 'view_count', 'like_count',
            'created_at', 'is_featured', 'display_order',
        )

    def resolve_photos(self, info):
        return self.photos.all()


class NotificationType(DjangoObjectType):
    is_read = graphene.Boolean()

    class Meta:
        model = Notification
        fields = (
            'id', 'title', 'title_fr', 'message', 'message_fr',
            'notification_type', 'action_type', 'action_value',
            'image', 'is_active', 'created_at',
        )

    def resolve_is_read(self, info):
        user = info.context.user
        if user.is_authenticated:
            return self.read_by.filter(pk=user.pk).exists()
        return False


# ─── Queries ──────────────────────────────────────────────────

class Query(graphene.ObjectType):
    # Articles
    all_articles = graphene.List(
        ArticleType,
        category=graphene.Int(description="Filter by category ID"),
        author=graphene.String(description="Filter by author name (case-insensitive contains)"),
        search=graphene.String(description="Search in title and content"),
        featured_only=graphene.Boolean(description="Only return featured articles"),
        limit=graphene.Int(description="Limit the number of results"),
    )
    article = graphene.Field(
        ArticleType,
        id=graphene.Int(required=True),
    )

    # Events
    all_events = graphene.List(
        EventType,
        upcoming_only=graphene.Boolean(description="Only return upcoming events"),
        limit=graphene.Int(description="Limit the number of results"),
    )
    event = graphene.Field(
        EventType,
        id=graphene.Int(required=True),
    )

    # Live Feeds
    all_live_feeds = graphene.List(
        LiveFeedType,
        active_only=graphene.Boolean(description="Only return live and upcoming feeds"),
        status=graphene.String(description="Filter by status: live, upcoming, recorded"),
        limit=graphene.Int(description="Limit the number of results"),
    )

    # Gallery
    all_gallery_albums = graphene.List(
        GalleryAlbumType,
        featured_only=graphene.Boolean(description="Only return featured albums"),
        limit=graphene.Int(description="Limit the number of results"),
    )

    # Notifications (auth required)
    notifications = graphene.List(
        NotificationType,
        unread_only=graphene.Boolean(description="Only return unread notifications"),
        limit=graphene.Int(description="Limit the number of results"),
    )

    # ─── Resolvers ────────────────────────────────────────────

    def resolve_all_articles(self, info, category=None, author=None, search=None,
                             featured_only=None, limit=None):
        qs = Article.objects.select_related('category').all()

        if category is not None:
            qs = qs.filter(category_id=category)
        if author:
            qs = qs.filter(author__icontains=author)
        if search:
            qs = qs.filter(
                Q(title__icontains=search) |
                Q(title_fr__icontains=search) |
                Q(content__icontains=search) |
                Q(content_fr__icontains=search)
            )
        if featured_only:
            qs = qs.filter(is_featured=True)
        if limit is not None:
            qs = qs[:limit]

        return qs

    def resolve_article(self, info, id):
        try:
            return Article.objects.select_related('category').get(pk=id)
        except Article.DoesNotExist:
            return None

    def resolve_all_events(self, info, upcoming_only=None, limit=None):
        qs = Event.objects.filter(is_active=True)

        if upcoming_only:
            qs = qs.filter(event_date__gte=timezone.now())

        if limit is not None:
            qs = qs[:limit]

        return qs

    def resolve_event(self, info, id):
        try:
            return Event.objects.get(pk=id)
        except Event.DoesNotExist:
            return None

    def resolve_all_live_feeds(self, info, active_only=None, status=None, limit=None):
        qs = LiveFeed.objects.all()

        if active_only:
            qs = qs.filter(status__in=['live', 'upcoming'])
        if status:
            qs = qs.filter(status=status)
        if limit is not None:
            qs = qs[:limit]

        return qs

    def resolve_all_gallery_albums(self, info, featured_only=None, limit=None):
        qs = GalleryAlbum.objects.all()

        if featured_only:
            qs = qs.filter(is_featured=True)
        if limit is not None:
            qs = qs[:limit]

        return qs

    def resolve_notifications(self, info, unread_only=None, limit=None):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required to view notifications.")

        qs = Notification.objects.filter(is_active=True)

        # Filter to notifications targeted at this user
        qs = qs.filter(
            Q(is_global=True) | Q(target_users=user)
        ).distinct()

        if unread_only:
            qs = qs.exclude(read_by=user)
        if limit is not None:
            qs = qs[:limit]

        return qs


schema = graphene.Schema(query=Query)
