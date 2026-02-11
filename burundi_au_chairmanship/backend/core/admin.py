from django.contrib import admin
from django.utils.html import format_html
from .models import (
    HeroSlide, MagazineEdition, Article, EmbassyLocation,
    Event, LiveFeed, Resource, EmergencyContact, AppSettings,
    FeatureCard,
)


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


@admin.register(MagazineEdition)
class MagazineEditionAdmin(admin.ModelAdmin):
    list_display = ['title', 'publish_date', 'is_featured', 'cover_preview']
    list_filter = ['is_featured', 'publish_date']
    search_fields = ['title', 'title_fr']
    list_editable = ['is_featured']
    list_per_page = 20
    date_hierarchy = 'publish_date'
    save_on_top = True

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
        ('Media', {'fields': ('cover_image', 'pdf_file')}),
        ('Settings', {'fields': ('publish_date', 'is_featured')}),
    )


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'category_badge', 'publish_date', 'is_featured']
    list_filter = ['category', 'is_featured', 'publish_date']
    search_fields = ['title', 'title_fr', 'author', 'content']
    list_editable = ['is_featured']
    list_per_page = 20
    date_hierarchy = 'publish_date'
    save_on_top = True
    readonly_fields = ['image_preview_large']

    def category_badge(self, obj):
        colors = {
            'news': '#1EB53A',
            'politics': '#CE1126',
            'culture': '#D4AF37',
            'economy': '#17a2b8',
        }
        color = colors.get(obj.category, '#6c757d')
        return format_html(
            '<span style="background:{};color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">{}</span>',
            color, obj.category.title(),
        )
    category_badge.short_description = 'Category'
    category_badge.admin_order_field = 'category'

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
