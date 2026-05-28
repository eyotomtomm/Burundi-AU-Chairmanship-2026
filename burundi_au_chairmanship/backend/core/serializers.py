from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import (
    MagazineLike, ArticleLike, GalleryAlbumLike, VideoLike,
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, Notification, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, HeroTextContent, QuickAccessMenuItem,
    VerificationRequest, VerificationSocialMedia, WeatherCity, EventCategory, EventRegistration, RegistrationFormField,
    EventSubmission, FeatureCardKeyPoint, FeatureCardImpactArea, FeatureCardMedia,
    SupportTicket, TicketMessage, Popup,
    # New models
    LoginHistory, ActiveSession, PasswordChangeHistory, Bookmark, Reaction,
    ReadingProgress, ContentSchedule, ArticleDraft, ContentVersion, ArticleSeries,
    TrendingContent, EventReminder, EventWaitlist, EventSpeaker, EventFeedback,
    EventCheckIn, EventPhoto, Conversation, DirectMessage, Discussion, DiscussionReply,
    Poll, PollOption, PollVote, NotificationPreference, AnnouncementBanner,
    ContactDirectory, LiveQASession, LiveQAQuestion, UserPreference, OnboardingStep,
    EmailTemplate, Webhook, ScheduledMaintenance, ABTest,
    ContentAnalytics, EngagementHeatmap, WeeklyReport, TranslationEntry, AppRelease,
    AuditLogEntry, AccountMergeRequest, FunnelStep,
    VideoChapter, VideoSubtitle, ArticleRevision, TranslationRequest,
    EventComment, CommentMention, NewsletterEdition,
    EventAgendaItem, LinkedAccount,
    # Engagement models
    EventLike, DiscussionLike, VideoComment, GalleryComment, AppOpenEvent,
)


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    name = serializers.CharField(source='first_name')

    class Meta:
        model = User
        fields = ['name', 'email', 'password']

    def validate_email(self, value):
        from .validators import validate_non_disposable_email
        validate_non_disposable_email(value)
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('Unable to register with this email address.')
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
        )
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['phone_number', 'gender', 'nationality', 'date_of_birth', 'profile_picture', 'is_email_verified',
                  'is_government_official', 'is_verified', 'badge_type', 'verification_requested_at',
                  'email_verified_at', 'government_verified_at', 'verified_at', 'receives_newsletter']
        read_only_fields = ['is_email_verified', 'is_government_official', 'is_verified', 'badge_type',
                            'email_verified_at', 'government_verified_at', 'verified_at',
                            'verification_requested_at']


class UserSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()
    profile = UserProfileSerializer(required=False)

    # Computed fields for easy access
    phone_number = serializers.CharField(source='profile.phone_number', required=False, allow_blank=True)
    gender = serializers.CharField(source='profile.gender', required=False, allow_blank=True)
    nationality = serializers.CharField(source='profile.nationality', required=False, allow_blank=True)
    date_of_birth = serializers.DateField(source='profile.date_of_birth', required=False, allow_null=True)
    profile_picture = serializers.ImageField(source='profile.profile_picture', required=False, allow_null=True)
    is_email_verified = serializers.BooleanField(source='profile.is_email_verified', read_only=True)
    is_government_official = serializers.BooleanField(source='profile.is_government_official', read_only=True)
    is_verified = serializers.BooleanField(source='profile.is_verified', read_only=True)
    badge_type = serializers.CharField(source='profile.badge_type', read_only=True, allow_null=True)

    class Meta:
        model = User
        fields = ['id', 'name', 'email', 'profile', 'phone_number', 'gender', 'nationality', 'date_of_birth',
                  'profile_picture', 'is_email_verified', 'is_government_official', 'is_verified', 'badge_type']
        read_only_fields = ['id', 'email', 'is_email_verified', 'is_government_official', 'is_verified', 'badge_type']

    def get_name(self, obj):
        """Return full name from first_name + last_name, falling back to a safe handle.
        Never exposes the raw username (which is the user's email in this app)."""
        from .utils import user_handle
        full = f'{obj.first_name} {obj.last_name}'.strip()
        return full or user_handle(obj)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # Ensure profile_picture is a full URL
        if hasattr(instance, 'profile') and instance.profile.profile_picture:
            request = self.context.get('request')
            if request:
                ret['profile_picture'] = request.build_absolute_uri(instance.profile.profile_picture.url)
            else:
                ret['profile_picture'] = instance.profile.profile_picture.url
        else:
            ret['profile_picture'] = None

        # Ensure badge_type is set when user is verified
        if hasattr(instance, 'profile') and instance.profile.is_verified and not ret.get('badge_type'):
            ret['badge_type'] = instance.profile.badge_type or 'BLUE'

        # Include verification title/role from approved request
        ret['verification_title'] = None
        ret['verification_role'] = None
        ret['verification_name'] = None
        approved = instance.verification_requests.filter(status='approved').order_by('-created_at').first()
        if approved:
            ret['verification_title'] = approved.get_title_display()
            ret['verification_role'] = approved.position_role
            ret['verification_name'] = approved.full_name
        return ret

    def update(self, instance, validated_data):
        # Update user name fields
        if 'first_name' in validated_data:
            name = validated_data['first_name']
            parts = name.strip().split(None, 1) if name else ['']
            instance.first_name = parts[0][:150]
            instance.last_name = parts[1][:150] if len(parts) > 1 else ''
        instance.save()

        # Update profile fields if provided
        profile_data = {}
        if 'profile' in validated_data:
            profile_fields = validated_data['profile']
            profile_data.update(profile_fields)

        # Handle direct profile field updates
        if 'phone_number' in validated_data:
            profile_data['phone_number'] = validated_data['phone_number']
        if 'gender' in validated_data:
            profile_data['gender'] = validated_data['gender']
        if 'nationality' in validated_data:
            profile_data['nationality'] = validated_data['nationality']
        if 'date_of_birth' in validated_data:
            profile_data['date_of_birth'] = validated_data['date_of_birth']
        if 'profile_picture' in validated_data:
            profile_data['profile_picture'] = validated_data['profile_picture']

        if profile_data:
            profile = instance.profile
            for key, value in profile_data.items():
                setattr(profile, key, value)
            profile.save()

        return instance


class HeroSlideSerializer(serializers.ModelSerializer):
    thumbnail_url = serializers.CharField(read_only=True)
    medium_url = serializers.CharField(read_only=True)

    class Meta:
        model = HeroSlide
        fields = ['id', 'image', 'thumbnail_url', 'medium_url', 'label', 'label_fr', 'order']


class MagazineImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = MagazineImage
        fields = ['id', 'image', 'caption', 'caption_fr', 'order']


def get_recent_likers(like_model, content_field, obj, request):
    """Return the 3 most recent likers with profile info."""
    likes = like_model.objects.filter(
        **{content_field: obj}
    ).select_related('user', 'user__profile').order_by('-created_at')[:3]
    result = []
    for like in likes:
        user = like.user
        pic = None
        if hasattr(user, 'profile') and user.profile.profile_picture:
            if request:
                pic = request.build_absolute_uri(user.profile.profile_picture.url)
            else:
                pic = user.profile.profile_picture.url
        from .utils import user_handle
        result.append({
            'user_id': user.id,
            'name': f'{user.first_name} {user.last_name}'.strip() or user_handle(user),
            'profile_picture': pic,
        })
    return result


class MagazineEditionSerializer(serializers.ModelSerializer):
    effective_pdf_url = serializers.SerializerMethodField()
    images = MagazineImageSerializer(many=True, read_only=True)
    is_liked = serializers.BooleanField(read_only=True, default=False)
    recent_likers = serializers.SerializerMethodField()

    class Meta:
        model = MagazineEdition
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'pdf_file', 'external_url', 'effective_pdf_url',
                  'publish_date', 'is_featured', 'view_count', 'like_count',
                  'page_count', 'file_size', 'images', 'is_liked', 'recent_likers']

    def get_effective_pdf_url(self, obj):
        if obj.pdf_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.pdf_file.url)
            return obj.pdf_file.url
        return obj.external_url or ''

    def get_recent_likers(self, obj):
        request = self.context.get('request')
        return get_recent_likers(MagazineLike, 'edition', obj, request)


class MagazineCommentSerializer(serializers.ModelSerializer):
    """Serializer for magazine comments with nested replies."""
    user_name = serializers.SerializerMethodField()
    username = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()
    reply_count = serializers.SerializerMethodField()

    class Meta:
        from .models import MagazineComment
        model = MagazineComment
        fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                  'parent', 'content', 'created_at', 'replies', 'reply_count']
        read_only_fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture',
                            'badge_type', 'created_at', 'replies', 'reply_count']

    def get_user_name(self, obj):
        from .utils import user_handle
        return obj.user.get_full_name().strip() or user_handle(obj.user)

    def get_username(self, obj):
        from .utils import user_handle
        return user_handle(obj.user)

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None

    def get_badge_type(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.is_verified:
            return obj.user.profile.badge_type
        return None

    def get_replies(self, obj):
        if obj.parent_id is not None:
            return []
        replies = obj.replies.select_related('user', 'user__profile').order_by('created_at')
        return MagazineCommentSerializer(replies, many=True, context=self.context).data

    def get_reply_count(self, obj):
        if obj.parent_id is not None:
            return 0
        return obj.replies.count()


class VideoCommentSerializer(serializers.ModelSerializer):
    """Serializer for video comments with nested replies."""
    user_name = serializers.SerializerMethodField()
    username = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()
    reply_count = serializers.SerializerMethodField()

    class Meta:
        model = VideoComment
        fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                  'parent', 'content', 'created_at', 'replies', 'reply_count']
        read_only_fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture',
                            'badge_type', 'created_at', 'replies', 'reply_count']

    def get_user_name(self, obj):
        from .utils import user_handle
        return obj.user.get_full_name().strip() or user_handle(obj.user)

    def get_username(self, obj):
        from .utils import user_handle
        return user_handle(obj.user)

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None

    def get_badge_type(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.is_verified:
            return obj.user.profile.badge_type
        return None

    def get_replies(self, obj):
        if obj.parent_id is not None:
            return []
        replies = obj.replies.select_related('user', 'user__profile').order_by('created_at')
        return VideoCommentSerializer(replies, many=True, context=self.context).data

    def get_reply_count(self, obj):
        if obj.parent_id is not None:
            return 0
        return obj.replies.count()


class GalleryCommentSerializer(serializers.ModelSerializer):
    """Serializer for gallery album comments with nested replies."""
    user_name = serializers.SerializerMethodField()
    username = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()
    reply_count = serializers.SerializerMethodField()

    class Meta:
        model = GalleryComment
        fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                  'parent', 'content', 'created_at', 'replies', 'reply_count']
        read_only_fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture',
                            'badge_type', 'created_at', 'replies', 'reply_count']

    def get_user_name(self, obj):
        from .utils import user_handle
        return obj.user.get_full_name().strip() or user_handle(obj.user)

    def get_username(self, obj):
        from .utils import user_handle
        return user_handle(obj.user)

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None

    def get_badge_type(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.is_verified:
            return obj.user.profile.badge_type
        return None

    def get_replies(self, obj):
        if obj.parent_id is not None:
            return []
        replies = obj.replies.select_related('user', 'user__profile').order_by('created_at')
        return GalleryCommentSerializer(replies, many=True, context=self.context).data

    def get_reply_count(self, obj):
        if obj.parent_id is not None:
            return 0
        return obj.replies.count()


class ArticleCommentSerializer(serializers.ModelSerializer):
    """Serializer for article comments with nested replies, @mentions, and username handle."""
    user_name = serializers.SerializerMethodField()
    username = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()
    reply_count = serializers.SerializerMethodField()

    class Meta:
        model = ArticleComment
        fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                  'parent', 'content', 'created_at', 'replies', 'reply_count']
        read_only_fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture',
                            'badge_type', 'created_at', 'replies', 'reply_count']

    def get_user_name(self, obj):
        # Never fall back to the raw username (which IS the user's email in this app).
        from .utils import user_handle
        return obj.user.get_full_name().strip() or user_handle(obj.user)

    def get_username(self, obj):
        from .utils import user_handle
        return user_handle(obj.user)

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None

    def get_badge_type(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.is_verified:
            return obj.user.profile.badge_type
        return None

    def get_replies(self, obj):
        # Only nest replies under top-level comments
        if obj.parent_id is not None:
            return []
        replies = obj.replies.select_related('user', 'user__profile').order_by('created_at')
        return ArticleCommentSerializer(replies, many=True, context=self.context).data

    def get_reply_count(self, obj):
        if obj.parent_id is not None:
            return 0
        return obj.replies.count()


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'name_fr', 'color', 'order']


class ArticleMediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = ArticleMedia
        fields = ['id', 'media_type', 'image', 'video_url', 'caption', 'caption_fr', 'order']


class ArticleSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    media = ArticleMediaSerializer(many=True, read_only=True)
    comment_count = serializers.IntegerField(read_only=True, default=0)
    like_count = serializers.IntegerField(read_only=True, default=0)
    is_liked = serializers.BooleanField(read_only=True, default=False)
    thumbnail_url = serializers.CharField(read_only=True)
    medium_url = serializers.CharField(read_only=True)
    recent_likers = serializers.SerializerMethodField()

    class Meta:
        model = Article
        fields = ['id', 'title', 'title_fr', 'content', 'content_fr',
                  'image', 'thumbnail_url', 'medium_url',
                  'author', 'category', 'publish_date', 'is_featured',
                  'view_count', 'comment_count', 'like_count', 'is_liked', 'media',
                  'recent_likers']

    def get_recent_likers(self, obj):
        request = self.context.get('request')
        return get_recent_likers(ArticleLike, 'article', obj, request)


class EmbassyLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmbassyLocation
        fields = ['id', 'name', 'name_fr', 'address', 'city', 'country',
                  'latitude', 'longitude', 'phone_number', 'email', 'website',
                  'opening_hours', 'type', 'image']


class EventSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = ['id', 'name', 'name_fr', 'description', 'description_fr',
                  'address', 'latitude', 'longitude', 'event_date', 'image',
                  'recurrence_type', 'recurrence_end_date']


class LiveFeedSerializer(serializers.ModelSerializer):
    event_name = serializers.CharField(source='event.name', read_only=True, default=None)
    event_date = serializers.DateTimeField(source='event.event_date', read_only=True, default=None)
    speakers = serializers.SerializerMethodField()

    class Meta:
        model = LiveFeed
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'event', 'event_name', 'event_date', 'speakers',
                  'stream_url', 'stream_type',
                  'meeting_id', 'passcode', 'thumbnail', 'status',
                  'viewer_count', 'duration', 'scheduled_time']

    def get_speakers(self, obj):
        if not obj.event_id:
            return []
        qs = obj.event.event_speakers.filter(is_active=True).order_by('order', 'name')
        return EventSpeakerSerializer(qs, many=True, context=self.context).data


class ResourceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resource
        fields = ['id', 'title', 'title_fr', 'category', 'file',
                  'file_size', 'file_type']


class FeatureCardKeyPointSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeatureCardKeyPoint
        fields = ['id', 'text', 'text_fr', 'order']


class FeatureCardImpactAreaSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeatureCardImpactArea
        fields = ['id', 'icon_name', 'title', 'title_fr', 'description', 'description_fr', 'order']


class FeatureCardMediaSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()

    class Meta:
        model = FeatureCardMedia
        fields = ['id', 'media_type', 'image', 'video_url', 'caption', 'caption_fr', 'order']

    def get_image(self, obj):
        """Return uploaded image URL or external image URL."""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return obj.image_url or None

    def get_video_url(self, obj):
        """Return uploaded video file URL or external video URL."""
        if obj.video_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.video_file.url)
            return obj.video_file.url
        return obj.video_url or None


class FeatureCardSerializer(serializers.ModelSerializer):
    key_points = serializers.SerializerMethodField()
    key_points_fr = serializers.SerializerMethodField()
    impact_areas = serializers.SerializerMethodField()
    impact_areas_fr = serializers.SerializerMethodField()
    media = FeatureCardMediaSerializer(many=True, read_only=True)

    class Meta:
        model = FeatureCard
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'image', 'gradient_start', 'gradient_end', 'icon_name', 'icon_image',
                  'action_type', 'action_value', 'order',
                  'overview', 'overview_fr', 'key_points', 'key_points_fr',
                  'impact_areas', 'impact_areas_fr', 'extra_content', 'extra_content_fr',
                  'media']

    def get_key_points(self, obj):
        """Return list of strings — from child model rows, fallback to JSON field."""
        items = obj.key_point_items.all() if hasattr(obj, 'key_point_items') else []
        if items:
            return [item.text for item in items]
        # Fallback to legacy JSON field
        return obj.key_points if obj.key_points else []

    def get_key_points_fr(self, obj):
        items = obj.key_point_items.all() if hasattr(obj, 'key_point_items') else []
        if items:
            return [item.text_fr or item.text for item in items]
        return obj.key_points_fr if obj.key_points_fr else []

    def get_impact_areas(self, obj):
        """Return list of dicts — from child model rows, fallback to JSON field."""
        items = obj.impact_area_items.all() if hasattr(obj, 'impact_area_items') else []
        if items:
            return [
                {'icon': item.icon_name, 'title': item.title, 'description': item.description}
                for item in items
            ]
        return obj.impact_areas if obj.impact_areas else []

    def get_impact_areas_fr(self, obj):
        items = obj.impact_area_items.all() if hasattr(obj, 'impact_area_items') else []
        if items:
            return [
                {'icon': item.icon_name, 'title': item.title_fr or item.title, 'description': item.description_fr or item.description}
                for item in items
            ]
        return obj.impact_areas_fr if obj.impact_areas_fr else []

class NotificationSerializer(serializers.ModelSerializer):
    is_read = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ['id', 'title', 'title_fr', 'message', 'message_fr',
                  'notification_type', 'action_type', 'action_value',
                  'image', 'is_read', 'created_at']

    def get_is_read(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.read_by.filter(id=request.user.id).exists()
        return False


class AppSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppSettings
        fields = ['summit_year', 'summit_theme', 'summit_theme_fr',
                  'website_url', 'facebook_url', 'twitter_url', 'instagram_url',
                  'app_description', 'app_description_fr',
                  'developer_name', 'developer_url',
                  'live_agent_online',
                  'bookmarks_enabled', 'discussions_enabled',
                  'polls_enabled', 'newsletter_enabled']


class PriorityAgendaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PriorityAgenda
        fields = ['id', 'title', 'title_fr', 'slug', 'description', 'description_fr',
                  'overview', 'overview_fr', 'objectives', 'objectives_fr',
                  'impact_areas', 'impact_areas_fr', 'current_initiatives',
                  'current_initiatives_fr', 'icon_name', 'display_order', 'hero_image']


class GalleryPhotoSerializer(serializers.ModelSerializer):
    thumbnail_url = serializers.CharField(read_only=True)
    medium_url = serializers.CharField(read_only=True)

    class Meta:
        model = GalleryPhoto
        fields = ['id', 'image', 'thumbnail_url', 'medium_url', 'caption', 'caption_fr',
                  'photographer', 'taken_date', 'display_order']


class GalleryAlbumSerializer(serializers.ModelSerializer):
    photos = GalleryPhotoSerializer(many=True, read_only=True)
    is_liked = serializers.BooleanField(read_only=True, default=False)
    recent_likers = serializers.SerializerMethodField()

    class Meta:
        model = GalleryAlbum
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'photo_count', 'view_count', 'like_count',
                  'created_at', 'is_featured', 'display_order', 'photos', 'is_liked',
                  'recent_likers']

    def get_recent_likers(self, obj):
        request = self.context.get('request')
        return get_recent_likers(GalleryAlbumLike, 'album', obj, request)


