from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink,
)


# ── User Profile Admin ────────────────────────────────────

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profile'
    fields = ['phone_number', 'gender', 'profile_picture', 'is_email_verified',
              'is_government_official', 'email_verified_at', 'government_verified_at']
    readonly_fields = ['email_verified_at', 'government_verified_at']


class CustomUserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ['username', 'email', 'first_name', 'is_verified_badge', 'is_official_badge', 'date_joined']
    list_filter = ['is_staff', 'is_superuser', 'profile__is_email_verified', 'profile__is_government_official']

    def is_verified_badge(self, obj):
        if hasattr(obj, 'profile') and obj.profile.is_email_verified:
            return format_html(
                '<span style="background:#28a745;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:600">✓ VERIFIED</span>'
            )
        return format_html('<span style="color:#999">—</span>')
    is_verified_badge.short_description = 'Email'

    def is_official_badge(self, obj):
        if hasattr(obj, 'profile') and obj.profile.is_government_official:
            return format_html(
                '<span style="background:#1EB53A;color:#fff;padding:3px 8px;border-radius:12px;font-size:10px;font-weight:600">🏛️ OFFICIAL</span>'
            )
        return format_html('<span style="color:#999">—</span>')
    is_official_badge.short_description = 'Status'


# Unregister default User admin and register our custom one
admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'phone_number', 'gender', 'is_email_verified', 'is_government_official', 'created_at']
    list_filter = ['gender', 'is_email_verified', 'is_government_official']
    search_fields = ['user__username', 'user__email', 'phone_number']
    readonly_fields = ['created_at', 'updated_at']
    list_per_page = 50

    fieldsets = (
        ('User', {'fields': ('user',)}),
        ('Personal Info', {'fields': ('phone_number', 'gender', 'profile_picture')}),
        ('Verification', {'fields': ('is_email_verified', 'is_government_official', 'email_verified_at', 'government_verified_at')}),
        ('Timestamps', {'fields': ('created_at', 'updated_at')}),
    )


# ── Content Admin ────────────────────────────────────────

@admin.register(HeroSlide)
class HeroSlideAdmin(admin.ModelAdmin):
    list_display = ['label', 'order', 'is_active', 'image_preview']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    list_per_page = 20
    save_on_top = True

    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" height="40" style="border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.15)" />',
                obj.image.url,
            )
        return format_html('<span style="color:#999">—</span>')
    image_preview.short_description = 'Preview'

    fieldsets = (
        ('English', {'fields': ('label',), 'classes': ('tab-english',)}),
        ('French', {'fields': ('label_fr',), 'classes': ('tab-french',)}),
        ('Media & Settings', {'fields': ('image', 'order', 'is_active')}),
    )


class MagazineImageInline(admin.TabularInline):
    model = MagazineImage
    extra = 1
    fields = ['image', 'caption', 'caption_fr', 'order']


@admin.register(MagazineEdition)
class MagazineEditionAdmin(admin.ModelAdmin):
    list_display = ['title', 'publish_date', 'is_featured', 'view_count', 'like_count', 'cover_preview']
    list_filter = ['is_featured', 'publish_date']
    search_fields = ['title', 'title_fr']
    list_editable = ['is_featured']
    list_per_page = 20
    date_hierarchy = 'publish_date'
    save_on_top = True
    readonly_fields = ['view_count', 'like_count']
    inlines = [MagazineImageInline]

    def cover_preview(self, obj):
        if obj.cover_image:
            return format_html(
                '<img src="{}" height="50" style="border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.15)" />',
                obj.cover_image.url,
            )
        return format_html('<span style="color:#999">—</span>')
    cover_preview.short_description = 'Cover'

    fieldsets = (
        ('English', {'fields': ('title', 'description')}),
        ('French', {'fields': ('title_fr', 'description_fr')}),
        ('Media', {
            'fields': ('cover_image', 'pdf_file', 'external_url'),
            'description': 'Leave cover image empty when uploading a PDF – a thumbnail will be auto-generated from the first page.',
        }),
        ('Settings', {'fields': ('publish_date', 'is_featured', 'page_count', 'file_size')}),
        ('Engagement', {'fields': ('view_count', 'like_count')}),
    )


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'name_fr', 'color_preview', 'order', 'article_count']
    list_editable = ['order']
    list_per_page = 20
    save_on_top = True

    def color_preview(self, obj):
        return format_html(
            '<span style="display:inline-block;width:60px;height:24px;border-radius:6px;background:{};"></span>',
            obj.color or '#ccc',
        )
    color_preview.short_description = 'Color'

    def article_count(self, obj):
        return obj.articles.count()
    article_count.short_description = 'Articles'

    fieldsets = (
        ('English', {'fields': ('name',)}),
        ('French', {'fields': ('name_fr',)}),
        ('Settings', {'fields': ('color', 'order')}),
    )


