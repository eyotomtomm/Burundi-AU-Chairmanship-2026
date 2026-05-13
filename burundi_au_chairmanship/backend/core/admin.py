from django.contrib import admin
from django.contrib.auth.models import User, Group
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from django.utils import timezone
from .models import (
    HeroSlide, MagazineEdition, MagazineImage, Article, EmbassyLocation,
    Event, LiveFeed, Resource, AppSettings,
    FeatureCard, UserProfile, ArticleComment, ArticleLike,
    Category, ArticleMedia, PriorityAgenda, GalleryAlbum,
    GalleryPhoto, Video, SocialMediaLink, Notification, MagazineLike,
    HeroTextContent, QuickAccessMenuItem, VerificationRequest, VerificationSocialMedia, WeatherCity,
    EventRegistration, RegistrationFormField, EventSubmission,
    FeatureCardKeyPoint, FeatureCardImpactArea, FeatureCardMedia,
    AuditLogEntry, AdminRole, SupportTicket, TicketMessage, Popup,
    UserSession, LinkedAccount,
)


# ═══════════════════════════════════════════════════════════════
#  ADMIN SITE CONFIGURATION
# ═══════════════════════════════════════════════════════════════
admin.site.site_header = 'Burundi Chairmanship 2026'
admin.site.site_title = 'Admin Panel'
admin.site.index_title = 'Content Management System'

# Hide unnecessary models
admin.site.unregister(Group)


# ═══════════════════════════════════════════════════════════════
#  USERS
# ═══════════════════════════════════════════════════════════════

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'User Profile Information'
    fields = [
        'firebase_uid',
        ('phone_number', 'gender'),
        ('nationality', 'date_of_birth'),
        'profile_picture',
        ('is_deactivated', 'deactivated_at'),
        ('is_scheduled_for_deletion', 'deletion_requested_at', 'deletion_scheduled_for'),
    ]
    readonly_fields = ['firebase_uid', 'deactivated_at', 'deletion_requested_at', 'deletion_scheduled_for']


class CustomUserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ['username', 'email', 'first_name', 'last_name', 'is_active',
                    'is_staff', 'account_status', 'assigned_roles', 'date_joined']
    list_filter = ['is_active', 'is_staff', 'is_superuser', 'date_joined',
                   'profile__is_deactivated', 'profile__is_scheduled_for_deletion']
    search_fields = ['username', 'email', 'first_name', 'last_name', 'profile__firebase_uid']
    ordering = ['-date_joined']
    actions = ['make_staff', 'remove_staff', 'reactivate_accounts', 'terminate_all_sessions']

    add_fieldsets = (
        ('Account Information', {
            'fields': ('username', 'email', 'first_name', 'last_name', 'password1', 'password2'),
            'description': 'Create a new user account. To grant admin access, check "Staff status" below.',
        }),
        ('Admin Access', {
            'fields': ('is_active', 'is_staff', 'is_superuser'),
            'description': 'Staff status = can access admin portal. Superuser = full access to everything. '
                           'For limited access, make them Staff and assign an Admin Role.',
        }),
    )

    fieldsets = (
        ('Account', {
            'fields': ('username', 'email', 'first_name', 'last_name', 'password')
        }),
        ('Admin Access & Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser'),
            'description': 'Staff status = can log into admin portal. Superuser = unrestricted access. '
                           'For granular access, assign Admin Roles below.',
        }),
        ('Important Dates', {
            'fields': ('date_joined', 'last_login'),
            'classes': ('collapse',),
        }),
    )
    readonly_fields = ['date_joined', 'last_login']

    def account_status(self, obj):
        if hasattr(obj, 'profile'):
            p = obj.profile
            if p.is_scheduled_for_deletion:
                days_left = (p.deletion_scheduled_for - timezone.now()).days if p.deletion_scheduled_for else 0
                return format_html(
                    '<span style="color:red; font-weight:bold;">Deleting in {} days</span>',
                    max(0, days_left)
                )
            if p.is_deactivated:
                return format_html('<span style="color:orange;">On Break</span>')
        if obj.is_active:
            return format_html('<span style="color:green;">Active</span>')
        return format_html('<span style="color:gray;">Inactive</span>')
    account_status.short_description = 'Status'

    def assigned_roles(self, obj):
        roles = AdminRole.objects.filter(users=obj, is_active=True)
        if not roles.exists():
            if obj.is_superuser:
                return format_html('<span style="color:#B8860B; font-weight:bold;">Superuser (Full Access)</span>')
            return '-'
        return ', '.join(r.name for r in roles)
    assigned_roles.short_description = 'Admin Roles'

    def make_staff(self, request, queryset):
        updated = queryset.update(is_staff=True)
        self.message_user(request, f'{updated} user(s) granted admin portal access.')
    make_staff.short_description = 'Grant admin portal access (Staff)'

    def remove_staff(self, request, queryset):
        updated = queryset.exclude(is_superuser=True).update(is_staff=False)
        self.message_user(request, f'{updated} user(s) had admin access removed. Superusers were skipped.')
    remove_staff.short_description = 'Remove admin portal access (Staff)'

    def reactivate_accounts(self, request, queryset):
        count = 0
        for user in queryset:
            if hasattr(user, 'profile') and (user.profile.is_deactivated or user.profile.is_scheduled_for_deletion):
                user.profile.is_deactivated = False
                user.profile.deactivated_at = None
                user.profile.is_scheduled_for_deletion = False
                user.profile.deletion_requested_at = None
                user.profile.deletion_scheduled_for = None
                user.profile.save()
                user.is_active = True
                user.save()
                count += 1
        self.message_user(request, f'{count} account(s) reactivated.')
    reactivate_accounts.short_description = 'Reactivate selected accounts'

    def terminate_all_sessions(self, request, queryset):
        from .models import UserSession
        count = 0
        for user in queryset:
            terminated = UserSession.objects.filter(user=user, is_active=True).update(
                is_active=False, terminated_at=timezone.now()
            )
            count += terminated
        self.message_user(request, f'{count} session(s) terminated across {queryset.count()} user(s).')
    terminate_all_sessions.short_description = 'Terminate all user sessions'


admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)