class VideoChapterSerializer(serializers.ModelSerializer):
    class Meta:
        model = VideoChapter
        fields = ['id', 'title', 'title_fr', 'timestamp_seconds',
                  'description', 'description_fr', 'thumbnail', 'order']


class VideoSubtitleSerializer(serializers.ModelSerializer):
    class Meta:
        model = VideoSubtitle
        fields = ['id', 'language', 'subtitle_file', 'is_default']


class VideoSerializer(serializers.ModelSerializer):
    # Return either the uploaded file URL or the external video_url
    video_url = serializers.SerializerMethodField()
    is_liked = serializers.BooleanField(read_only=True, default=False)
    chapters = VideoChapterSerializer(many=True, read_only=True)
    subtitles = VideoSubtitleSerializer(many=True, read_only=True)
    recent_likers = serializers.SerializerMethodField()

    class Meta:
        model = Video
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'video_url', 'thumbnail', 'duration', 'category', 'view_count',
                  'like_count', 'publish_date', 'is_featured', 'is_liked',
                  'chapters', 'subtitles', 'recent_likers']

    def get_video_url(self, obj):
        """Return video_file URL if exists, otherwise return video_url"""
        request = self.context.get('request')
        if obj.video_file:
            if request:
                return request.build_absolute_uri(obj.video_file.url)
            return obj.video_file.url
        return obj.video_url

    def get_recent_likers(self, obj):
        request = self.context.get('request')
        return get_recent_likers(VideoLike, 'video', obj, request)


class SocialMediaLinkSerializer(serializers.ModelSerializer):
    class Meta:
        model = SocialMediaLink
        fields = ['id', 'platform', 'display_name', 'display_name_fr', 'url',
                  'handle', 'follower_count', 'description', 'description_fr',
                  'icon_color', 'is_active', 'display_order']


class HeroTextContentSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroTextContent
        fields = ['id', 'key', 'text_en', 'text_fr', 'is_active', 'order']


class QuickAccessMenuItemSerializer(serializers.ModelSerializer):
    badge_text = serializers.SerializerMethodField()

    class Meta:
        model = QuickAccessMenuItem
        fields = ['id', 'title_en', 'title_fr', 'icon_name', 'action_type',
                  'action_value', 'order', 'is_active', 'has_live_indicator',
                  'badge_text', 'badge_color']

    def get_badge_text(self, obj):
        # Manual badge always takes priority
        if obj.badge_text:
            return obj.badge_text

        # Auto-detect new content if enabled
        if obj.auto_badge:
            from django.utils import timezone
            from datetime import timedelta
            cutoff = timezone.now() - timedelta(days=obj.auto_badge_days)

            route = obj.action_value
            has_new = False

            if route == '/news':
                from core.models import Article
                has_new = Article.objects.filter(publish_date__gte=cutoff).exists()
            elif route == '/magazine':
                from core.models import MagazineEdition
                has_new = MagazineEdition.objects.filter(publish_date__gte=cutoff).exists()
            elif route == '/gallery':
                from core.models import GalleryAlbum
                has_new = GalleryAlbum.objects.filter(created_at__gte=cutoff).exists()
            elif route == '/videos':
                from core.models import Video
                has_new = Video.objects.filter(created_at__gte=cutoff).exists()
            elif route == '/resources':
                from core.models import Resource
                has_new = Resource.objects.filter(created_at__gte=cutoff).exists()
            elif route == '/live-feeds':
                from core.models import LiveFeed
                has_new = LiveFeed.objects.filter(status='live').exists()
            elif route == '/calendar':
                from core.models import Event
                has_new = Event.objects.filter(
                    event_date__gte=timezone.now(),
                    created_at__gte=cutoff,
                ).exists()

            if has_new:
                return 'NEW'

        return ''


class VerificationSocialMediaSerializer(serializers.ModelSerializer):
    """Serializer for social media profiles in verification requests"""
    class Meta:
        model = VerificationSocialMedia
        fields = ['id', 'platform', 'username_or_url']


class VerificationRequestSerializer(serializers.ModelSerializer):
    """Serializer for creating and viewing verification requests"""
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)
    social_media_profiles = VerificationSocialMediaSerializer(many=True, required=False)

    class Meta:
        model = VerificationRequest
        fields = [
            'id', 'user', 'user_name', 'user_email',
            'title', 'first_name', 'last_name', 'full_name', 'gender',
            'email', 'country_code', 'phone_number', 'phone_verified',
            'position_role', 'reasoning_message', 'supporting_document',
            'social_media_profiles',
            'status', 'badge_type', 'rejection_reason',
            'appeal_message', 'appeal_submitted_at',
            'created_at', 'updated_at', 'reviewed_at'
        ]
        read_only_fields = [
            'id', 'user', 'user_name', 'user_email',
            'status', 'badge_type', 'rejection_reason', 'phone_verified',
            'appeal_submitted_at', 'created_at', 'updated_at', 'reviewed_at'
        ]

    def create(self, validated_data):
        """Create verification request with nested social media profiles"""
        social_media_data = validated_data.pop('social_media_profiles', [])
        verification_request = VerificationRequest.objects.create(**validated_data)

        # Create social media profiles
        for social_media in social_media_data:
            VerificationSocialMedia.objects.create(
                verification_request=verification_request,
                **social_media
            )

        return verification_request

    def validate(self, data):
        """Ensure user only has one pending/approved request"""
        user = self.context['request'].user

        # Check for existing pending or approved requests
        existing = VerificationRequest.objects.filter(
            user=user,
            status__in=['pending', 'approved', 'appealed']
        ).exists()

        if existing:
            raise serializers.ValidationError(
                'You already have a pending or approved verification request.'
            )

        return data


class VerificationStatusSerializer(serializers.Serializer):
    """Serializer for checking verification status"""
    has_verification = serializers.BooleanField()
    status = serializers.CharField(allow_null=True)
    badge_type = serializers.CharField(allow_null=True)
    rejection_reason = serializers.CharField(allow_null=True)
    can_appeal = serializers.BooleanField()
    request_details = VerificationRequestSerializer(allow_null=True)