class ArticleMediaInline(admin.TabularInline):
    model = ArticleMedia
    extra = 1
    fields = ['media_type', 'image', 'video_url', 'caption', 'caption_fr', 'order']


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'category_badge', 'publish_date', 'is_featured',
                    'view_count', 'get_comment_count', 'get_like_count']
    list_filter = ['category', 'is_featured', 'publish_date']
    search_fields = ['title', 'title_fr', 'author', 'content']
    list_editable = ['is_featured']
    list_per_page = 20
    date_hierarchy = 'publish_date'
    save_on_top = True
    readonly_fields = ['image_preview_large', 'view_count']
    inlines = [ArticleMediaInline]

    def get_comment_count(self, obj):
        return obj.comments.count()
    get_comment_count.short_description = 'Comments'

    def get_like_count(self, obj):
        return obj.likes.count()
    get_like_count.short_description = 'Likes'

    def category_badge(self, obj):
        if obj.category:
            color = obj.category.color or '#6c757d'
            label = obj.category.name
        else:
            color = '#6c757d'
            label = '—'
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, label,
        )
    category_badge.short_description = 'Category'
    category_badge.admin_order_field = 'category__name'

    def image_preview_large(self, obj):
        if obj.image:
            return format_html('<img src="{}" style="max-height:200px;border-radius:8px" />', obj.image.url)
        return '—'
    image_preview_large.short_description = 'Image Preview'

    fieldsets = (
        ('English', {'fields': ('title', 'content')}),
        ('French', {'fields': ('title_fr', 'content_fr')}),
        ('Details', {'fields': ('author', 'category', 'image', 'image_preview_large', 'publish_date', 'is_featured')}),
    )


@admin.register(ArticleComment)
class ArticleCommentAdmin(admin.ModelAdmin):
    list_display = ['user', 'article', 'content_preview', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'article__title', 'content']
    list_per_page = 30
    raw_id_fields = ['user', 'article']

    def content_preview(self, obj):
        return obj.content[:80] + '...' if len(obj.content) > 80 else obj.content
    content_preview.short_description = 'Content'


