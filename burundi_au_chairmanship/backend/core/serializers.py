from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import (
    HeroSlide, MagazineEdition, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard,
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


class UserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='first_name')

    class Meta:
        model = User
        fields = ['id', 'name', 'email']
        read_only_fields = ['id', 'email']


class HeroSlideSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroSlide
        fields = ['id', 'image', 'label', 'label_fr', 'order']


class MagazineEditionSerializer(serializers.ModelSerializer):
    class Meta:
        model = MagazineEdition
        fields = ['id', 'title', 'title_fr', 'description', 'description_fr',
                  'cover_image', 'pdf_file', 'publish_date', 'is_featured']


class ArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Article
        fields = ['id', 'title', 'title_fr', 'content', 'content_fr',
                  'image', 'author', 'category', 'publish_date', 'is_featured']


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
                  'image', 'gradient_start', 'gradient_end', 'order']


class AppSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppSettings
        fields = ['summit_year', 'summit_theme', 'summit_theme_fr',
                  'website_url', 'facebook_url', 'twitter_url', 'instagram_url']