@admin.register(AdminRole)
class AdminRoleAdmin(admin.ModelAdmin):
    """
    ADMIN ROLES - Define access levels for admin users

    HELP:
    Create roles like "Content Editor", "Event Manager", "Notification Admin" etc.
    Assign users to roles to control what they can access in the admin portal.

    AVAILABLE PERMISSIONS:
    - content: Articles, Magazines, Hero Slides, Feature Cards
    - events: Events & Event Registrations
    - users: User Management & Profiles
    - verification: Verification Request approvals
    - notifications: Push Notification management
    - gallery: Photo Gallery & Albums
    - locations: Embassy & Location data
    - settings: App Settings & Configuration
    - audit: View Audit Logs
    """
    list_display = ['name', 'description', 'permission_list', 'user_count', 'is_active']
    list_filter = ['is_active']
    search_fields = ['name', 'description']
    filter_horizontal = ['users']

    fieldsets = (
        (None, {
            'fields': ('name', 'description', 'is_active'),
        }),
        ('Permissions', {
            'fields': ('permissions',),
            'description': (
                'Enter a JSON list of permission keys. Available permissions:\n'
                '["content", "events", "users", "verification", "notifications", '
                '"gallery", "locations", "settings", "audit"]\n\n'
                'Example for a Content Editor: ["content", "gallery"]\n'
                'Example for an Event Manager: ["events", "notifications"]'
            ),
        }),
        ('Assigned Users', {
            'fields': ('users',),
            'description': 'Select which users have this role. Users must also have "Staff" status to access the admin portal.',
        }),
    )

    def permission_list(self, obj):
        labels = obj.get_permission_labels()
        if not labels:
            return '-'
        return ', '.join(labels)
    permission_list.short_description = 'Permissions'

    def user_count(self, obj):
        count = obj.users.count()
        return format_html('<strong>{}</strong> user(s)', count)
    user_count.short_description = 'Users'


# ═══════════════════════════════════════════════════════════════
#  HOME SCREEN CONTENT
# ═══════════════════════════════════════════════════════════════

@admin.register(HeroSlide)
class HeroSlideAdmin(admin.ModelAdmin):
    """
    HERO SLIDES - Top rotating banner images on home screen

    HELP:
    These images appear at the very top of the app home screen in a slideshow.
    - Upload high-quality images (recommended: 1200x600px)
    - Add a short label that appears over the image
    - Set the order to control which appears first
    - Use "is active" to show/hide slides without deleting them
    """
    list_display = ['label', 'image_preview', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    search_fields = ['label', 'label_fr']

    fieldsets = (
        (None, {
            'fields': [
                'image',
                ('label', 'label_fr'),
                ('order', 'is_active'),
            ],
        }),
    )

    def image_preview(self, obj):
        if obj.image:
            return format_html('<img src="{}" style="max-height:50px; border-radius:4px;" />', obj.image.url)
        return '-'
    image_preview.short_description = 'Preview'


@admin.register(HeroTextContent)
class HeroTextAdmin(admin.ModelAdmin):
    """
    HERO TEXT - Big text overlay on home screen

    HELP:
    This is the large text that appears over the hero slideshow.
    Examples: "BURUNDI", "African Union", "Chairmanship", "2026"

    KEYS:
    - badge: Small text at top (e.g., "BURUNDI")
    - title_line1: First line of big title (e.g., "African Union")
    - title_line2: Second line of big title (e.g., "Chairmanship")
    - year: Year text (e.g., "2026")
    """
    list_display = ['key', 'text_en', 'text_fr']
    list_editable = ['text_en', 'text_fr']
    fields = ['key', ('text_en', 'text_fr')]


class FeatureCardKeyPointInline(admin.TabularInline):
    model = FeatureCardKeyPoint
    extra = 1
    fields = ['order', 'text', 'text_fr']


class FeatureCardImpactAreaInline(admin.TabularInline):
    model = FeatureCardImpactArea
    extra = 1
    fields = ['order', 'icon_name', 'title', 'title_fr', 'description', 'description_fr']


class FeatureCardMediaInline(admin.TabularInline):
    model = FeatureCardMedia
    extra = 1
    fields = ['order', 'media_type', 'image', 'image_url', 'video_file', 'video_url', 'caption', 'caption_fr']


@admin.register(FeatureCard)
class FeatureCardAdmin(admin.ModelAdmin):
    """
    FEATURE CARDS - Main content cards on home screen

    HELP:
    These are the colorful cards that appear on the home screen.
    Users can tap them to see more details or navigate to different sections.

    HOW TO USE:
    1. Add a title and description
    2. Upload a background image (optional)
    3. Upload an icon image or choose a built-in icon
    4. Set gradient colors for the card background
    5. Set the order (lower numbers appear first)
    6. Check "is active" to make it visible in the app

    DETAIL PAGE CONTENT:
    Use the inline sections below to add:
    - Key Points: Simple text rows (one per line)
    - Impact Areas: Icon + title + description rows
    - Media: Upload photos or add video URLs

    No JSON needed — just fill in the rows!
    """
    inlines = [
        FeatureCardKeyPointInline,
        FeatureCardImpactAreaInline,
        FeatureCardMediaInline,
    ]
    list_display = ['title', 'preview', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active']
    search_fields = ['title', 'title_fr', 'description']

    fieldsets = (
        ('Basic Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
                'image',
            ],
        }),
        ('Visual Design', {
            'fields': [
                'icon_image',
                'icon_name',
                ('gradient_start', 'gradient_end'),
            ],
            'description': 'Upload a custom icon or select a built-in one. Set gradient colors for card background.',
        }),
        ('Display Settings', {
            'fields': [
                ('order', 'is_active'),
            ],
        }),
        ('Detail Page Text (Optional)', {
            'fields': [
                ('overview', 'overview_fr'),
                ('extra_content', 'extra_content_fr'),
            ],
            'classes': ('collapse',),
            'description': 'Overview and extra text for the detail page. Key points, impact areas, and media are managed below.',
        }),
    )

    def preview(self, obj):
        if obj.image:
            return format_html('<img src="{}" style="max-height:40px; border-radius:8px;" />', obj.image.url)
        elif obj.gradient_start:
            return format_html(
                '<div style="width:40px; height:40px; background:linear-gradient(135deg, {}, {}); border-radius:8px;"></div>',
                obj.gradient_start, obj.gradient_end
            )
        return '-'
    preview.short_description = 'Preview'