@admin.register(ArticleLike)
class ArticleLikeAdmin(admin.ModelAdmin):
    list_display = ['user', 'article', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__username', 'article__title']
    list_per_page = 30
    raw_id_fields = ['user', 'article']


@admin.register(EmbassyLocation)
class EmbassyLocationAdmin(admin.ModelAdmin):
    list_display = ['name', 'city', 'country', 'type_badge', 'phone_number', 'map_link']
    list_filter = ['type', 'country']
    search_fields = ['name', 'name_fr', 'city', 'country']
    list_per_page = 20
    save_on_top = True

    def type_badge(self, obj):
        colors = {'embassy': '#1EB53A', 'consulate': '#D4AF37', 'mission': '#17a2b8'}
        color = colors.get(obj.type, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.type.title(),
        )
    type_badge.short_description = 'Type'
    type_badge.admin_order_field = 'type'

    def map_link(self, obj):
        if obj.latitude and obj.longitude:
            url = f'https://www.google.com/maps?q={obj.latitude},{obj.longitude}'
            return format_html(
                '<a href="{}" target="_blank" style="color:#1EB53A;font-weight:600">'
                '<i class="fas fa-map-marker-alt"></i> View Map</a>',
                url,
            )
        return '—'
    map_link.short_description = 'Map'

    fieldsets = (
        ('English', {'fields': ('name',)}),
        ('French', {'fields': ('name_fr',)}),
        ('Location', {'fields': ('address', 'city', 'country', 'latitude', 'longitude')}),
        ('Contact', {'fields': ('phone_number', 'email', 'website', 'opening_hours')}),
        ('Details', {'fields': ('type', 'image')}),
    )


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ['name', 'event_date', 'address', 'map_link']
    list_filter = ['event_date']
    search_fields = ['name', 'name_fr', 'address']
    list_per_page = 20
    date_hierarchy = 'event_date'
    save_on_top = True

    def map_link(self, obj):
        if obj.latitude and obj.longitude:
            url = f'https://www.google.com/maps?q={obj.latitude},{obj.longitude}'
            return format_html(
                '<a href="{}" target="_blank" style="color:#1EB53A;font-weight:600">'
                '<i class="fas fa-map-marker-alt"></i> Map</a>',
                url,
            )
        return '—'
    map_link.short_description = 'Map'

    fieldsets = (
        ('English', {'fields': ('name', 'description')}),
        ('French', {'fields': ('name_fr', 'description_fr')}),
        ('Location', {'fields': ('address', 'latitude', 'longitude')}),
        ('Details', {'fields': ('event_date', 'image')}),
    )


@admin.register(LiveFeed)
class LiveFeedAdmin(admin.ModelAdmin):
    list_display = ['title', 'status_badge', 'viewer_count', 'scheduled_time', 'stream_link']
    list_filter = ['status']
    search_fields = ['title', 'title_fr']
    list_editable = ['viewer_count']
    list_per_page = 20
    save_on_top = True

    def status_badge(self, obj):
        colors = {'live': '#CE1126', 'upcoming': '#D4AF37', 'ended': '#6c757d'}
        color = colors.get(obj.status, '#6c757d')
        icon = {'live': '🔴', 'upcoming': '🟡', 'ended': '⚫'}.get(obj.status, '')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">'
            '{} {}</span>',
            color, icon, obj.status.upper(),
        )
    status_badge.short_description = 'Status'
    status_badge.admin_order_field = 'status'

    def stream_link(self, obj):
        if obj.stream_url:
            return format_html(
                '<a href="{}" target="_blank" style="color:#1EB53A;font-weight:600">'
                '<i class="fas fa-external-link-alt"></i> Open Stream</a>',
                obj.stream_url,
            )
        return '—'
    stream_link.short_description = 'Stream'

    fieldsets = (
        ('English', {'fields': ('title',)}),
        ('French', {'fields': ('title_fr',)}),
        ('Stream', {'fields': ('stream_url', 'thumbnail', 'status')}),
        ('Stats', {'fields': ('viewer_count', 'duration', 'scheduled_time')}),
    )


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ['title', 'category_badge', 'file_type_badge', 'file_size']
    list_filter = ['category', 'file_type']
    search_fields = ['title', 'title_fr']
    list_per_page = 20
    save_on_top = True

    def category_badge(self, obj):
        colors = {
            'official_documents': '#1EB53A',
            'country_info': '#D4AF37',
            'media': '#CE1126',
            'reference': '#17a2b8',
        }
        color = colors.get(obj.category, '#6c757d')
        label = obj.category.replace('_', ' ').title()
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, label,
        )
    category_badge.short_description = 'Category'
    category_badge.admin_order_field = 'category'

    def file_type_badge(self, obj):
        colors = {'pdf': '#CE1126', 'zip': '#D4AF37'}
        color = colors.get(obj.file_type.lower(), '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 8px;border-radius:6px;font-size:10px;font-weight:700">{}</span>',
            color, obj.file_type.upper(),
        )
    file_type_badge.short_description = 'Type'

    fieldsets = (
        ('English', {'fields': ('title',)}),
        ('French', {'fields': ('title_fr',)}),
        ('File', {'fields': ('file', 'category', 'file_type', 'file_size')}),
    )


