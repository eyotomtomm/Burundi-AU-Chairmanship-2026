from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import (
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, Notification,
)


# ── User Profile Admin ────────────────────────────────────

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profile'
    exclude = ['created_at', 'updated_at']


class CustomUserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ['username', 'email', 'first_name', 'is_staff', 'date_joined']


# Unregister default User admin and register our custom one
admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'phone_number', 'is_email_verified', 'is_government_official']
    list_filter = ['is_email_verified', 'is_government_official']
    search_fields = ['user__username', 'user__email', 'phone_number']
    exclude = ['created_at', 'updated_at']


# ── Content Admin ────────────────────────────────────────

@admin.register(HeroSlide)
class HeroSlideAdmin(admin.ModelAdmin):
    list_display = ['label', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    exclude = ['created_at']


@admin.register(MagazineEdition)
class MagazineEditionAdmin(admin.ModelAdmin):
    list_display = ['title', 'publish_date', 'is_featured', 'view_count', 'like_count']
    list_filter = ['is_featured', 'publish_date']
    search_fields = ['title', 'title_fr']
    list_editable = ['is_featured']
    readonly_fields = ['view_count', 'like_count']
    exclude = ['created_at', 'updated_at']


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'color', 'order']
    list_editable = ['order']
    exclude = ['created_at', 'updated_at']


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'category', 'publish_date', 'is_featured', 'view_count']
    list_filter = ['category', 'is_featured', 'publish_date']
    search_fields = ['title', 'title_fr', 'author']
    list_editable = ['is_featured']
    readonly_fields = ['view_count']
    exclude = ['created_at', 'updated_at']


@admin.register(ArticleComment)
class ArticleCommentAdmin(admin.ModelAdmin):
    list_display = ['user', 'article', 'content', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'article__title', 'content']
    exclude = ['updated_at']


@admin.register(ArticleLike)
class ArticleLikeAdmin(admin.ModelAdmin):
    list_display = ['user', 'article', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'article__title']


@admin.register(EmbassyLocation)
class EmbassyLocationAdmin(admin.ModelAdmin):
    list_display = ['name', 'city', 'country', 'type', 'phone_number']
    list_filter = ['type', 'country']
    search_fields = ['name', 'city', 'country']
    exclude = ['created_at', 'updated_at']


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ['name', 'address', 'event_date']
    list_filter = ['event_date']
    search_fields = ['name', 'name_fr', 'address']
    exclude = ['created_at', 'updated_at']


@admin.register(LiveFeed)
class LiveFeedAdmin(admin.ModelAdmin):
    list_display = ['title', 'status', 'scheduled_time', 'viewer_count']
    list_filter = ['status', 'scheduled_time']
    search_fields = ['title', 'title_fr']
    exclude = ['created_at', 'updated_at']


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ['title', 'category', 'file_type', 'file_size']
    list_filter = ['category', 'file_type']
    search_fields = ['title', 'title_fr']
    exclude = ['created_at', 'updated_at']


@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone_number', 'type', 'order']
    list_editable = ['order']
    list_filter = ['type']
    search_fields = ['name', 'name_fr', 'phone_number']
    exclude = ['created_at', 'updated_at']


@admin.register(FeatureCard)
class FeatureCardAdmin(admin.ModelAdmin):
    list_display = ['title', 'action_type', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['action_type', 'is_active']
    search_fields = ['title', 'title_fr']
    exclude = ['created_at']


@admin.register(AppSettings)
class AppSettingsAdmin(admin.ModelAdmin):
    list_display = ['summit_year', 'summit_theme']

    def has_add_permission(self, request):
        return not AppSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(PriorityAgenda)
class PriorityAgendaAdmin(admin.ModelAdmin):
    list_display = ['title', 'slug', 'display_order']
    list_editable = ['display_order']
    search_fields = ['title', 'title_fr', 'slug']
    prepopulated_fields = {'slug': ('title',)}
    exclude = ['created_at', 'updated_at']


@admin.register(GalleryAlbum)
class GalleryAlbumAdmin(admin.ModelAdmin):
    list_display = ['title', 'photo_count', 'is_featured', 'display_order']
    list_editable = ['is_featured', 'display_order']
    list_filter = ['is_featured']
    search_fields = ['title', 'title_fr']
    readonly_fields = ['photo_count']
    exclude = ['created_at', 'updated_at']


@admin.register(GalleryPhoto)
class GalleryPhotoAdmin(admin.ModelAdmin):
    list_display = ['album', 'caption', 'photographer', 'taken_date', 'display_order']
    list_editable = ['display_order']
    list_filter = ['album', 'taken_date']
    search_fields = ['caption', 'photographer']
    exclude = ['created_at', 'updated_at']


@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    list_display = ['title', 'category', 'view_count', 'publish_date', 'is_featured']
    list_editable = ['is_featured']
    list_filter = ['category', 'is_featured', 'publish_date']
    search_fields = ['title', 'title_fr']
    readonly_fields = ['view_count']
    exclude = ['created_at', 'updated_at']


@admin.register(SocialMediaLink)
class SocialMediaLinkAdmin(admin.ModelAdmin):
    list_display = ['platform', 'handle', 'follower_count', 'is_active', 'display_order']
    list_editable = ['is_active', 'display_order']
    list_filter = ['platform', 'is_active']
    search_fields = ['handle', 'display_name']
    exclude = ['created_at', 'updated_at']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title', 'notification_type', 'action_type', 'is_global', 'is_active', 'created_at']
    list_filter = ['notification_type', 'is_global', 'is_active']
    search_fields = ['title', 'title_fr', 'message']
    list_editable = ['is_active']
    filter_horizontal = ['target_users', 'read_by']


@admin.register(MagazineImage)
class MagazineImageAdmin(admin.ModelAdmin):
    list_display = ['edition', 'caption', 'order']
    list_editable = ['order']
    list_filter = ['edition']
    search_fields = ['caption']


@admin.register(ArticleMedia)
class ArticleMediaAdmin(admin.ModelAdmin):
    list_display = ['article', 'media_type', 'order']
    list_editable = ['order']
    list_filter = ['article', 'media_type']
    search_fields = ['caption']