@admin.register(QuickAccessMenuItem)
class QuickAccessAdmin(admin.ModelAdmin):
    """
    QUICK ACCESS MENU - Icon menu below hero section

    HELP:
    This is the row of icons that appears below the hero slideshow.
    Each icon is a shortcut to a different section of the app.

    HOW TO USE:
    1. Set the title (shown below the icon)
    2. Choose an icon name (e.g., live_tv, menu_book, article)
    3. Set where it should navigate to (e.g., /live-feeds, /magazine)
    4. Set the order to control position
    5. Check "is active" to show/hide

    SPECIAL FEATURES:
    - "Has live indicator": Shows a red "LIVE" badge
    - "Badge text": Custom badge text (e.g., "NEW", "HOT")
    """
    list_display = ['title_en', 'icon_name', 'action_value', 'order', 'is_active']
    list_editable = ['order', 'is_active']
    list_filter = ['is_active', 'has_live_indicator']
    search_fields = ['title_en', 'title_fr']

    fieldsets = (
        ('Menu Item', {
            'fields': [
                ('title_en', 'title_fr'),
                'icon_name',
                'action_value',
                ('order', 'is_active'),
            ],
        }),
        ('Badges (Optional)', {
            'fields': [
                ('has_live_indicator', 'badge_text'),
            ],
            'classes': ('collapse',),
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  EVENTS & HOLIDAY CARDS
# ═══════════════════════════════════════════════════════════════

class RegistrationFormFieldInline(admin.TabularInline):
    model = RegistrationFormField
    extra = 1
    fields = ['order', 'field_type', 'field_label', 'field_label_fr', 'field_name', 'is_required', 'is_active']
    classes = ['collapse']


@admin.register(EventRegistration)
class EventRegistrationAdmin(admin.ModelAdmin):
    """
    EVENT REGISTRATIONS - Standalone event registration management.

    HOW TO USE:
    1. Add event title, description, and poster image
    2. Set event date, venue, and contact info
    3. Configure registration settings (deadline, max, proxy)
    4. Add form fields in the section below
    5. Check "is active" to make visible in app
    """
    inlines = [RegistrationFormFieldInline]
    list_display = ['event_title', 'card_type', 'event_date', 'venue', 'submission_count', 'is_active', 'order']
    list_editable = ['is_active', 'order']
    list_filter = ['card_type', 'is_registration_enabled', 'is_active', 'created_at']
    search_fields = ['event_title', 'event_title_fr']

    fieldsets = (
        ('Event Information', {
            'fields': [
                'card_type',
                ('event_title', 'event_title_fr'),
                ('event_description', 'event_description_fr'),
                'event_poster',
            ],
        }),
        ('Date & Venue', {
            'fields': [
                ('event_date', 'event_end_date'),
                ('venue', 'venue_fr'),
                'venue_address',
            ],
        }),
        ('Contact', {
            'fields': [
                ('contact_email', 'contact_phone'),
            ],
        }),
        ('Registration Settings', {
            'fields': [
                'is_registration_enabled',
                'registration_deadline',
                'max_registrations',
                'allow_proxy_registration',
                'send_confirmation_email',
                ('confirmation_message', 'confirmation_message_fr'),
            ],
        }),
        ('Display', {
            'fields': [
                ('is_active', 'order'),
            ],
        }),
    )

    def submission_count(self, obj):
        count = obj.submissions.count()
        return format_html(
            '<span style="background:#1E88E5; color:white; padding:2px 8px; border-radius:3px; font-size:11px;">{}</span>',
            count
        )
    submission_count.short_description = 'Submissions'


@admin.register(EventSubmission)
class EventSubmissionAdmin(admin.ModelAdmin):
    """
    EVENT SUBMISSIONS - User registrations and form submissions

    HELP:
    This is where you see all user submissions for event registrations.
    You can review, approve, or reject submissions here.

    STATUS OPTIONS:
    - Pending: Waiting for your review
    - Approved: User registration accepted
    - Rejected: User registration denied
    - Waitlist: User added to waiting list

    HOW TO REVIEW:
    1. Click on a submission to see the details
    2. Review the user's submitted information
    3. Change the status to approve/reject
    4. Add admin notes (optional)
    5. Save

    The system tracks when you reviewed it and who reviewed it.
    """
    list_display = ['user', 'event_title', 'status_badge', 'submitted_at']
    list_filter = ['status', 'submitted_at']
    search_fields = ['user__username', 'user__email', 'user__first_name', 'event_registration__event_title']
    readonly_fields = ['user', 'event_registration', 'submitted_at', 'form_data_display']
    date_hierarchy = 'submitted_at'

    fieldsets = (
        ('Submission Information', {
            'fields': ['event_registration', 'user', 'submitted_at'],
        }),
        ('Submitted Data', {
            'fields': ['form_data_display'],
        }),
        ('Review & Status', {
            'fields': ['status', 'admin_notes', 'reviewed_at', 'reviewed_by'],
        }),
    )

    def event_title(self, obj):
        return obj.event_registration.event_title
    event_title.short_description = 'Event'

    def status_badge(self, obj):
        colors = {
            'pending': '#FFA500',
            'approved': '#28A745',
            'rejected': '#DC3545',
            'waitlist': '#6C757D',
        }
        return format_html(
            '<span style="background:{}; color:white; padding:3px 10px; border-radius:3px; font-size:11px; font-weight:600;">{}</span>',
            colors.get(obj.status, '#666'),
            obj.get_status_display().upper()
        )
    status_badge.short_description = 'Status'

    def form_data_display(self, obj):
        if not obj.form_data:
            return 'No data submitted'
        from django.utils.html import escape, format_html_join

        header = '<table style="width:100%; border-collapse:collapse; margin:10px 0;"><thead><tr style="background:#f5f5f5;"><th style="padding:10px; text-align:left; border:1px solid #ddd;">Field</th><th style="padding:10px; text-align:left; border:1px solid #ddd;">Value</th></tr></thead><tbody>'
        footer = '</tbody></table>'
        rows = format_html_join(
            '',
            '<tr><td style="padding:10px; border:1px solid #ddd; font-weight:600;">{}</td><td style="padding:10px; border:1px solid #ddd;">{}</td></tr>',
            ((escape(str(k)), escape(str(v))) for k, v in obj.form_data.items())
        )
        return format_html('{}{}{}', format_html(header), rows, format_html(footer))
    form_data_display.short_description = 'User Submitted Information'

    def save_model(self, request, obj, form, change):
        if obj.status in ['approved', 'rejected'] and not obj.reviewed_at:
            obj.reviewed_at = timezone.now()
            obj.reviewed_by = request.user
        super().save_model(request, obj, form, change)


# ═══════════════════════════════════════════════════════════════
#  CONTENT - ARTICLES, MAGAZINES, VIDEOS
# ═══════════════════════════════════════════════════════════════

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    """
    CATEGORIES - Organize articles and videos by topic

    HELP:
    Categories help organize content into topics like Politics, Economy, Culture, etc.
    Users can filter articles and videos by category in the app.
    """
    list_display = ['name', 'name_fr', 'order']
    list_editable = ['order']
    fields = [('name', 'name_fr'), 'order']


class ArticleMediaInline(admin.TabularInline):
    model = ArticleMedia
    extra = 1
    fields = ['media_type', 'file', 'caption', 'caption_fr', 'order']
    classes = ['collapse']


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    """
    ARTICLES - News articles and blog posts

    HELP:
    Articles appear in the News section and on the home screen.

    HOW TO USE:
    1. Add a title and cover image
    2. Choose a category
    3. Write the article content
    4. Check "is featured" to show on home screen
    5. Set publish date
    6. Add media files (images/videos) in the Media section below if needed

    FEATURED ARTICLES:
    Articles marked as "featured" appear in a special section on the home screen.
    """
    inlines = [ArticleMediaInline]
    list_display = ['title', 'category', 'is_featured', 'publish_date', 'view_count', 'like_count']
    list_filter = ['is_featured', 'category', 'publish_date']
    list_editable = ['is_featured']
    search_fields = ['title', 'title_fr', 'content']
    date_hierarchy = 'publish_date'

    fieldsets = (
        ('Article Content', {
            'fields': [
                ('title', 'title_fr'),
                'cover_image',
                'category',
                'content',
                'content_fr',
            ],
        }),
        ('Publishing', {
            'fields': [
                'publish_date',
                'is_featured',
            ],
        }),
    )


class MagazineImageInline(admin.TabularInline):
    model = MagazineImage
    extra = 1
    fields = ['image', 'caption', 'caption_fr', 'order']
    classes = ['collapse']


@admin.register(MagazineEdition)
class MagazineAdmin(admin.ModelAdmin):
    """
    MAGAZINE EDITIONS - Digital magazine publications

    HELP:
    Magazines are PDF publications that users can read in the app.
    They can download magazines for offline reading.

    HOW TO USE:
    1. Add a title and description
    2. Upload a cover image
    3. Upload the PDF file
    4. Set page count and file size
    5. Check "is featured" to highlight on home screen
    6. Add preview images in the Images section below (optional)

    FEATURES:
    - Users can like magazines
    - Download for offline reading
    - Screenshot protection (DRM)
    """
    inlines = [MagazineImageInline]
    list_display = ['title', 'publish_date', 'is_featured', 'page_count', 'view_count', 'like_count']
    list_filter = ['is_featured', 'publish_date']
    list_editable = ['is_featured']
    search_fields = ['title', 'title_fr', 'description']
    date_hierarchy = 'publish_date'

    fieldsets = (
        ('Magazine Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
                'cover_image',
            ],
        }),
        ('PDF File', {
            'fields': [
                'pdf_file',
                ('page_count', 'file_size'),
            ],
        }),
        ('Publishing', {
            'fields': [
                'publish_date',
                'is_featured',
            ],
        }),
    )


@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    """
    VIDEOS - Video content library

    HELP:
    Videos appear in the Videos section of the app.

    HOW TO USE:
    1. Add a title and description
    2. Upload a thumbnail image
    3. Add the video URL (YouTube, Vimeo, or direct link)
    4. Choose a category
    5. Set duration (e.g., "5:30" or "1h 20m")

    VIDEO URL:
    Can be YouTube, Vimeo, or direct video file URL.
    The app will automatically detect the type and play it correctly.
    """
    list_display = ['title', 'thumbnail_preview', 'category', 'duration', 'view_count', 'like_count']
    list_filter = ['category', 'created_at']
    search_fields = ['title', 'title_fr', 'description']
    date_hierarchy = 'created_at'

    fieldsets = (
        ('Video Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
                'thumbnail',
            ],
        }),
        ('Video Source', {
            'fields': [
                'video_url',
                'category',
                'duration',
            ],
        }),
    )

    def thumbnail_preview(self, obj):
        if obj.thumbnail:
            return format_html('<img src="{}" style="max-height:50px; border-radius:4px;" />', obj.thumbnail.url)
        return '-'
    thumbnail_preview.short_description = 'Thumbnail'