@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ['name', 'type_badge', 'phone_link', 'order']
    list_editable = ['order']
    list_filter = ['type']
    list_per_page = 20
    save_on_top = True

    def type_badge(self, obj):
        colors = {
            'embassy': '#1EB53A', 'police': '#17a2b8',
            'ambulance': '#CE1126', 'fire': '#D4AF37',
        }
        color = colors.get(obj.type, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.type.title(),
        )
    type_badge.short_description = 'Type'

    def phone_link(self, obj):
        return format_html(
            '<a href="tel:{}" style="color:#1EB53A;font-weight:600">'
            '<i class="fas fa-phone-alt"></i> {}</a>',
            obj.phone_number, obj.phone_number,
        )
    phone_link.short_description = 'Phone'

    fieldsets = (
        ('English', {'fields': ('name',)}),
        ('French', {'fields': ('name_fr',)}),
        ('Contact', {'fields': ('phone_number', 'type', 'order')}),
    )


@admin.register(FeatureCard)
class FeatureCardAdmin(admin.ModelAdmin):
    list_display = ['title', 'order', 'is_active', 'color_preview']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    list_per_page = 20
    save_on_top = True

    def color_preview(self, obj):
        return format_html(
            '<span style="display:inline-block;width:60px;height:24px;border-radius:6px;'
            'background:linear-gradient(135deg, {} 0%, {} 100%)"></span>',
            obj.gradient_start or '#ccc', obj.gradient_end or '#999',
        )
    color_preview.short_description = 'Gradient'

    fieldsets = (
        ('English', {'fields': ('title', 'description')}),
        ('French', {'fields': ('title_fr', 'description_fr')}),
        ('Media & Settings', {'fields': ('image', 'gradient_start', 'gradient_end', 'order', 'is_active')}),
    )


@admin.register(AppSettings)
class AppSettingsAdmin(admin.ModelAdmin):
    list_display = ['summit_year', 'summit_theme', 'social_links']
    save_on_top = True

    def social_links(self, obj):
        links = []
        if obj.website_url:
            links.append(format_html('<a href="{}" target="_blank" title="Website"><i class="fas fa-globe"></i></a>', obj.website_url))
        if obj.facebook_url:
            links.append(format_html('<a href="{}" target="_blank" title="Facebook"><i class="fab fa-facebook"></i></a>', obj.facebook_url))
        if obj.twitter_url:
            links.append(format_html('<a href="{}" target="_blank" title="Twitter"><i class="fab fa-twitter"></i></a>', obj.twitter_url))
        if obj.instagram_url:
            links.append(format_html('<a href="{}" target="_blank" title="Instagram"><i class="fab fa-instagram"></i></a>', obj.instagram_url))
        if links:
            return format_html(
                '<span style="font-size:18px;display:flex;gap:12px">{}</span>',
                format_html(' '.join(str(l) for l in links)),
            )
        return '—'
    social_links.short_description = 'Social'

    fieldsets = (
        ('Summit Info (English)', {'fields': ('summit_year', 'summit_theme')}),
        ('Summit Info (French)', {'fields': ('summit_theme_fr',)}),
        ('Social Links', {'fields': ('website_url', 'facebook_url', 'twitter_url', 'instagram_url')}),
    )


@admin.register(PriorityAgenda)
class PriorityAgendaAdmin(admin.ModelAdmin):
    list_display = ['title', 'slug', 'display_order', 'is_active', 'hero_image_preview']
    list_editable = ['display_order', 'is_active']
    list_filter = ['is_active']
    search_fields = ['title', 'title_fr', 'slug']
    prepopulated_fields = {'slug': ('title',)}
    list_per_page = 20
    save_on_top = True

    def hero_image_preview(self, obj):
        if obj.hero_image:
            return format_html(
                '<img src="{}" height="40" style="border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.15)" />',
                obj.hero_image.url,
            )
        return format_html('<span style="color:#999">—</span>')
    hero_image_preview.short_description = 'Hero Image'

    fieldsets = (
        ('English', {'fields': ('title', 'description', 'overview', 'current_initiatives')}),
        ('French', {'fields': ('title_fr', 'description_fr', 'overview_fr', 'current_initiatives_fr')}),
        ('Structured Data (English)', {'fields': ('objectives', 'impact_areas')}),
        ('Structured Data (French)', {'fields': ('objectives_fr', 'impact_areas_fr')}),
        ('Display Settings', {'fields': ('slug', 'icon_name', 'display_order', 'is_active')}),
        ('Media', {'fields': ('hero_image',)}),
    )


