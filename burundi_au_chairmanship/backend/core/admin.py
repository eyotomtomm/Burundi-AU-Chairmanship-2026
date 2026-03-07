from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, Notification, MagazineLike,
    HeroTextContent, QuickAccessMenuItem,
)


# ═══════════════════════════════════════════════════════════════
#  ADMIN SITE BRANDING
# ═══════════════════════════════════════════════════════════════
admin.site.site_header = 'Burundi4africa'
admin.site.site_title = 'Burundi4africa Admin'
admin.site.index_title = 'Content Management'


# ═══════════════════════════════════════════════════════════════
#  USERS — simplified, no technical fields
# ═══════════════════════════════════════════════════════════════

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profile'
    fields = ['phone_number', 'gender', 'profile_picture',
              'is_government_official']


class CustomUserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ['username', 'email', 'first_name', 'last_name', 'is_staff', 'date_joined']
    # Simplified add form — just username, email, password
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2'),
        }),
    )
    # Simplified edit form — no technical permission stuff for content managers
    fieldsets = (
        ('Account', {'fields': ('username', 'password')}),
        ('Personal Info', {'fields': ('first_name', 'last_name', 'email')}),
        ('Access Level', {
            'fields': ('is_active', 'is_staff', 'is_superuser'),
            'description': 'Staff = can access this admin panel. Superuser = full access to everything.',
        }),
    )


admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)


# ═══════════════════════════════════════════════════════════════
#  HOME – Hero Slides & Feature Cards
# ═══════════════════════════════════════════════════════════════