class VerificationAppealSerializer(serializers.Serializer):
    """Serializer for submitting appeals"""
    appeal_message = serializers.CharField(
        max_length=1000,
        help_text='Explain why you believe the rejection was incorrect'
    )

    def validate_appeal_message(self, value):
        if len(value.strip()) < 50:
            raise serializers.ValidationError(
                'Appeal message must be at least 50 characters long.'
            )
        return value


class AdminVerificationActionSerializer(serializers.Serializer):
    """Serializer for admin approve/reject actions"""
    action = serializers.ChoiceField(choices=['approve', 'reject'])
    badge_type = serializers.ChoiceField(
        choices=['GOLD', 'BLUE'],
        required=False,
        help_text='Required for approve action'
    )
    rejection_reason = serializers.CharField(
        required=False,
        max_length=500,
        help_text='Required for reject action'
    )

    def validate(self, data):
        if data['action'] == 'approve' and not data.get('badge_type'):
            raise serializers.ValidationError({
                'badge_type': 'Badge type is required when approving.'
            })

        if data['action'] == 'reject' and not data.get('rejection_reason'):
            raise serializers.ValidationError({
                'rejection_reason': 'Rejection reason is required when rejecting.'
            })

        return data


class WeatherCitySerializer(serializers.ModelSerializer):
    class Meta:
        model = WeatherCity
        fields = ['id', 'name', 'latitude', 'longitude', 'background_image',
                  'order', 'is_default']

class RegistrationFormFieldSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistrationFormField
        fields = ['id', 'field_type', 'field_label', 'field_label_fr', 'field_name',
                  'placeholder', 'placeholder_fr', 'is_required', 'is_active',
                  'options', 'validation_regex', 'help_text', 'help_text_fr', 'order']


class EventCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = EventCategory
        fields = ['id', 'name', 'name_fr', 'icon_name', 'color']