# ═══════════════════════════════════════════════════════════════
#  GALLERY
# ═══════════════════════════════════════════════════════════════

class GalleryPhotoInline(admin.TabularInline):
    model = GalleryPhoto
    extra = 3
    fields = ['image', 'caption', 'caption_fr', 'display_order']


@admin.register(GalleryAlbum)
class GalleryAlbumAdmin(admin.ModelAdmin):
    """
    PHOTO GALLERY - Photo albums

    HELP:
    Photo albums allow you to organize photos into collections.
    Users can browse albums and download them for offline viewing.

    HOW TO USE:
    1. Create an album with title and description
    2. Upload a cover image
    3. Check "is featured" to highlight the album
    4. Add photos in the Photos section below

    FEATURES:
    - Offline download with DRM protection
    - Users can view photos in fullscreen
    - Captions support bilingual text
    """
    inlines = [GalleryPhotoInline]
    list_display = ['title', 'cover_preview', 'is_featured', 'photo_count', 'view_count', 'like_count', 'created_at']
    list_filter = ['is_featured', 'created_at']
    list_editable = ['is_featured']
    search_fields = ['title', 'title_fr', 'description']
    date_hierarchy = 'created_at'

    fieldsets = (
        ('Album Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
                'cover_image',
                'is_featured',
            ],
        }),
    )

    def cover_preview(self, obj):
        if obj.cover_image:
            return format_html('<img src="{}" style="max-height:50px; border-radius:4px;" />', obj.cover_image.url)
        return '-'
    cover_preview.short_description = 'Cover'