class GalleryPhotoInline(admin.TabularInline):
    model = GalleryPhoto
    extra = 1
    fields = ['image', 'caption', 'caption_fr', 'photographer', 'taken_date', 'display_order']


@admin.register(GalleryAlbum)
class GalleryAlbumAdmin(admin.ModelAdmin):
    list_display = ['title', 'photo_count', 'is_featured', 'display_order', 'cover_preview', 'created_at']
    list_editable = ['is_featured', 'display_order']
    list_filter = ['is_featured', 'created_at']
    search_fields = ['title', 'title_fr', 'description']
    list_per_page = 20
    save_on_top = True
    inlines = [GalleryPhotoInline]

    def cover_preview(self, obj):
        if obj.cover_image:
            return format_html(
                '<img src="{}" height="50" style="border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.15)" />',
                obj.cover_image.url,
            )
        return format_html('<span style="color:#999">—</span>')
    cover_preview.short_description = 'Cover'

    fieldsets = (
        ('English', {'fields': ('title', 'description')}),
        ('French', {'fields': ('title_fr', 'description_fr')}),
        ('Settings', {'fields': ('cover_image', 'photo_count', 'is_featured', 'display_order')}),
    )


@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    list_display = ['title', 'category_badge', 'duration', 'view_count', 'is_featured', 'publish_date', 'thumbnail_preview']
    list_editable = ['is_featured']
    list_filter = ['category', 'is_featured', 'publish_date']
    search_fields = ['title', 'title_fr', 'description']
    date_hierarchy = 'publish_date'
    list_per_page = 20
    save_on_top = True

    def category_badge(self, obj):
        colors = {
            'highlight': '#1EB53A',
            'speech': '#D4AF37',
            'documentary': '#17a2b8',
            'interview': '#CE1126',
            'event': '#9C27B0',
            'cultural': '#FF9800',
        }
        color = colors.get(obj.category, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.get_category_display(),
        )
    category_badge.short_description = 'Category'

    def thumbnail_preview(self, obj):
        if obj.thumbnail:
            return format_html(
                '<img src="{}" height="50" style="border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.15)" />',
                obj.thumbnail.url,
            )
        return format_html('<span style="color:#999">—</span>')
    thumbnail_preview.short_description = 'Thumbnail'

    fieldsets = (
        ('English', {'fields': ('title', 'description')}),
        ('French', {'fields': ('title_fr', 'description_fr')}),
        ('Video Details', {'fields': ('video_url', 'thumbnail', 'duration', 'category')}),
        ('Settings', {'fields': ('publish_date', 'is_featured', 'view_count')}),
    )


@admin.register(SocialMediaLink)
class SocialMediaLinkAdmin(admin.ModelAdmin):
    list_display = ['platform_badge', 'handle', 'follower_count', 'is_active', 'display_order', 'social_link']
    list_editable = ['is_active', 'display_order']
    list_filter = ['platform', 'is_active']
    list_per_page = 20
    save_on_top = True

    def platform_badge(self, obj):
        colors = {
            'facebook': '#1877F2',
            'twitter': '#1DA1F2',
            'instagram': '#E4405F',
            'youtube': '#FF0000',
            'linkedin': '#0A66C2',
            'tiktok': '#000000',
        }
        color = colors.get(obj.platform, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.get_platform_display(),
        )
    platform_badge.short_description = 'Platform'

    def social_link(self, obj):
        return format_html(
            '<a href="{}" target="_blank" style="color:#1EB53A;font-weight:600">'
            '<i class="fas fa-external-link-alt"></i> Open</a>',
            obj.url,
        )
    social_link.short_description = 'Link'

    fieldsets = (
        ('Platform', {'fields': ('platform', 'url', 'handle')}),
        ('Display (English)', {'fields': ('display_name', 'description')}),
        ('Display (French)', {'fields': ('display_name_fr', 'description_fr')}),
        ('Settings', {'fields': ('follower_count', 'icon_color', 'is_active', 'display_order')}),
    )