@admin.register(HeroSlide)
class HeroSlideAdmin(admin.ModelAdmin):
    list_display = ['label', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    fields = ['image', 'label', 'label_fr', 'order', 'is_active']


@admin.register(FeatureCard)
class FeatureCardAdmin(admin.ModelAdmin):
    list_display = ['title', 'color_preview', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    search_fields = ['title', 'title_fr']

    # Hide technical fields — only show what content managers need
    fields = ['title', 'title_fr', 'description', 'description_fr',
              'image', 'gradient_start', 'gradient_end', 'order', 'is_active']

    @admin.display(description='Color')
    def color_preview(self, obj):
        return format_html(
            '<span style="display:inline-block;width:40px;height:18px;border-radius:4px;'
            'background:linear-gradient(135deg,{} 0%,{} 100%)"></span>',
            obj.gradient_start, obj.gradient_end
        )


# ═══════════════════════════════════════════════════════════════
#  NEWS – Categories & Articles
# ═══════════════════════════════════════════════════════════════

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'name_fr', 'color_chip', 'order']
    list_editable = ['order']
    fields = ['name', 'name_fr', 'color', 'order']

    @admin.display(description='Color')
    def color_chip(self, obj):
        return format_html(
            '<span style="display:inline-block;width:14px;height:14px;border-radius:50%;'
            'background:{};vertical-align:middle"></span> {}',
            obj.color, obj.color
        )


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'category', 'publish_date', 'is_featured', 'view_count']
    list_filter = ['category', 'is_featured']
    search_fields = ['title', 'title_fr', 'author']
    list_editable = ['is_featured']
    readonly_fields = ['view_count']

    fieldsets = (
        ('English', {
            'fields': ('title', 'content', 'image'),
        }),
        ('French', {
            'fields': ('title_fr', 'content_fr'),
            'classes': ('collapse',),
            'description': 'French translation (optional)',
        }),
        ('Publishing', {
            'fields': ('author', 'category', 'publish_date', 'is_featured'),
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  MAGAZINE — no image inline, simplified
# ═══════════════════════════════════════════════════════════════

@admin.register(MagazineEdition)
class MagazineEditionAdmin(admin.ModelAdmin):
    list_display = ['title', 'publish_date', 'is_featured', 'view_count', 'like_count']
    list_filter = ['is_featured', 'publish_date']
    search_fields = ['title', 'title_fr']
    list_editable = ['is_featured']
    readonly_fields = ['view_count', 'like_count']

    fieldsets = (
        ('Content', {
            'fields': ('title', 'title_fr', 'description', 'description_fr'),
        }),
        ('Files', {
            'fields': ('cover_image', 'pdf_file', 'external_url'),
            'description': 'Upload a cover image. Either upload a PDF or paste an external link.',
        }),
        ('Details', {
            'fields': ('publish_date', 'is_featured', 'page_count', 'file_size'),
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  LOCATIONS & EVENTS — hide lat/long, simple address only
# ═══════════════════════════════════════════════════════════════

@admin.register(EmbassyLocation)
class EmbassyLocationAdmin(admin.ModelAdmin):
    list_display = ['name', 'city', 'country', 'type', 'phone_number']
    list_filter = ['type', 'country']
    search_fields = ['name', 'city', 'country']

    fieldsets = (
        ('Info', {
            'fields': ('name', 'name_fr', 'type', 'image'),
        }),
        ('Address', {
            'fields': ('address', 'city', 'country'),
        }),
        ('Contact', {
            'fields': ('phone_number', 'email', 'website', 'opening_hours'),
        }),
        ('Map Coordinates (optional)', {
            'fields': ('latitude', 'longitude'),
            'classes': ('collapse',),
            'description': 'Leave as-is unless you need to update the map pin location.',
        }),
    )


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ['name', 'address', 'event_date']
    list_filter = ['event_date']
    search_fields = ['name', 'name_fr', 'address']

    fieldsets = (
        ('Event', {
            'fields': ('name', 'name_fr', 'description', 'description_fr', 'image'),
        }),
        ('When & Where', {
            'fields': ('event_date', 'address'),
        }),
        ('Map Coordinates (optional)', {
            'fields': ('latitude', 'longitude'),
            'classes': ('collapse',),
            'description': 'Leave as-is unless you need to update the map pin location.',
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  MEDIA – Live Feeds, Videos, Gallery
# ═══════════════════════════════════════════════════════════════

@admin.register(LiveFeed)
class LiveFeedAdmin(admin.ModelAdmin):
    list_display = ['title', 'status_badge', 'scheduled_time', 'viewer_count']
    list_filter = ['status']
    search_fields = ['title', 'title_fr']
    fields = ['title', 'title_fr', 'stream_url', 'thumbnail',
              'status', 'scheduled_time', 'duration', 'viewer_count']

    @admin.display(description='Status')
    def status_badge(self, obj):
        colors = {'live': '#1EB53A', 'upcoming': '#D4AF37', 'recorded': '#6c757d'}
        color = colors.get(obj.status, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;'
            'font-size:11px;font-weight:600">{}</span>',
            color, obj.get_status_display()
        )


class GalleryPhotoInline(admin.TabularInline):
    model = GalleryPhoto
    extra = 1
    fields = ['image', 'caption', 'photographer', 'display_order']


@admin.register(GalleryAlbum)
class GalleryAlbumAdmin(admin.ModelAdmin):
    list_display = ['title', 'photo_count', 'is_featured', 'display_order']
    list_editable = ['is_featured', 'display_order']
    list_filter = ['is_featured']
    search_fields = ['title', 'title_fr']
    readonly_fields = ['photo_count']
    inlines = [GalleryPhotoInline]

    fields = ['title', 'title_fr', 'description', 'description_fr',
              'cover_image', 'is_featured', 'display_order', 'photo_count']


@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    list_display = ['title', 'category', 'duration', 'view_count', 'is_featured']
    list_editable = ['is_featured']
    list_filter = ['category', 'is_featured']
    search_fields = ['title', 'title_fr']
    readonly_fields = ['view_count']

    fieldsets = (
        ('Content', {
            'fields': ('title', 'title_fr', 'description', 'description_fr'),
        }),
        ('Video', {
            'fields': ('video_url', 'thumbnail', 'duration', 'category'),
            'description': 'Paste the YouTube link. Duration example: 5:30 or 1:45:30',
        }),
        ('Publishing', {
            'fields': ('publish_date', 'is_featured'),
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  PRIORITY AGENDAS — simplified, hide JSON
# ═══════════════════════════════════════════════════════════════

@admin.register(PriorityAgenda)
class PriorityAgendaAdmin(admin.ModelAdmin):
    list_display = ['title', 'display_order', 'is_active']
    list_editable = ['display_order', 'is_active']
    search_fields = ['title', 'title_fr']
    prepopulated_fields = {'slug': ('title',)}

    fieldsets = (
        ('Info', {
            'fields': ('title', 'title_fr', 'slug', 'description', 'description_fr', 'hero_image'),
        }),
        ('Overview', {
            'fields': ('overview', 'overview_fr'),
        }),
        ('Initiatives', {
            'fields': ('current_initiatives', 'current_initiatives_fr'),
        }),
        ('Display', {
            'fields': ('display_order', 'is_active'),
        }),
        ('Advanced (technical)', {
            'fields': ('icon_name', 'objectives', 'objectives_fr', 'impact_areas', 'impact_areas_fr'),
            'classes': ('collapse',),
            'description': 'These are technical fields managed by the developer. Do not edit unless instructed.',
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  RESOURCES — show download link
# ═══════════════════════════════════════════════════════════════

@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ['title', 'category', 'file_type', 'file_size', 'download_link']
    list_filter = ['category', 'file_type']
    search_fields = ['title', 'title_fr']
    fields = ['title', 'title_fr', 'category', 'file', 'file_type', 'file_size']

    @admin.display(description='Download')
    def download_link(self, obj):
        if obj.file:
            return format_html('<a href="{}" target="_blank">Download</a>', obj.file.url)
        return '-'


@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone_number', 'type', 'order']
    list_editable = ['order']
    list_filter = ['type']
    search_fields = ['name', 'phone_number']
    fields = ['name', 'name_fr', 'phone_number', 'type', 'order']


# ═══════════════════════════════════════════════════════════════
#  SOCIAL & NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════

@admin.register(SocialMediaLink)
class SocialMediaLinkAdmin(admin.ModelAdmin):
    list_display = ['platform', 'handle', 'follower_count', 'is_active', 'display_order']
    list_editable = ['is_active', 'display_order']
    list_filter = ['platform', 'is_active']
    search_fields = ['handle', 'display_name']
    fields = ['platform', 'display_name', 'display_name_fr', 'url', 'handle',
              'follower_count', 'description', 'description_fr',
              'icon_color', 'is_active', 'display_order']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title', 'notification_type', 'is_global', 'is_active', 'created_at']
    list_filter = ['notification_type', 'is_global', 'is_active']
    search_fields = ['title', 'message']
    list_editable = ['is_active']

    fieldsets = (
        ('Message', {
            'fields': ('title', 'title_fr', 'message', 'message_fr', 'notification_type'),
        }),
        ('Who receives it', {
            'fields': ('is_global', 'is_active'),
            'description': 'Global = everyone gets it. Uncheck to target specific users below.',
        }),
        ('Target specific users', {
            'fields': ('target_users',),
            'classes': ('collapse',),
        }),
    )
    filter_horizontal = ['target_users']


# ═══════════════════════════════════════════════════════════════
#  SETTINGS
# ═══════════════════════════════════════════════════════════════

@admin.register(AppSettings)
class AppSettingsAdmin(admin.ModelAdmin):
    list_display = ['__str__']

    fieldsets = (
        ('Summit Info', {
            'fields': ('summit_year', 'summit_theme', 'summit_theme_fr'),
        }),
        ('Social Links', {
            'fields': ('website_url', 'facebook_url', 'twitter_url', 'instagram_url'),
            'description': 'Paste full URLs like https://facebook.com/YourPage',
        }),
    )

    def has_add_permission(self, request):
        return not AppSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False


# ═══════════════════════════════════════════════════════════════
#  HERO TEXT & QUICK ACCESS MENU
# ═══════════════════════════════════════════════════════════════

@admin.register(HeroTextContent)
class HeroTextContentAdmin(admin.ModelAdmin):
    list_display = ['text_en', 'text_fr', 'is_active', 'order']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    fields = ['text_en', 'text_fr', 'is_active', 'order']


@admin.register(QuickAccessMenuItem)
class QuickAccessMenuItemAdmin(admin.ModelAdmin):
    list_display = ['title_en', 'is_active', 'order']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    fields = ['title_en', 'title_fr', 'order', 'is_active', 'has_live_indicator']