# ═══════════════════════════════════════════════════════════════
#  NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    """
    PUSH NOTIFICATIONS - Send notifications to users

    HELP:
    Send push notifications to inform users about news, events, or updates.

    HOW TO USE:
    1. Choose a notification type (article, event, magazine, etc.)
    2. Write the title and message in English and French
    3. Choose who should receive it:
       - All users (check "is global")
       - Specific filters (gender, nationality, age, badge)
       - Specific users (select individually)
    4. Optionally add an image for rich push notifications
    5. Optionally set an action (URL or app route) for tap behavior
    6. Check "is active" to make it visible in the app
    7. Save the notification, then select it and use the
       "Send push notification now" action to deliver it

    SCHEDULING:
    Instead of sending immediately, you can schedule notifications:
    - Set "scheduled at" for a one-time future send
    - Check "is scheduled" and choose a schedule type for recurring sends
    - The Celery Beat task will pick up and send scheduled notifications

    NOTE:
    After sending, check push_sent, push_recipient_count, and open_rate
    in the list view or read-only fields to monitor delivery.
    """
    list_display = ['title', 'notification_type', 'targeting_info', 'push_status', 'is_active', 'created_at']
    list_filter = ['notification_type', 'is_active', 'is_global', 'push_sent', 'target_language', 'created_at']
    search_fields = ['title', 'title_fr', 'message']
    filter_horizontal = ['target_users']
    date_hierarchy = 'created_at'
    readonly_fields = ['push_sent', 'push_sent_at', 'push_recipient_count', 'push_recipient_en', 'push_recipient_fr']
    actions = ['send_push_now']

    fieldsets = (
        ('Notification Content', {
            'fields': [
                'notification_type',
                ('title', 'title_fr'),
                ('message', 'message_fr'),
                'image',
            ],
        }),
        ('Tap Action', {
            'fields': [
                'action_type',
                'action_value',
            ],
            'description': 'What happens when the user taps the notification. Leave as "No Action" for default behavior.',
            'classes': ['collapse'],
        }),
        ('Targeting - Who Should See This?', {
            'fields': [
                'is_global',
                'target_gender',
                'target_language',
                'target_nationalities',
                ('target_age_min', 'target_age_max'),
                ('target_verified_only', 'target_badge_type'),
                'target_users',
            ],
            'description': 'Check "is global" to send to everyone, or use filters below for specific groups.',
        }),
        ('Scheduling', {
            'fields': [
                'scheduled_at',
                'is_scheduled',
                'schedule_type',
                'schedule_day',
                'schedule_time',
            ],
            'description': 'Leave blank to send manually via the "Send push notification now" action. Or set a schedule for automatic sending.',
            'classes': ['collapse'],
        }),
        ('Push Delivery Status', {
            'fields': [
                'push_sent',
                'push_sent_at',
                ('push_recipient_count', 'push_recipient_en', 'push_recipient_fr'),
            ],
        }),
        ('Settings', {
            'fields': [
                'is_active',
            ],
        }),
    )

    def push_status(self, obj):
        if obj.push_sent:
            return format_html(
                '<span style="color: green;">Sent</span> ({} devices)',
                obj.push_recipient_count,
            )
        if obj.scheduled_at:
            return format_html(
                '<span style="color: orange;">Scheduled</span> ({})',
                obj.scheduled_at.strftime('%Y-%m-%d %H:%M'),
            )
        return format_html('<span style="color: gray;">Not sent</span>')
    push_status.short_description = 'Push Status'

    def targeting_info(self, obj):
        if obj.is_global:
            return 'All Users'
        filters = []
        if obj.target_gender:
            filters.append(obj.target_gender)
        if obj.target_nationalities:
            filters.append(f'{len(obj.target_nationalities)} countries')
        if obj.target_age_min or obj.target_age_max:
            filters.append(f'Age {obj.target_age_min or "any"}-{obj.target_age_max or "any"}')
        if obj.target_users.exists():
            filters.append(f'{obj.target_users.count()} users')
        return ', '.join(filters) if filters else 'No filters'
    targeting_info.short_description = 'Targeting'

    @admin.action(description='Send push notification now')
    def send_push_now(self, request, queryset):
        from core.push_service import send_push_notification

        sent_count = 0
        skipped_count = 0
        errors = []

        for notification in queryset:
            if notification.push_sent:
                skipped_count += 1
                continue
            try:
                success, failure = send_push_notification(notification)
                sent_count += 1
            except Exception as e:
                errors.append(f'"{notification.title}": {e}')

        parts = []
        if sent_count:
            parts.append(f'{sent_count} notification(s) sent successfully.')
        if skipped_count:
            parts.append(f'{skipped_count} skipped (already sent).')
        if errors:
            parts.append(f'Errors: {"; ".join(errors)}')

        msg = ' '.join(parts) if parts else 'No notifications processed.'
        if errors:
            from django.contrib import messages as django_messages
            self.message_user(request, msg, django_messages.WARNING)
        else:
            self.message_user(request, msg)
    send_push_now.short_description = 'Send push notification now'


# ═══════════════════════════════════════════════════════════════
#  LOCATIONS & EVENTS
# ═══════════════════════════════════════════════════════════════

@admin.register(EmbassyLocation)
class EmbassyAdmin(admin.ModelAdmin):
    """
    EMBASSY LOCATIONS - Embassy and consulate information

    HELP:
    Store information about embassies and consulates.
    Users can view locations on a map and get directions.

    HOW TO USE:
    1. Add embassy name and address
    2. Set country and city
    3. Add contact information (phone, email, website)
    4. Add GPS coordinates for map display

    GPS COORDINATES:
    Get coordinates from Google Maps:
    - Right-click on the location
    - Click on the coordinates to copy them
    - Paste latitude and longitude here
    """
    list_display = ['name', 'city', 'country', 'phone_number', 'email']
    list_filter = ['country', 'city']
    search_fields = ['name', 'name_fr', 'city', 'country', 'address']

    fieldsets = (
        ('Embassy Information', {
            'fields': [
                ('name', 'name_fr'),
                'address',
                ('city', 'country'),
            ],
        }),
        ('Contact Information', {
            'fields': [
                ('phone_number', 'email'),
                'website',
            ],
        }),
        ('Map Location', {
            'fields': [
                ('latitude', 'longitude'),
            ],
            'description': 'GPS coordinates for map display. Get from Google Maps.',
        }),
    )


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    """
    CALENDAR EVENTS - Important dates and events

    HELP:
    Events appear in the Calendar section of the app.
    Users can add them to their device calendar.

    HOW TO USE:
    1. Add event name and description
    2. Set the event date and time
    3. Add location/address
    4. Add GPS coordinates (optional, for map)
    5. Upload an image (optional)

    FEATURES:
    - Users can set reminders
    - Add to iOS Calendar, Google Calendar, Outlook
    - View location on map
    """
    list_display = ['name', 'event_date', 'address', 'created_at']
    list_filter = ['event_date', 'created_at']
    search_fields = ['name', 'name_fr', 'address', 'description']
    date_hierarchy = 'event_date'

    fieldsets = (
        ('Event Information', {
            'fields': [
                ('name', 'name_fr'),
                ('description', 'description_fr'),
                'event_date',
            ],
        }),
        ('Location', {
            'fields': [
                'address',
                ('latitude', 'longitude'),
            ],
        }),
        ('Media', {
            'fields': ['image'],
            'classes': ('collapse',),
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  LIVE FEEDS & RESOURCES
# ═══════════════════════════════════════════════════════════════

@admin.register(LiveFeed)
class LiveFeedAdmin(admin.ModelAdmin):
    """
    LIVE FEEDS - Live streams and videos

    HELP:
    Manage live streams, upcoming broadcasts, and recorded videos.

    STATUS:
    - Live: Currently streaming
    - Upcoming: Scheduled for future
    - Recorded: Past broadcast/recording

    HOW TO USE:
    1. Add title and description
    2. Upload thumbnail image
    3. Add stream URL (YouTube Live, Vimeo, etc.)
    4. Set status (live/upcoming/recorded)
    5. Set scheduled time for upcoming streams
    6. Set duration for recorded videos

    The app will automatically show a "LIVE" badge for live streams.
    """
    list_display = ['title', 'status', 'scheduled_time', 'viewer_count', 'created_at']
    list_filter = ['status', 'scheduled_time', 'created_at']
    search_fields = ['title', 'title_fr', 'description']
    date_hierarchy = 'scheduled_time'

    fieldsets = (
        ('Stream Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
                'thumbnail',
            ],
        }),
        ('Stream Settings', {
            'fields': [
                'stream_url',
                ('status', 'scheduled_time'),
                'duration',
            ],
        }),
    )


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    """
    RESOURCES - Downloadable files and documents

    HELP:
    Provide downloadable resources like PDFs, documents, guides, etc.

    CATEGORIES:
    - Official Documents: Government documents, official papers
    - Country Information: Tourist guides, maps, general info
    - Media Resources: Press kits, logos, media files
    - Reference Guides: Manuals, handbooks, guides

    HOW TO USE:
    1. Add title and description
    2. Choose category
    3. Choose file type (PDF or ZIP)
    4. Upload the file
    5. Enter file size (e.g., "2.5 MB")

    Users can download these files in the Resources section.
    """
    list_display = ['title', 'category', 'file_type', 'file_size']
    list_filter = ['category', 'file_type']
    search_fields = ['title', 'title_fr', 'description']

    fieldsets = (
        ('Resource Information', {
            'fields': [
                ('title', 'title_fr'),
                ('description', 'description_fr'),
            ],
        }),
        ('File', {
            'fields': [
                ('category', 'file_type'),
                'file',
                'file_size',
            ],
        }),
    )


# ═══════════════════════════════════════════════════════════════
#  OTHER SETTINGS
# ═══════════════════════════════════════════════════════════════

@admin.register(WeatherCity)
class WeatherCityAdmin(admin.ModelAdmin):
    """
    WEATHER CITIES - Cities shown in weather section

    HELP:
    Configure which cities appear in the weather section.

    HOW TO USE:
    1. Add city name
    2. Add GPS coordinates (latitude/longitude)
    3. Upload background image (optional)
    4. Check "is default" for main city (Bujumbura)
    5. Check "is active" to show in app
    6. Set order to control display position

    GPS COORDINATES:
    The app uses coordinates to fetch weather data from Open-Meteo API.
    Get coordinates from Google Maps.
    """
    list_display = ['name', 'is_default', 'is_active', 'order']
    list_editable = ['is_default', 'is_active', 'order']
    list_filter = ['is_default', 'is_active']

    fieldsets = (
        ('City Information', {
            'fields': [
                'name',
                'background_image',
            ],
        }),
        ('Location', {
            'fields': [
                ('latitude', 'longitude'),
            ],
            'description': 'GPS coordinates for weather API',
        }),
        ('Display Settings', {
            'fields': [
                ('order', 'is_default', 'is_active'),
            ],
            'description': 'Default cities cannot be removed by users in the app',
        }),
    )


@admin.register(PriorityAgenda)
class PriorityAgendaAdmin(admin.ModelAdmin):
    """
    PRIORITY AGENDAS - Key focus areas and initiatives

    HELP:
    Priority agendas are the main focus areas of the Burundi Chairmanship.
    Examples: Water & Sanitation, Economic Development, Peace & Security

    HOW TO USE:
    1. Add title and description
    2. Create a unique slug (URL-friendly name)
    3. Upload hero image
    4. Add detailed content in Overview and Objectives sections

    SLUG:
    The slug is used in URLs. Use lowercase letters and hyphens.
    Example: "water-sanitation", "economic-development"
    """
    list_display = ['title', 'slug']
    search_fields = ['title', 'title_fr', 'slug', 'description']
    prepopulated_fields = {'slug': ('title',)}

    fieldsets = (
        ('Basic Information', {
            'fields': [
                ('title', 'title_fr'),
                'slug',
                ('description', 'description_fr'),
                'hero_image',
            ],
        }),
        ('Detailed Content', {
            'fields': [
                ('overview', 'overview_fr'),
                ('objectives', 'objectives_fr'),
                ('current_initiatives', 'current_initiatives_fr'),
            ],
            'classes': ('collapse',),
        }),
    )


@admin.register(SocialMediaLink)
class SocialMediaAdmin(admin.ModelAdmin):
    """
    SOCIAL MEDIA LINKS - Social media accounts

    HELP:
    Add links to official social media accounts.
    These appear in the app footer and More section.

    PLATFORMS:
    Facebook, Twitter, Instagram, YouTube, LinkedIn, TikTok
    """
    list_display = ['platform', 'url', 'display_order']
    list_editable = ['display_order']
    list_filter = ['platform']


@admin.register(AppSettings)
class AppSettingsAdmin(admin.ModelAdmin):
    """
    APP SETTINGS - General app configuration

    HELP:
    Global settings for the app.

    IMPORTANT:
    Only one settings record should exist.
    Edit the existing record instead of creating a new one.
    """
    fieldsets = (
        ('Summit Information', {
            'fields': [
                'summit_year',
                ('summit_theme', 'summit_theme_fr'),
            ],
        }),
        ('About Page', {
            'description': 'These fields control what appears in the About dialog inside the app.',
            'fields': [
                ('app_description', 'app_description_fr'),
                'developer_name',
                'developer_url',
            ],
        }),
        ('Social Media & Links', {
            'fields': [
                'website_url',
                'facebook_url',
                'twitter_url',
                'instagram_url',
            ],
        }),
    )

    def has_add_permission(self, request):
        return not AppSettings.objects.exists()


# ═══════════════════════════════════════════════════════════════
#  VERIFICATION SYSTEM
# ═══════════════════════════════════════════════════════════════

class VerificationSocialMediaInline(admin.TabularInline):
    """Inline admin for social media profiles in verification requests"""
    model = VerificationSocialMedia
    extra = 0
    fields = ['platform', 'username_or_url']
    verbose_name = 'Social Media Profile'
    verbose_name_plural = 'Social Media Profiles'


@admin.register(VerificationRequest)
class VerificationRequestAdmin(admin.ModelAdmin):
    """
    VERIFICATION REQUESTS - Review and approve/reject user verification badges

    HELP:
    Users submit verification requests to receive Gold or Blue badges.
    Review their professional email, phone, social media, and reasoning.

    HOW TO APPROVE/REJECT:
    1. Click on a verification request to open it
    2. Review the applicant's information, documents, and social media
    3. In the "Admin Review" section:
       - Set Status to "Approved" and choose a Badge Type (Gold or Blue)
       - OR set Status to "Rejected" and write a rejection reason
    4. Click Save — the user's profile will be updated automatically

    STATUS:
    - Pending: Waiting for your review
    - Approved: Badge granted (user profile updated automatically)
    - Rejected: Request denied (user can appeal)
    - Appealed: User submitted appeal after rejection
    """
    list_display = ['full_name', 'user', 'status_badge', 'badge_type_display', 'email',
                    'phone_number', 'position_role', 'created_at']
    list_filter = ['status', 'badge_type', 'created_at']
    search_fields = ['full_name', 'first_name', 'last_name', 'email', 'user__email',
                     'user__username', 'position_role']
    readonly_fields = ['user', 'title', 'first_name', 'last_name', 'full_name', 'gender',
                       'email', 'email_verified', 'country_code', 'phone_number', 'phone_verified',
                       'position_role', 'reasoning_message', 'supporting_document',
                       'created_at', 'updated_at', 'reviewed_at', 'appeal_submitted_at',
                       'appeal_message', 'user_verification_status']
    date_hierarchy = 'created_at'
    inlines = [VerificationSocialMediaInline]
    actions = ['approve_with_blue_badge', 'approve_with_gold_badge', 'reject_selected']

    fieldsets = (
        ('Personal Information', {
            'fields': [
                'user',
                ('title', 'first_name', 'last_name'),
                'full_name',
                'gender',
                'position_role',
                'supporting_document',
            ],
        }),
        ('Contact Information', {
            'fields': [
                ('email', 'email_verified'),
                ('country_code', 'phone_number', 'phone_verified'),
            ],
        }),
        ('Reasoning', {
            'fields': ['reasoning_message'],
        }),
        ('Admin Review', {
            'fields': [
                'user_verification_status',
                ('status', 'badge_type'),
                'rejection_reason',
                ('reviewed_by', 'reviewed_at'),
            ],
            'description': 'Set status to Approved + choose badge type, OR set to Rejected + write reason. '
                           'The user profile is updated automatically on save.',
        }),
        ('Appeal', {
            'fields': ['appeal_message', 'appeal_submitted_at'],
            'classes': ('collapse',),
        }),
        ('Timestamps', {
            'fields': ['created_at', 'updated_at'],
            'classes': ('collapse',),
        }),
    )

    def status_badge(self, obj):
        colors = {
            'pending': '#FFA500',
            'approved': '#28A745',
            'rejected': '#DC3545',
            'appealed': '#6C757D',
        }
        return format_html(
            '<span style="background:{}; color:white; padding:3px 10px; border-radius:3px; font-size:11px; font-weight:600;">{}</span>',
            colors.get(obj.status, '#666'),
            obj.get_status_display().upper()
        )
    status_badge.short_description = 'Status'

    def badge_type_display(self, obj):
        if not obj.badge_type:
            return '-'
        colors = {'GOLD': '#DAA520', 'BLUE': '#1E88E5'}
        return format_html(
            '<span style="background:{}; color:white; padding:3px 10px; border-radius:3px; font-size:11px; font-weight:600;">{}</span>',
            colors.get(obj.badge_type, '#666'),
            obj.badge_type
        )
    badge_type_display.short_description = 'Badge'

    def user_verification_status(self, obj):
        """Show current user profile verification state for context."""
        if not hasattr(obj.user, 'profile'):
            return format_html('<span style="color:gray;">No profile found</span>')
        profile = obj.user.profile
        if profile.is_verified:
            badge = profile.badge_type or 'BLUE'
            return format_html(
                '<span style="color:green; font-weight:bold;">Verified ({} badge since {})</span>',
                badge, profile.verified_at.strftime('%Y-%m-%d') if profile.verified_at else 'unknown'
            )
        return format_html('<span style="color:orange;">Not verified</span>')
    user_verification_status.short_description = 'Current Profile Status'

    def save_model(self, request, obj, form, change):
        """
        When admin changes status to approved/rejected, automatically:
        - Call approve() to update user profile with badge
        - Call reject() to record rejection
        - Set reviewed_by and reviewed_at
        """
        if change and 'status' in form.changed_data:
            if obj.status == 'approved':
                # Use the model's approve() method to properly update user profile
                badge_type = obj.badge_type or 'BLUE'
                obj.approve(admin_user=request.user, badge_type=badge_type)
                self.message_user(
                    request,
                    format_html(
                        'Verification <strong>approved</strong> for {} with <strong>{}</strong> badge. '
                        'User profile has been updated.',
                        obj.full_name, badge_type
                    )
                )
                return  # approve() already saves the object
            elif obj.status == 'rejected':
                reason = obj.rejection_reason or 'No reason provided'
                obj.reject(admin_user=request.user, reason=reason)
                self.message_user(
                    request,
                    format_html(
                        'Verification <strong>rejected</strong> for {}.',
                        obj.full_name
                    )
                )
                return  # reject() already saves the object

        # For other changes (e.g., editing notes), just save normally
        if obj.status in ['approved', 'rejected'] and not obj.reviewed_at:
            obj.reviewed_at = timezone.now()
            obj.reviewed_by = request.user
        super().save_model(request, obj, form, change)

    def approve_with_blue_badge(self, request, queryset):
        count = 0
        for obj in queryset.filter(status__in=['pending', 'appealed']):
            obj.approve(admin_user=request.user, badge_type='BLUE')
            count += 1
        self.message_user(request, f'{count} request(s) approved with Blue badge.')
    approve_with_blue_badge.short_description = 'Approve selected with Blue badge'

    def approve_with_gold_badge(self, request, queryset):
        count = 0
        for obj in queryset.filter(status__in=['pending', 'appealed']):
            obj.approve(admin_user=request.user, badge_type='GOLD')
            count += 1
        self.message_user(request, f'{count} request(s) approved with Gold badge.')
    approve_with_gold_badge.short_description = 'Approve selected with Gold badge'

    def reject_selected(self, request, queryset):
        count = 0
        for obj in queryset.filter(status__in=['pending', 'appealed']):
            obj.reject(admin_user=request.user, reason='Rejected via bulk action. Please resubmit with additional documentation.')
            count += 1
        self.message_user(request, f'{count} request(s) rejected.')
    reject_selected.short_description = 'Reject selected requests'


# ═══════════════════════════════════════════════════════════════
#  HIDE TECHNICAL MODELS
# ═══════════════════════════════════════════════════════════════

# Hide Token Blacklist (technical authentication stuff)
try:
    from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
    admin.site.unregister(OutstandingToken)
    admin.site.unregister(BlacklistedToken)
except (ImportError, admin.sites.NotRegistered):
    pass


@admin.register(AuditLogEntry)
class AuditLogEntryAdmin(admin.ModelAdmin):
    list_display = ('timestamp', 'user', 'action', 'entity_type', 'entity_label', 'status')
    list_filter = ('action', 'status', 'entity_type')
    search_fields = ('entity_label', 'entity_type')
    readonly_fields = ('timestamp',)


class TicketMessageInline(admin.TabularInline):
    model = TicketMessage
    extra = 0
    readonly_fields = ('created_at',)


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ('subject', 'user', 'status', 'priority', 'created_at')
    list_filter = ('status', 'priority')
    search_fields = ('subject', 'user__username', 'user__email')
    readonly_fields = ('created_at', 'updated_at')
    inlines = [TicketMessageInline]


@admin.register(Popup)
class PopupAdmin(admin.ModelAdmin):
    """Admin interface for Popup/Announcement system"""
    list_display = ('title', 'popup_type', 'is_active', 'priority', 'show_once', 'expires_at', 'created_at')
    list_filter = ('is_active', 'popup_type', 'show_once')
    search_fields = ('title', 'title_fr', 'message', 'message_fr')
    readonly_fields = ('created_at', 'updated_at')
    fieldsets = (
        ('Content (English)', {
            'fields': ('title', 'message', 'action_text')
        }),
        ('Content (French)', {
            'fields': ('title_fr', 'message_fr', 'action_text_fr'),
            'classes': ('collapse',)
        }),
        ('Media & Action', {
            'fields': ('image', 'action_url')
        }),
        ('Settings', {
            'fields': ('popup_type', 'is_active', 'priority', 'show_once', 'expires_at')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    list_editable = ('is_active', 'priority')
    ordering = ('-priority', '-created_at')

    def get_fieldsets(self, request, obj=None):
        """Simplify fieldsets for add form"""
        if obj is None:
            return (
                ('Content (English)', {
                    'fields': ('title', 'message', 'action_text')
                }),
                ('Content (French)', {
                    'fields': ('title_fr', 'message_fr', 'action_text_fr')
                }),
                ('Media & Action', {
                    'fields': ('image', 'action_url')
                }),
                ('Settings', {
                    'fields': ('popup_type', 'is_active', 'priority', 'show_once', 'expires_at')
                }),
            )
        return super().get_fieldsets(request, obj)


@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'ip_address', 'country_name', 'city', 'user_nationality', 'device_os', 'is_active', 'terminated_at', 'created_at')
    list_filter = ('country_code', 'device_os', 'is_active', 'created_at')
    search_fields = ('ip_address', 'country_name', 'city', 'user__username')
    readonly_fields = ('created_at',)
    date_hierarchy = 'created_at'
    actions = ['terminate_selected_sessions']

    def terminate_selected_sessions(self, request, queryset):
        count = queryset.filter(is_active=True).update(is_active=False, terminated_at=timezone.now())
        self.message_user(request, f'{count} session(s) terminated.')
    terminate_selected_sessions.short_description = 'Terminate selected sessions'


@admin.register(LinkedAccount)
class LinkedAccountAdmin(admin.ModelAdmin):
    list_display = ('user', 'provider', 'email', 'display_name', 'is_primary', 'linked_at')
    list_filter = ('provider', 'is_primary')
    search_fields = ('user__username', 'user__email', 'email', 'provider_uid', 'display_name')
    readonly_fields = ('linked_at',)
    raw_id_fields = ('user',)
