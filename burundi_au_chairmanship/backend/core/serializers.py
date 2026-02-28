from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import (
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink,
)


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    name = serializers.CharField(source='first_name')

    class Meta:
        model = User
        fields = ['name', 'email', 'password']

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
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
        fields = ['phone_number', 'gender', 'profile_picture', 'is_email_verified',
                  'is_government_official', 'email_verified_at', 'government_verified_at']
        read_only_fields = ['is_email_verified', 'is_government_official',
                            'email_verified_at', 'government_verified_at']


class UserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='first_name')
    profile = UserProfileSerializer(required=False)

    # Computed fields for easy access
    phone_number = serializers.CharField(source='profile.phone_number', required=False, allow_blank=True)
    gender = serializers.CharField(source='profile.gender', required=False, allow_blank=True)
    profile_picture = serializers.ImageField(source='profile.profile_picture', required=False, allow_null=True)
    is_email_verified = serializers.BooleanField(source='profile.is_email_verified', read_only=True)
    is_government_official = serializers.BooleanField(source='profile.is_government_official', read_only=True)

    class Meta:
        model = User
        fields = ['id', 'name', 'email', 'profile', 'phone_number', 'gender',
                  'profile_picture', 'is_email_verified', 'is_government_official']
        read_only_fields = ['id', 'email', 'is_email_verified', 'is_government_official']

    def update(self, instance, validated_data):
        # Update user fields
        instance.first_name = validated_data.get('first_name', instance.first_name)
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
        if 'profile_picture' in validated_data:
            profile_data['profile_picture'] = validated_data['profile_picture']

        if profile_data:
            profile = instance.profile
            for key, value in profile_data.items():
                setattr(profile, key, value)
            profile.save()

        return instance


class HeroSlideSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroSlide
        fields = ['id', 'image', 'label', 'label_fr', 'order']


class MagazineImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = MagazineImage
        fields = ['id', 'image', 'caption', 'caption_fr', 'order']


class MagazineEditionSerializer(serializers.ModelSerializer):
    effective_pdf_url = serializers.SerializerMethodField()
    images = MagazineImageSerializer(many=True, read_only=True)
    is_liked = serializers.BooleanField(read_only=True, default=False)

    class Meta:
        model = MagazineEdition
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'pdf_file', 'external_url', 'effective_pdf_url',
                  'publish_date', 'is_featured', 'view_count', 'like_count',
                  'page_count', 'file_size', 'images', 'is_liked']

    def get_effective_pdf_url(self, obj):
        if obj.pdf_file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.pdf_file.url)
            return obj.pdf_file.url
        return obj.external_url or ''


class ArticleCommentSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    profile_picture = serializers.SerializerMethodField()

    class Meta:
        model = ArticleComment
        fields = ['id', 'user_id', 'user_name', 'profile_picture', 'content', 'created_at']
        read_only_fields = ['id', 'user_id', 'user_name', 'profile_picture', 'created_at']

    def get_user_name(self, obj):
        return obj.user.first_name or obj.user.username

    def get_profile_picture(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.user.profile.profile_picture.url)
        return None


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

    class Meta:
        model = Article
        fields = ['id', 'title', 'title_fr', 'content', 'content_fr',
                  'image', 'author', 'category', 'publish_date', 'is_featured',
                  'view_count', 'comment_count', 'like_count', 'is_liked', 'media']


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
                  'address', 'latitude', 'longitude', 'event_date', 'image']


class LiveFeedSerializer(serializers.ModelSerializer):
    class Meta:
        model = LiveFeed
        fields = ['id', 'title', 'title_fr', 'stream_url', 'thumbnail',
                  'status', 'viewer_count', 'duration', 'scheduled_time']


class ResourceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Resource
        fields = ['id', 'title', 'title_fr', 'category', 'file',
                  'file_size', 'file_type']


class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'name_fr', 'phone_number', 'type', 'order']


class FeatureCardSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeatureCard
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'image', 'gradient_start', 'gradient_end', 'icon_name',
                  'action_type', 'action_value', 'order']


class AppSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppSettings
        fields = ['summit_year', 'summit_theme', 'summit_theme_fr',
                  'website_url', 'facebook_url', 'twitter_url', 'instagram_url']


class PriorityAgendaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PriorityAgenda
        fields = ['id', 'title', 'title_fr', 'slug', 'description', 'description_fr',
                  'overview', 'overview_fr', 'objectives', 'objectives_fr',
                  'impact_areas', 'impact_areas_fr', 'current_initiatives',
                  'current_initiatives_fr', 'icon_name', 'display_order', 'hero_image']


class GalleryPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = GalleryPhoto
        fields = ['id', 'image', 'caption', 'caption_fr', 'photographer',
                  'taken_date', 'display_order']


class GalleryAlbumSerializer(serializers.ModelSerializer):
    photos = GalleryPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = GalleryAlbum
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'photo_count', 'created_at', 'is_featured',
                  'display_order', 'photos']


class VideoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Video
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'video_url', 'thumbnail', 'duration', 'category', 'view_count',
                  'publish_date', 'is_featured']


class SocialMediaLinkSerializer(serializers.ModelSerializer):
    class Meta:
        model = SocialMediaLink
        fields = ['id', 'platform', 'display_name', 'display_name_fr', 'url',
                  'handle', 'follower_count', 'description', 'description_fr',
                  'icon_color', 'is_active', 'display_order']