class EventRegistrationSerializer(serializers.ModelSerializer):
    form_fields = RegistrationFormFieldSerializer(many=True, read_only=True)
    category_data = EventCategorySerializer(source='category', read_only=True)
    has_registered = serializers.SerializerMethodField()
    user_submission_status = serializers.SerializerMethodField()
    user_submission_id = serializers.SerializerMethodField()
    is_registration_open = serializers.SerializerMethodField()
    current_registration_count = serializers.SerializerMethodField()
    spots_remaining = serializers.SerializerMethodField()

    class Meta:
        model = EventRegistration
        fields = ['id', 'card_type', 'event_type', 'category_data', 'event_title', 'event_title_fr',
                  'event_description', 'event_description_fr', 'event_poster',
                  'event_date', 'event_end_date', 'venue', 'venue_fr', 'venue_address',
                  'contact_email', 'contact_phone',
                  'is_registration_enabled', 'registration_deadline',
                  'max_registrations', 'allow_proxy_registration',
                  'confirmation_message', 'confirmation_message_fr',
                  'show_photos', 'show_attendees', 'show_comments',
                  'is_active', 'order',
                  'form_fields', 'has_registered', 'user_submission_status',
                  'user_submission_id',
                  'is_registration_open', 'current_registration_count',
                  'spots_remaining']

    def get_has_registered(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.submissions.filter(user=request.user, is_proxy=False).exists()
        return False

    def get_user_submission_status(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            submission = obj.submissions.filter(user=request.user, is_proxy=False).first()
            if submission:
                return submission.status
        return None

    def get_is_registration_open(self, obj):
        if not obj.is_registration_enabled:
            return False
        if obj.registration_deadline:
            from django.utils import timezone
            if timezone.now() > obj.registration_deadline:
                return False
        if obj.max_registrations > 0:
            if obj.submissions.count() >= obj.max_registrations:
                return False
        return True

    def get_current_registration_count(self, obj):
        return obj.submissions.count()

    def get_user_submission_id(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            submission = obj.submissions.filter(user=request.user, is_proxy=False).first()
            if submission:
                return submission.id
        return None

    def get_spots_remaining(self, obj):
        if obj.max_registrations <= 0:
            return None  # Unlimited
        count = obj.submissions.filter(is_waitlisted=False).count()
        remaining = obj.max_registrations - count
        return max(0, remaining)


class EventSubmissionSerializer(serializers.ModelSerializer):
    event_title = serializers.CharField(source='event_registration.event_title', read_only=True)
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = EventSubmission
        fields = ['id', 'event_registration', 'event_title', 'user', 'user_name', 'user_email',
                  'form_data', 'uploaded_files',
                  'is_proxy', 'proxy_name', 'proxy_email', 'proxy_phone',
                  'status', 'is_waitlisted', 'checked_in_at', 'qr_ticket_hash',
                  'submitted_at', 'reviewed_at', 'reviewed_by']
        read_only_fields = ['id', 'user', 'is_waitlisted', 'checked_in_at', 'qr_ticket_hash',
                            'submitted_at', 'reviewed_at', 'reviewed_by']


class ProxyRegistrationSerializer(serializers.Serializer):
    event_registration = serializers.IntegerField()
    proxy_name = serializers.CharField(max_length=200)
    proxy_email = serializers.EmailField()
    proxy_phone = serializers.CharField(max_length=50, required=False, allow_blank=True)
    form_data = serializers.JSONField(required=False, default=dict)


class TicketMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()

    class Meta:
        model = TicketMessage
        fields = ['id', 'sender', 'sender_name', 'message', 'is_admin_reply',
                  'is_read', 'attachment', 'created_at']
        read_only_fields = ['id', 'sender', 'sender_name', 'is_admin_reply',
                            'is_read', 'created_at']

    def get_sender_name(self, obj):
        from .utils import user_handle
        return obj.sender.first_name or user_handle(obj.sender)


class SupportTicketListSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = SupportTicket
        fields = ['id', 'subject', 'status', 'priority', 'is_live_chat',
                  'created_at', 'updated_at', 'last_message', 'unread_count']

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'message': msg.message[:100],
                'is_admin_reply': msg.is_admin_reply,
                'created_at': msg.created_at.isoformat(),
            }
        return None

    def get_unread_count(self, obj):
        return obj.messages.filter(is_read=False, is_admin_reply=True).count()


class SupportTicketDetailSerializer(serializers.ModelSerializer):
    messages = TicketMessageSerializer(many=True, read_only=True)

    class Meta:
        model = SupportTicket
        fields = ['id', 'subject', 'status', 'priority', 'is_live_chat',
                  'created_at', 'updated_at', 'resolved_at',
                  'rating', 'rating_comment', 'messages']


class PopupSerializer(serializers.ModelSerializer):
    """Serializer for Popup/Announcement model"""
    class Meta:
        model = Popup
        fields = [
            'id', 'title', 'title_fr', 'message', 'message_fr',
            'image', 'action_text', 'action_text_fr', 'action_url',
            'popup_type', 'priority', 'show_once', 'created_at'
        ]

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # Ensure image is a full URL
        if instance.image:
            request = self.context.get('request')
            if request:
                ret['image'] = request.build_absolute_uri(instance.image.url)
            else:
                ret['image'] = instance.image.url
        return ret


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Authentication & Security
# ══════════════════════════════════════════════════════════════

class LoginHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LoginHistory
        fields = ['id', 'email', 'method', 'ip_address', 'device_type',
                  'country', 'city', 'success', 'failure_reason', 'created_at']
        read_only_fields = fields


class ActiveSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ActiveSession
        fields = ['id', 'device_name', 'device_type', 'ip_address', 'location',
                  'app_version', 'is_current', 'last_active', 'created_at']
        read_only_fields = fields


class PasswordChangeSerializer(serializers.Serializer):
    """Serializer for changing password."""
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, validators=[validate_password])

    def validate_current_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Current password is incorrect.')
        return value


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Content & Media
# ══════════════════════════════════════════════════════════════

class BookmarkSerializer(serializers.ModelSerializer):
    content_title = serializers.SerializerMethodField()
    content_image = serializers.SerializerMethodField()

    class Meta:
        model = Bookmark
        fields = ['id', 'content_type', 'content_id', 'notes', 'content_title',
                  'content_image', 'created_at']
        read_only_fields = ['id', 'created_at']

    def get_content_title(self, obj):
        try:
            if obj.content_type == 'article':
                return Article.objects.get(pk=obj.content_id).title
            elif obj.content_type == 'magazine':
                return MagazineEdition.objects.get(pk=obj.content_id).title
            elif obj.content_type == 'video':
                return Video.objects.get(pk=obj.content_id).title
        except Exception:
            pass
        return None

    def get_content_image(self, obj):
        request = self.context.get('request')
        try:
            img = None
            if obj.content_type == 'article':
                img = Article.objects.get(pk=obj.content_id).image
            elif obj.content_type == 'magazine':
                img = MagazineEdition.objects.get(pk=obj.content_id).cover_image
            elif obj.content_type == 'video':
                img = Video.objects.get(pk=obj.content_id).thumbnail
            if img and request:
                return request.build_absolute_uri(img.url)
        except Exception:
            pass
        return None


class ReactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reaction
        fields = ['id', 'content_type', 'content_id', 'reaction_type', 'created_at']
        read_only_fields = ['id', 'created_at']


class ReadingProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReadingProgress
        fields = ['id', 'article', 'progress_percent', 'scroll_position',
                  'completed', 'last_read_at']
        read_only_fields = ['id', 'last_read_at']


class ArticleDraftSerializer(serializers.ModelSerializer):
    class Meta:
        model = ArticleDraft
        fields = ['id', 'title', 'title_fr', 'content', 'content_fr',
                  'image', 'author', 'category', 'auto_saved',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class ContentVersionSerializer(serializers.ModelSerializer):
    changed_by_name = serializers.CharField(source='changed_by.username', read_only=True, default='')

    class Meta:
        model = ContentVersion
        fields = ['id', 'content_type', 'content_id', 'version_number',
                  'data_snapshot', 'changed_by_name', 'change_summary', 'created_at']
        read_only_fields = fields


class ArticleSeriesSerializer(serializers.ModelSerializer):
    article_count = serializers.SerializerMethodField()

    class Meta:
        model = ArticleSeries
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'article_count', 'is_active', 'order']

    def get_article_count(self, obj):
        return obj.articles.count()


class TrendingContentSerializer(serializers.ModelSerializer):
    content_title = serializers.SerializerMethodField()

    class Meta:
        model = TrendingContent
        fields = ['id', 'content_type', 'content_id', 'score',
                  'content_title', 'period_start', 'period_end']

    def get_content_title(self, obj):
        try:
            if obj.content_type == 'article':
                return Article.objects.get(pk=obj.content_id).title
            elif obj.content_type == 'magazine':
                return MagazineEdition.objects.get(pk=obj.content_id).title
            elif obj.content_type == 'video':
                return Video.objects.get(pk=obj.content_id).title
        except Exception:
            pass
        return None


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Events & Calendar
# ══════════════════════════════════════════════════════════════

class EventReminderSerializer(serializers.ModelSerializer):
    event_name = serializers.SerializerMethodField()

    class Meta:
        model = EventReminder
        fields = ['id', 'event', 'event_registration', 'reminder_type',
                  'reminder_time', 'sent', 'event_name', 'created_at']
        read_only_fields = ['id', 'sent', 'created_at']

    def get_event_name(self, obj):
        if obj.event:
            return obj.event.name
        if obj.event_registration:
            return obj.event_registration.event_title
        return None


class EventWaitlistSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventWaitlist
        fields = ['id', 'event_registration', 'position', 'notified',
                  'promoted', 'created_at']
        read_only_fields = ['id', 'position', 'notified', 'promoted', 'created_at']


class EventSpeakerSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventSpeaker
        fields = ['id', 'event', 'name', 'title', 'bio', 'bio_fr', 'photo',
                  'organization', 'topic', 'topic_fr', 'linkedin_url',
                  'twitter_handle', 'display_order', 'order']


class EventFeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventFeedback
        fields = ['id', 'event', 'event_registration', 'overall_rating',
                  'content_rating', 'organization_rating', 'venue_rating',
                  'comments', 'would_recommend', 'submitted_at']
        read_only_fields = ['id', 'submitted_at']


class EventCheckInSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.first_name', read_only=True)

    class Meta:
        model = EventCheckIn
        fields = ['id', 'user', 'user_name', 'event', 'event_registration',
                  'qr_code', 'checked_in', 'checked_in_at', 'created_at']
        read_only_fields = ['id', 'created_at']


class EventPhotoSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.first_name', read_only=True)

    class Meta:
        model = EventPhoto
        fields = ['id', 'user', 'user_name', 'event', 'event_registration',
                  'image', 'caption', 'is_approved', 'created_at']
        read_only_fields = ['id', 'user', 'is_approved', 'created_at']


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Communication & Social
# ══════════════════════════════════════════════════════════════

class ConversationSerializer(serializers.ModelSerializer):
    participant_names = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ['id', 'participant_names', 'last_message', 'unread_count',
                  'last_message_at', 'created_at']

    def get_participant_names(self, obj):
        from .utils import user_handle
        request = self.context.get('request')
        return [
            {'id': u.id, 'name': f'{u.first_name} {u.last_name}'.strip() or user_handle(u)}
            for u in obj.participants.all()
            if not request or u != request.user
        ]

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {'content': msg.content[:100], 'sender_id': msg.sender_id, 'created_at': msg.created_at}
        return None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.messages.filter(is_read=False).exclude(sender=request.user).count()
        return 0


class DirectMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()

    class Meta:
        model = DirectMessage
        fields = ['id', 'conversation', 'sender', 'sender_name', 'content',
                  'attachment', 'is_read', 'read_at', 'created_at']
        read_only_fields = ['id', 'sender', 'is_read', 'read_at', 'created_at']

    def get_sender_name(self, obj):
        from .utils import user_handle
        return f'{obj.sender.first_name} {obj.sender.last_name}'.strip() or user_handle(obj.sender)


class DiscussionSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    author_badge = serializers.SerializerMethodField()

    class Meta:
        model = Discussion
        fields = ['id', 'title', 'content', 'category', 'author', 'author_name',
                  'author_badge', 'is_pinned', 'is_locked', 'view_count',
                  'reply_count', 'last_reply_at', 'created_at']
        read_only_fields = ['id', 'author', 'view_count', 'reply_count',
                            'last_reply_at', 'created_at']

    def get_author_name(self, obj):
        from .utils import user_handle
        return f'{obj.author.first_name} {obj.author.last_name}'.strip() or user_handle(obj.author)

    def get_author_badge(self, obj):
        if hasattr(obj.author, 'profile') and obj.author.profile.is_verified:
            return obj.author.profile.badge_type
        return None


class DiscussionReplySerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()

    class Meta:
        model = DiscussionReply
        fields = ['id', 'discussion', 'author', 'author_name', 'content',
                  'parent', 'like_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'author', 'like_count', 'created_at', 'updated_at']

    def get_author_name(self, obj):
        from .utils import user_handle
        return f'{obj.author.first_name} {obj.author.last_name}'.strip() or user_handle(obj.author)


class PollOptionSerializer(serializers.ModelSerializer):
    vote_percentage = serializers.SerializerMethodField()

    class Meta:
        model = PollOption
        fields = ['id', 'text', 'text_fr', 'vote_count', 'vote_percentage', 'display_order', 'order']

    def get_vote_percentage(self, obj):
        if obj.poll.total_votes > 0:
            return round((obj.vote_count / obj.poll.total_votes) * 100, 1)
        return 0


class PollSerializer(serializers.ModelSerializer):
    options = PollOptionSerializer(many=True, read_only=True)
    user_voted = serializers.SerializerMethodField()
    user_vote_option = serializers.SerializerMethodField()

    class Meta:
        model = Poll
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'is_anonymous', 'multiple_choice', 'expires_at', 'total_votes',
                  'options', 'user_voted', 'user_vote_option', 'created_at']

    def get_user_voted(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return PollVote.objects.filter(poll=obj, user=request.user).exists()
        return False

    def get_user_vote_option(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            votes = PollVote.objects.filter(poll=obj, user=request.user).values_list('option_id', flat=True)
            return list(votes)
        return []


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = ['push_enabled', 'email_enabled', 'new_articles', 'new_magazines',
                  'event_reminders', 'event_updates', 'live_streams',
                  'verification_updates', 'support_replies', 'polls_surveys',
                  'direct_messages', 'discussion_replies', 'system_updates',
                  'quiet_hours_enabled', 'quiet_start', 'quiet_end']


class AnnouncementBannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnnouncementBanner
        fields = ['id', 'title', 'title_fr', 'message', 'message_fr',
                  'banner_type', 'link_url', 'action_url', 'action_text',
                  'action_text_fr', 'is_dismissible', 'is_active', 'starts_at',
                  'ends_at', 'priority']


class ContactDirectorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ContactDirectory
        fields = ['id', 'name', 'name_fr', 'title', 'title_fr', 'department',
                  'department_fr', 'organization', 'category', 'email', 'phone',
                  'photo', 'country', 'is_active', 'display_order', 'order']


class LiveQASessionSerializer(serializers.ModelSerializer):
    question_count = serializers.SerializerMethodField()

    class Meta:
        model = LiveQASession
        fields = ['id', 'title', 'event', 'event_registration', 'is_active',
                  'question_count', 'started_at', 'ended_at']

    def get_question_count(self, obj):
        return obj.questions.filter(is_approved=True).count()


class LiveQAQuestionSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()

    class Meta:
        model = LiveQAQuestion
        fields = ['id', 'session', 'user', 'user_name', 'question', 'is_answered',
                  'is_approved', 'upvote_count', 'answer', 'answered_at', 'created_at']
        read_only_fields = ['id', 'user', 'is_answered', 'is_approved', 'upvote_count',
                            'answer', 'answered_at', 'created_at']

    def get_user_name(self, obj):
        from .utils import user_handle
        return f'{obj.user.first_name} {obj.user.last_name}'.strip() or user_handle(obj.user)


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — User Preferences & Onboarding
# ══════════════════════════════════════════════════════════════

class UserPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserPreference
        fields = ['theme', 'text_size', 'auto_play_videos', 'haptic_feedback',
                  'data_saver_mode', 'onboarding_completed', 'onboarding_step',
                  'profile_completion', 'interests']


class OnboardingStepSerializer(serializers.ModelSerializer):
    class Meta:
        model = OnboardingStep
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'image', 'icon_name', 'order']


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Admin & Infrastructure
# ══════════════════════════════════════════════════════════════

class EmailTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmailTemplate
        fields = ['id', 'key', 'subject', 'subject_fr', 'body_html', 'body_html_fr',
                  'body_text', 'body_text_fr', 'is_active']


class ScheduledMaintenanceSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ScheduledMaintenance
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'starts_at', 'ends_at', 'is_active', 'show_banner',
                  'contact_email', 'severity', 'affected_services', 'image_url']

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class AppReleaseHighlightSerializer(serializers.ModelSerializer):
    class Meta:
        from .models import AppReleaseHighlight
        model = AppReleaseHighlight
        fields = ['id', 'order', 'icon_name',
                  'title_en', 'title_fr', 'subtitle_en', 'subtitle_fr']


class AppReleaseSerializer(serializers.ModelSerializer):
    highlights = AppReleaseHighlightSerializer(many=True, read_only=True)

    class Meta:
        model = AppRelease
        fields = ['id', 'version', 'version_code', 'title', 'title_fr',
                  'release_notes', 'release_notes_fr', 'is_force_update',
                  'min_supported_version', 'android_url', 'ios_url',
                  'popup_delay_seconds', 'is_published', 'released_at',
                  'highlights']


class ContentAnalyticsSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContentAnalytics
        fields = ['content_type', 'content_id', 'date', 'views', 'likes',
                  'shares', 'comments', 'bookmarks', 'avg_read_time_seconds']


class WeeklyReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = WeeklyReport
        fields = ['id', 'week_start', 'week_end', 'new_users', 'active_users',
                  'total_views', 'total_engagements', 'top_content', 'generated_at']


# ══════════════════════════════════════════════════════════════
# NEW SERIALIZERS — Admin Audit, Translations, Drafts, Versioning, etc.
# ══════════════════════════════════════════════════════════════

class AuditLogEntrySerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)
    class Meta:
        model = AuditLogEntry
        fields = ['id', 'user', 'user_email', 'action', 'model_name', 'object_id', 'object_repr', 'changes', 'ip_address', 'created_at']


class TranslationEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = TranslationEntry
        fields = ['id', 'key', 'language', 'value', 'context', 'is_approved', 'updated_at']


class FunnelStepSerializer(serializers.ModelSerializer):
    class Meta:
        model = FunnelStep
        fields = ['id', 'funnel_name', 'step_name', 'step_order']


class EngagementHeatmapSerializer(serializers.ModelSerializer):
    class Meta:
        model = EngagementHeatmap
        fields = ['screen_name', 'date', 'hour', 'event_count']


class AccountMergeRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccountMergeRequest
        fields = ['id', 'primary_user', 'secondary_user', 'status', 'created_at', 'processed_at']


class LinkedAccountSerializer(serializers.ModelSerializer):
    provider_display = serializers.CharField(source='get_provider_display', read_only=True)

    class Meta:
        from .models import LinkedAccount
        model = LinkedAccount
        fields = ['id', 'provider', 'provider_display', 'provider_uid', 'email',
                  'display_name', 'linked_at', 'is_primary']
        read_only_fields = ['id', 'linked_at']


class EventCommentSerializer(serializers.ModelSerializer):
    """Serializer for event comments with nested replies and @mention highlighting."""
    user_name = serializers.SerializerMethodField()
    username = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    replies = serializers.SerializerMethodField()
    reply_count = serializers.SerializerMethodField()

    class Meta:
        from .models import EventComment
        model = EventComment
        fields = ['id', 'event', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                  'parent', 'content', 'is_approved', 'created_at', 'replies', 'reply_count']
        read_only_fields = ['id', 'user_id', 'user_name', 'username', 'profile_picture', 'badge_type',
                            'is_approved', 'created_at', 'replies', 'reply_count']

    def get_user_name(self, obj):
        from .utils import user_handle
        return obj.user.get_full_name().strip() or user_handle(obj.user)

    def get_username(self, obj):
        from .utils import user_handle
        return user_handle(obj.user)

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None

    def get_badge_type(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.is_verified:
            return obj.user.profile.badge_type
        return None

    def get_replies(self, obj):
        # Only include replies for top-level comments (parent=None)
        if obj.parent is not None:
            return []
        replies = obj.replies.filter(is_approved=True).select_related('user', 'user__profile').order_by('created_at')
        return EventCommentSerializer(replies, many=True, context=self.context).data

    def get_reply_count(self, obj):
        if obj.parent is not None:
            return 0
        return obj.replies.filter(is_approved=True).count()


class NewsletterEditionSerializer(serializers.ModelSerializer):
    class Meta:
        from .models import NewsletterEdition
        model = NewsletterEdition
        fields = ['id', 'subject', 'body_html', 'sent_at', 'recipient_count', 'created_at']
        read_only_fields = ['id', 'sent_at', 'recipient_count', 'created_at']


class EventAttendeeSerializer(serializers.ModelSerializer):
    """Public attendee info for event networking (no email/phone for privacy)."""
    name = serializers.SerializerMethodField()
    badge_type = serializers.SerializerMethodField()
    nationality = serializers.SerializerMethodField()

    class Meta:
        from django.contrib.auth.models import User
        model = User
        fields = ['id', 'name', 'badge_type', 'nationality']

    def get_name(self, obj):
        from .utils import user_handle
        return obj.get_full_name() or user_handle(obj)

    def get_badge_type(self, obj):
        if hasattr(obj, 'profile') and obj.profile.is_verified:
            return obj.profile.badge_type
        return None

    def get_nationality(self, obj):
        if hasattr(obj, 'profile') and obj.profile.nationality:
            return obj.profile.nationality
        return None


class PasswordChangeHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PasswordChangeHistory
        fields = ['id', 'changed_at', 'ip_address']


class ArticleRevisionSerializer(serializers.ModelSerializer):
    edited_by_name = serializers.SerializerMethodField()

    class Meta:
        model = ArticleRevision
        fields = ['id', 'article', 'revision_number', 'title', 'content',
                  'edited_by', 'edited_by_name', 'created_at', 'change_summary']

    def get_edited_by_name(self, obj):
        if obj.edited_by:
            return obj.edited_by.get_full_name() or obj.edited_by.username
        return None


class TranslationRequestSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.SerializerMethodField()

    class Meta:
        model = TranslationRequest
        fields = ['id', 'content_type', 'object_id', 'source_language',
                  'target_language', 'status', 'assigned_to', 'assigned_to_name',
                  'notes', 'created_at', 'completed_at']

    def get_assigned_to_name(self, obj):
        if obj.assigned_to:
            return obj.assigned_to.get_full_name() or obj.assigned_to.username
        return None


class EventAgendaItemSerializer(serializers.ModelSerializer):
    speaker_name = serializers.CharField(source='speaker.name', read_only=True, default=None)
    speaker_photo = serializers.ImageField(source='speaker.photo', read_only=True, default=None)

    class Meta:
        model = EventAgendaItem
        fields = ['id', 'event', 'title', 'description', 'speaker',
                  'speaker_name', 'speaker_photo', 'start_time', 'end_time',
                  'room', 'track', 'order']
