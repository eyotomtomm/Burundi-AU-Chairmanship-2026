import io
import logging

from django.db import models
from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from PIL import Image as PILImage

from .validators import validate_image_file, validate_document_file, validate_fcm_token, validate_professional_email

logger = logging.getLogger(__name__)

# Content status choices used across multiple content models
CONTENT_STATUS_CHOICES = [
    ('draft', 'Draft'),
    ('scheduled', 'Scheduled'),
    ('published', 'Published'),
    ('archived', 'Archived'),
]

# All 55 African Union member states + key international nationalities
NATIONALITY_CHOICES = [
    # AU Member States (alphabetical)
    ('DZ', 'Algeria'), ('AO', 'Angola'), ('BJ', 'Benin'), ('BW', 'Botswana'),
    ('BF', 'Burkina Faso'), ('BI', 'Burundi'), ('CV', 'Cabo Verde'), ('CM', 'Cameroon'),
    ('CF', 'Central African Republic'), ('TD', 'Chad'), ('KM', 'Comoros'),
    ('CG', 'Congo (Brazzaville)'), ('CD', 'Congo (DRC)'), ('CI', "Côte d'Ivoire"),
    ('DJ', 'Djibouti'), ('EG', 'Egypt'), ('GQ', 'Equatorial Guinea'), ('ER', 'Eritrea'),
    ('SZ', 'Eswatini'), ('ET', 'Ethiopia'), ('GA', 'Gabon'), ('GM', 'Gambia'),
    ('GH', 'Ghana'), ('GN', 'Guinea'), ('GW', 'Guinea-Bissau'), ('KE', 'Kenya'),
    ('LS', 'Lesotho'), ('LR', 'Liberia'), ('LY', 'Libya'), ('MG', 'Madagascar'),
    ('MW', 'Malawi'), ('ML', 'Mali'), ('MR', 'Mauritania'), ('MU', 'Mauritius'),
    ('MA', 'Morocco'), ('MZ', 'Mozambique'), ('NA', 'Namibia'), ('NE', 'Niger'),
    ('NG', 'Nigeria'), ('RW', 'Rwanda'), ('ST', 'São Tomé and Príncipe'),
    ('SN', 'Senegal'), ('SC', 'Seychelles'), ('SL', 'Sierra Leone'), ('SO', 'Somalia'),
    ('ZA', 'South Africa'), ('SS', 'South Sudan'), ('SD', 'Sudan'),
    ('TZ', 'Tanzania'), ('TG', 'Togo'), ('TN', 'Tunisia'), ('UG', 'Uganda'),
    ('ZM', 'Zambia'), ('ZW', 'Zimbabwe'),
    # Key international
    ('BE', 'Belgium'), ('BR', 'Brazil'), ('CA', 'Canada'), ('CN', 'China'),
    ('FR', 'France'), ('DE', 'Germany'), ('IN', 'India'), ('JP', 'Japan'),
    ('RU', 'Russia'), ('SA', 'Saudi Arabia'), ('TR', 'Turkey'), ('AE', 'UAE'),
    ('GB', 'United Kingdom'), ('US', 'United States'),
    ('OTHER', 'Other'),
]


class UserProfile(models.Model):
    """Extended user profile with additional fields and verification status"""
    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    phone_number = models.CharField(max_length=20, blank=True)
    gender = models.CharField(max_length=20, choices=GENDER_CHOICES, blank=True)
    nationality = models.CharField(max_length=5, choices=NATIONALITY_CHOICES, blank=True, help_text='User nationality (ISO country code)')
    preferred_language = models.CharField(
        max_length=5,
        choices=[('en', 'English'), ('fr', 'French')],
        default='en',
        help_text='Preferred language for push notifications'
    )
    date_of_birth = models.DateField(blank=True, null=True, help_text='Date of birth for age-based targeting')
    profile_picture = models.ImageField(upload_to='profile_pictures/', blank=True, null=True, validators=[validate_image_file])

    # Firebase integration fields
    firebase_uid = models.CharField(
        max_length=128,
        unique=True,
        db_index=True,
        blank=True,
        null=True,
        help_text='Firebase user UID for authentication'
    )
    fcm_token = models.CharField(
        max_length=255,
        blank=True,
        validators=[validate_fcm_token],
        help_text='Firebase Cloud Messaging token for push notifications'
    )

    # Verification fields
    is_email_verified = models.BooleanField(default=False)
    is_government_official = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False, help_text='User has verified badge (approved by admin)')
    badge_type = models.CharField(
        max_length=10,
        choices=[('GOLD', 'Gold Badge'), ('BLUE', 'Blue Badge'), ('GREEN', 'Green Badge')],
        blank=True,
        null=True,
        help_text='Type of verification badge (Gold for VIPs, Blue for officials, Green for verified users)'
    )
    verification_requested_at = models.DateTimeField(null=True, blank=True, help_text='When user requested verification')
    email_verified_at = models.DateTimeField(null=True, blank=True)
    government_verified_at = models.DateTimeField(null=True, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True, help_text='When admin approved verification')

    # SMS notification fields
    sms_enabled = models.BooleanField(
        default=False,
        help_text='Enable SMS notifications for VIP/Government users'
    )

    # Account status fields
    is_deactivated = models.BooleanField(
        default=False,
        help_text='User chose "Take a Break" - account inactive until they log in again'
    )
    deactivated_at = models.DateTimeField(null=True, blank=True)
    is_scheduled_for_deletion = models.BooleanField(
        default=False,
        help_text='User requested account deletion - will be purged after 30 days'
    )
    deletion_requested_at = models.DateTimeField(null=True, blank=True)
    deletion_scheduled_for = models.DateTimeField(
        null=True, blank=True,
        help_text='Date when account will be permanently deleted'
    )

    # Newsletter preference
    receives_newsletter = models.BooleanField(default=True, help_text='User opted in for monthly newsletter')

    # Admin section permissions (staff users only; superusers have implicit full access)
    admin_sections = models.JSONField(
        default=list,
        blank=True,
        help_text='List of admin section keys this staff user can access. Ignored for superusers.'
    )

    # Device tracking
    device_type = models.CharField(max_length=50, blank=True, help_text='e.g. iPhone 15, Samsung Galaxy S24')
    device_os = models.CharField(max_length=50, blank=True, help_text='e.g. iOS 17.4, Android 14')
    app_version = models.CharField(max_length=20, blank=True, help_text='App build version')
    last_active = models.DateTimeField(null=True, blank=True, help_text='Last time user opened the app')

    # Additional metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'User Profile'
        verbose_name_plural = 'User Profiles'

    def __str__(self):
        return f"{self.user.username}'s Profile"


@receiver(post_save, sender=User)
def create_or_update_user_profile(sender, instance, created, **kwargs):
    """Automatically create/update profile when user is created/updated"""
    if created:
        UserProfile.objects.get_or_create(user=instance)
    else:
        # Ensure profile exists (handles legacy users created before this signal)
        profile, _ = UserProfile.objects.get_or_create(user=instance)
        profile.save()


class HeroSlide(models.Model):
    image = models.ImageField(upload_to='hero_slides/', validators=[validate_image_file])
    label = models.CharField(max_length=100)
    label_fr = models.CharField(max_length=100, blank=True)
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.label

    @property
    def thumbnail_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'thumb')

    @property
    def medium_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'medium')

    @property
    def large_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'large')


class MagazineEdition(models.Model):
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to='magazines/', validators=[validate_image_file])
    pdf_file = models.FileField(upload_to='magazines/pdfs/', blank=True, validators=[validate_document_file], help_text='Upload a PDF file')
    external_url = models.URLField(blank=True, help_text='External link to PDF (used if no file uploaded)')
    publish_date = models.DateField()
    is_featured = models.BooleanField(default=False)
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    page_count = models.PositiveIntegerField(default=0, help_text='Number of pages in the PDF')
    file_size = models.CharField(max_length=20, blank=True, help_text='e.g. 2.4 MB')
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this magazine (used when status=scheduled)'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-publish_date']
        indexes = [
            models.Index(fields=['-publish_date']),
            models.Index(fields=['is_featured', '-publish_date']),
            models.Index(fields=['status', '-publish_date']),
        ]

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        # Auto-generate cover image from PDF first page if cover is empty
        generate_cover = self.pdf_file and not self.cover_image
        super().save(*args, **kwargs)
        if generate_cover:
            self._generate_cover_from_pdf()

    def _generate_cover_from_pdf(self):
        """Render the first page of the uploaded PDF as a cover image."""
        try:
            import fitz  # PyMuPDF

            pdf_path = self.pdf_file.path
            doc = fitz.open(pdf_path)
            if doc.page_count == 0:
                doc.close()
                return

            page = doc[0]
            # Render at 2x for good quality (default is 72 dpi → 144 dpi)
            mat = fitz.Matrix(2.0, 2.0)
            pix = page.get_pixmap(matrix=mat)
            img_bytes = pix.tobytes("png")
            doc.close()

            # Auto-fill page_count if not set
            if self.page_count == 0:
                self.page_count = doc.page_count

            filename = f"cover_{self.pk}.png"
            self.cover_image.save(filename, ContentFile(img_bytes), save=False)
            # Save without triggering the cover generation again
            super(MagazineEdition, self).save(update_fields=['cover_image', 'page_count'])
            logger.info("Auto-generated cover for magazine '%s' from PDF", self.title)
        except ImportError:
            logger.warning("PyMuPDF not installed – skipping cover generation")
        except Exception as e:
            logger.error("Failed to generate cover from PDF for '%s': %s", self.title, e)

    @property
    def effective_pdf_url(self):
        """Returns pdf_file URL if available, otherwise external_url."""
        if self.pdf_file:
            return self.pdf_file.url
        return self.external_url or ''


class MagazineLike(models.Model):
    """Tracks which users liked which magazine editions."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='magazine_likes')
    edition = models.ForeignKey(MagazineEdition, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'edition')

    def __str__(self):
        return f"{self.user.username} likes {self.edition.title[:30]}"


class MagazineComment(models.Model):
    """User comments on magazine editions."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='magazine_comments')
    edition = models.ForeignKey(MagazineEdition, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies',
        help_text='Parent comment for threaded replies (1 level deep).'
    )
    content = models.TextField()
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['edition', '-created_at']),
            models.Index(fields=['parent']),
        ]

    def __str__(self):
        return f"{self.user.username} on {self.edition.title[:30]}"


class MagazineImage(models.Model):
    """Additional images for a magazine edition (shown in info bottom sheet)."""
    edition = models.ForeignKey(MagazineEdition, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='magazines/gallery/', validators=[validate_image_file])
    caption = models.CharField(max_length=300, blank=True)
    caption_fr = models.CharField(max_length=300, blank=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Magazine Image'
        verbose_name_plural = 'Magazine Images'

    def __str__(self):
        return f"{self.edition.title} - Image {self.pk}"


class Category(models.Model):
    name = models.CharField(max_length=50, unique=True)
    name_fr = models.CharField(max_length=50, blank=True)
    color = models.CharField(max_length=10, default='#1EB53A', help_text='Hex color e.g. #CE1126')
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name_plural = 'Categories'

    def __str__(self):
        return self.name


class Article(models.Model):
    CONTENT_TYPE_CHOICES = [('article', 'Article'), ('news', 'News')]

    title = models.CharField(max_length=300)
    title_fr = models.CharField(max_length=300, blank=True)
    content = models.TextField()
    content_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='articles/', blank=True, validators=[validate_image_file])
    author = models.CharField(max_length=100)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, null=True, blank=True, related_name='articles')
    publish_date = models.DateTimeField()
    content_type = models.CharField(
        max_length=10, choices=CONTENT_TYPE_CHOICES, default='article',
        help_text='Type of content: "article" for long-form articles, "news" for news items'
    )
    is_featured = models.BooleanField(default=False)
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this article (used when status=scheduled)'
    )
    scheduled_publish_at = models.DateTimeField(null=True, blank=True, help_text='Legacy: Schedule article for future publication. If set and in the future, article is hidden from public API.')
    expires_at = models.DateTimeField(null=True, blank=True, help_text='Auto-archive article after this date. Expired articles are hidden from public API but remain in the database.')
    is_draft = models.BooleanField(default=False, help_text='Legacy: Draft articles are hidden from the public API until published.')

    class Meta:
        ordering = ['-publish_date']
        indexes = [
            models.Index(fields=['-publish_date']),
            models.Index(fields=['is_featured', '-publish_date']),
            models.Index(fields=['is_draft', '-publish_date']),
            models.Index(fields=['status', '-publish_date']),
            models.Index(fields=['content_type', '-publish_date']),
        ]

    def __str__(self):
        return self.title

    @property
    def is_scheduled(self):
        """Check if article is scheduled for future publication."""
        if self.scheduled_publish_at is None and self.scheduled_publish_date is None:
            return False
        from django.utils import timezone
        sched = self.scheduled_publish_date or self.scheduled_publish_at
        return sched and sched > timezone.now()

    @property
    def is_expired(self):
        """Check if article has expired."""
        if self.expires_at is None:
            return False
        from django.utils import timezone
        return self.expires_at < timezone.now()

    @property
    def is_publicly_visible(self):
        """Check if article should be visible in public API."""
        if self.status in ('draft', 'scheduled', 'archived'):
            return False
        return not self.is_draft and not self.is_scheduled and not self.is_expired

    @property
    def thumbnail_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'thumb')

    @property
    def medium_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'medium')

    @property
    def large_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'large')


class ArticleComment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_comments')
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies',
        help_text='Parent comment for threaded replies (1 level deep).'
    )
    content = models.TextField()
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['article', '-created_at']),
            models.Index(fields=['parent']),
        ]

    def __str__(self):
        return f"{self.user.username} on {self.article.title[:30]}"


class ArticleCommentMention(models.Model):
    """Tracks @mentions in article comments (mirror of CommentMention for events)."""
    comment = models.ForeignKey(ArticleComment, on_delete=models.CASCADE, related_name='mentions')
    mentioned_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_comment_mentions')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('comment', 'mentioned_user')
        verbose_name = 'Article Comment Mention'
        verbose_name_plural = 'Article Comment Mentions'

    def __str__(self):
        return f"@{self.mentioned_user.username} in article comment #{self.comment_id}"


class ArticleLike(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_likes')
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'article')

    def __str__(self):
        return f"{self.user.username} likes {self.article.title[:30]}"


class ArticleMedia(models.Model):
    MEDIA_TYPE_CHOICES = [
        ('image', 'Image'),
        ('video', 'Video'),
    ]

    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='media')
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPE_CHOICES, default='image')
    image = models.ImageField(upload_to='article_media/', blank=True, validators=[validate_image_file])
    video_url = models.URLField(blank=True)
    caption = models.CharField(max_length=300, blank=True)
    caption_fr = models.CharField(max_length=300, blank=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name_plural = 'Article Media'

    def __str__(self):
        return f"{self.get_media_type_display()} for {self.article.title[:30]}"


class EmbassyLocation(models.Model):
    TYPE_CHOICES = [
        ('embassy', 'Embassy'),
        ('consulate', 'Consulate'),
        ('event_venue', 'Event Venue'),
        ('office', 'Office'),
    ]

    name = models.CharField(max_length=200)
    name_fr = models.CharField(max_length=200, blank=True)
    address = models.CharField(max_length=300)
    city = models.CharField(max_length=100)
    country = models.CharField(max_length=100)
    latitude = models.FloatField()
    longitude = models.FloatField()
    phone_number = models.CharField(max_length=50, blank=True)
    email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    opening_hours = models.CharField(max_length=200, blank=True)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='embassy')
    image = models.ImageField(upload_to='embassies/', blank=True, validators=[validate_image_file])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['country', 'city']
        verbose_name_plural = 'Embassy Locations'

    def __str__(self):
        return f"{self.name} - {self.city}, {self.country}"


class Event(models.Model):
    name = models.CharField(max_length=200)
    name_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    address = models.CharField(max_length=300)
    latitude = models.FloatField()
    longitude = models.FloatField()
    event_date = models.DateTimeField()
    image = models.ImageField(upload_to='events/', blank=True, validators=[validate_image_file])
    is_active = models.BooleanField(default=True, help_text='When off, event is hidden from the app')
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this event (used when status=scheduled)'
    )

    # Engagement
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)

    # Recurrence fields
    RECURRENCE_CHOICES = [
        ('none', 'None'),
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    ]
    recurrence_type = models.CharField(
        max_length=10,
        choices=RECURRENCE_CHOICES,
        default='none',
        help_text='Recurrence pattern for the event'
    )
    recurrence_end_date = models.DateField(
        null=True,
        blank=True,
        help_text='When the recurring series ends'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['event_date']
        indexes = [
            models.Index(fields=['is_active', 'event_date']),
            models.Index(fields=['status', 'event_date']),
        ]

    def __str__(self):
        return self.name


class LiveFeed(models.Model):
    STATUS_CHOICES = [
        ('live', 'Live'),
        ('upcoming', 'Upcoming'),
        ('recorded', 'Recorded'),
    ]
    STREAM_TYPE_CHOICES = [
        ('video', 'Video'),
        ('youtube', 'YouTube'),
        ('zoom', 'Zoom'),
        ('teams', 'Microsoft Teams'),
        ('webex', 'Webex'),
        ('meet', 'Google Meet'),
        ('external', 'External Link'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    event = models.ForeignKey(
        'Event', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='live_feeds',
        help_text='Optional — link this webinar to an event so it inherits the event\'s speakers.',
    )
    stream_url = models.URLField()
    stream_type = models.CharField(
        max_length=20, choices=STREAM_TYPE_CHOICES, default='video',
        help_text='Auto-detected from URL on save. External platforms open in their app.',
    )
    meeting_id = models.CharField(max_length=100, blank=True, help_text='Meeting ID for Zoom/Teams/Webex (shown to users)')
    passcode = models.CharField(max_length=100, blank=True, help_text='Meeting passcode (shown to users)')
    thumbnail = models.ImageField(upload_to='live_feeds/', blank=True, validators=[validate_image_file])
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='upcoming')
    viewer_count = models.IntegerField(default=0)
    view_count = models.PositiveIntegerField(default=0)
    duration = models.CharField(max_length=50, blank=True, help_text='e.g. 1h 30m')
    scheduled_time = models.DateTimeField(null=True, blank=True)
    content_status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Publishing workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this live feed (used when content_status=scheduled)'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['content_status', '-created_at']),
        ]

    def __str__(self):
        return f"[{self.get_status_display()}] {self.title}"

    def save(self, *args, **kwargs):
        # Auto-detect stream type from URL
        url = self.stream_url.lower()
        if 'zoom.us' in url or 'zoom.com' in url:
            self.stream_type = 'zoom'
        elif 'youtube.com' in url or 'youtu.be' in url:
            self.stream_type = 'youtube'
        elif 'teams.microsoft.com' in url or 'teams.live.com' in url:
            self.stream_type = 'teams'
        elif 'webex.com' in url:
            self.stream_type = 'webex'
        elif 'meet.google.com' in url:
            self.stream_type = 'meet'
        else:
            self.stream_type = 'video'
        super().save(*args, **kwargs)


class Resource(models.Model):
    CATEGORY_CHOICES = [
        ('official_documents', 'Official Documents'),
        ('country_info', 'Country Information'),
        ('media', 'Media Resources'),
        ('reference', 'Reference Guides'),
    ]
    FILE_TYPE_CHOICES = [
        ('pdf', 'PDF'),
        ('zip', 'ZIP'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    file = models.FileField(upload_to='resources/', validators=[validate_document_file])
    file_size = models.CharField(max_length=20, help_text='e.g. 2.4 MB')
    file_type = models.CharField(max_length=10, choices=FILE_TYPE_CHOICES, default='pdf')
    view_count = models.PositiveIntegerField(default=0)
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this resource (used when status=scheduled)'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['category', 'title']
        indexes = [
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return self.title


class FeatureCard(models.Model):
    ACTION_TYPE_CHOICES = [
        ('none', 'No Action'),
        ('url', 'External URL'),
        ('route', 'App Route'),
    ]

    ICON_CHOICES = [
        ('stars', 'Stars'),
        ('travel_explore', 'Travel / Explore'),
        ('public', 'Globe / Public'),
        ('security', 'Security / Shield'),
        ('groups', 'Groups / People'),
        ('gavel', 'Gavel / Justice'),
        ('handshake', 'Handshake'),
        ('trending_up', 'Trending Up / Growth'),
        ('auto_stories', 'Book / Stories'),
        ('campaign', 'Campaign / Megaphone'),
        ('flag', 'Flag'),
        ('workspace_premium', 'Premium / Award'),
        ('landscape', 'Landscape / Nature'),
        ('music_note', 'Music Note'),
        ('restaurant', 'Restaurant / Food'),
        ('diversity_3', 'Diversity / Community'),
        ('water_drop', 'Water Drop'),
        ('health_and_safety', 'Health & Safety'),
        ('school', 'School / Education'),
        ('agriculture', 'Agriculture'),
        ('business', 'Business / Trade'),
        ('computer', 'Computer / Digital'),
        ('factory', 'Factory / Industry'),
        ('local_shipping', 'Shipping / Transport'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='feature_cards/', blank=True, validators=[validate_image_file])
    gradient_start = models.CharField(max_length=10, default='#1EB53A', help_text='Hex color e.g. #1EB53A')
    gradient_end = models.CharField(max_length=10, default='#4CAF50', help_text='Hex color e.g. #4CAF50')
    icon_name = models.CharField(max_length=50, blank=True, choices=ICON_CHOICES, help_text='Fallback icon if no image is uploaded')
    icon_image = models.ImageField(upload_to='feature_cards/icons/', blank=True, validators=[validate_image_file],
                                   help_text='Upload a custom icon image (PNG/SVG recommended). Overrides icon_name.')
    action_type = models.CharField(max_length=10, choices=ACTION_TYPE_CHOICES, default='none', help_text='Leave as "No Action" to open detail page. Use URL/Route only for special redirects.')
    action_value = models.CharField(max_length=500, blank=True, help_text='Only needed for URL or Route overrides. Leave blank for normal cards.')

    # Rich content fields for detail page
    overview = models.TextField(blank=True, help_text='Extended description for the detail page')
    overview_fr = models.TextField(blank=True)
    key_points = models.JSONField(default=list, blank=True, help_text='List of bullet point strings, e.g. ["Point one", "Point two"]')
    key_points_fr = models.JSONField(default=list, blank=True)
    impact_areas = models.JSONField(
        default=list, blank=True,
        help_text='List of impact areas. Each item: {"icon": "icon_name", "title": "Title", "description": "Description"}. '
                  'Available icons: stars, public, security, groups, trending_up, landscape, music_note, restaurant, '
                  'diversity_3, health_and_safety, school, agriculture, business, computer, factory, local_shipping'
    )
    impact_areas_fr = models.JSONField(default=list, blank=True)
    extra_content = models.TextField(blank=True, help_text='Additional text section for the detail page')
    extra_content_fr = models.TextField(blank=True)

    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    view_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def save(self, *args, **kwargs):
        if not self.gradient_start:
            self.gradient_start = '#1EB53A'
        if not self.gradient_end:
            self.gradient_end = '#4CAF50'
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title


class FeatureCardKeyPoint(models.Model):
    """Individual key point for a feature card — replaces JSON key_points field."""
    feature_card = models.ForeignKey(FeatureCard, on_delete=models.CASCADE, related_name='key_point_items')
    text = models.CharField(max_length=500)
    text_fr = models.CharField(max_length=500, blank=True)
    order = models.IntegerField(default=0)

    class Meta:
        ordering = ['order']
        verbose_name = 'Key Point'
        verbose_name_plural = 'Key Points'

    def __str__(self):
        return self.text[:60]


class FeatureCardImpactArea(models.Model):
    """Individual impact area for a feature card — replaces JSON impact_areas field."""
    ICON_CHOICES = FeatureCard.ICON_CHOICES

    feature_card = models.ForeignKey(FeatureCard, on_delete=models.CASCADE, related_name='impact_area_items')
    icon_name = models.CharField(max_length=50, choices=ICON_CHOICES, default='stars')
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    order = models.IntegerField(default=0)

    class Meta:
        ordering = ['order']
        verbose_name = 'Impact Area'
        verbose_name_plural = 'Impact Areas'

    def __str__(self):
        return self.title


class FeatureCardMedia(models.Model):
    """Photo/video attachments for a feature card detail page.

    Each row is either an image or a video.
    Images can be uploaded files OR external URLs.
    Videos can be uploaded files OR external URLs (YouTube, etc.).
    """
    MEDIA_TYPE_CHOICES = [
        ('image', 'Image'),
        ('video', 'Video'),
    ]

    feature_card = models.ForeignKey(FeatureCard, on_delete=models.CASCADE, related_name='media')
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPE_CHOICES, default='image')

    # Image source — upload OR external link
    image = models.ImageField(upload_to='feature_card_media/', blank=True, validators=[validate_image_file],
                              help_text='Upload an image file, OR paste a URL below')
    image_url = models.URLField(blank=True, help_text='External image URL (used if no file uploaded)')

    # Video source — upload OR external link
    video_file = models.FileField(upload_to='feature_card_media/videos/', blank=True,
                                  help_text='Upload a video file (MP4, MOV, etc.), OR paste a URL below')
    video_url = models.URLField(blank=True, help_text='YouTube/external video URL (used if no file uploaded)')

    caption = models.CharField(max_length=300, blank=True)
    caption_fr = models.CharField(max_length=300, blank=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Feature Card Media'
        verbose_name_plural = 'Feature Card Media'

    def __str__(self):
        return f"{self.get_media_type_display()} for {self.feature_card.title[:30]}"

    @property
    def effective_image_url(self):
        """Return uploaded image URL if available, otherwise external URL."""
        if self.image:
            return self.image.url
        return self.image_url or ''

    @property
    def effective_video_url(self):
        """Return uploaded video file URL if available, otherwise external URL."""
        if self.video_file:
            return self.video_file.url
        return self.video_url or ''


class EventCategory(models.Model):
    name = models.CharField(max_length=100)
    name_fr = models.CharField(max_length=100, blank=True)
    icon_name = models.CharField(max_length=50, default='event', help_text='Material icon name')
    color = models.CharField(max_length=7, default='#1B5E20', help_text='Hex color')
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['order', 'name']
        verbose_name = 'Event Category'
        verbose_name_plural = 'Event Categories'


class EventRegistration(models.Model):
    """Standalone event registration — no longer tied to FeatureCard"""
    CARD_TYPE_CHOICES = [
        ('event', 'Event Registration'),
        ('greeting', 'Greeting/Holiday Wish'),
        ('announcement', 'General Announcement'),
        ('survey', 'Survey/Feedback'),
    ]

    card_type = models.CharField(max_length=20, choices=CARD_TYPE_CHOICES, default='event')

    EVENT_TYPE_CHOICES = [
        ('in_person', 'In Person'),
        ('online', 'Online / Webinar'),
        ('hybrid', 'Hybrid'),
        ('info', 'Information Only'),
    ]
    event_type = models.CharField(max_length=20, choices=EVENT_TYPE_CHOICES, default='in_person')
    category = models.ForeignKey(EventCategory, on_delete=models.SET_NULL, null=True, blank=True, related_name='events')

    # Event details
    event_title = models.CharField(max_length=300)
    event_title_fr = models.CharField(max_length=300, blank=True)
    event_description = models.TextField(blank=True)
    event_description_fr = models.TextField(blank=True)
    event_poster = models.ImageField(upload_to='event_posters/', blank=True, validators=[validate_image_file])

    # Date & venue
    event_date = models.DateTimeField(null=True, blank=True, help_text='Event start date/time (for countdown)')
    event_end_date = models.DateTimeField(null=True, blank=True, help_text='Event end date/time (multi-day events)')
    venue = models.CharField(max_length=300, blank=True, help_text='Venue name')
    venue_fr = models.CharField(max_length=300, blank=True)
    venue_address = models.CharField(max_length=500, blank=True, help_text='Full address for directions')

    # Contact
    contact_email = models.EmailField(blank=True, help_text='Contact email for "Contact Us" button')
    contact_phone = models.CharField(max_length=50, blank=True, help_text='Contact phone for "Contact Us" button')

    # Registration settings
    is_registration_enabled = models.BooleanField(default=True, help_text='Enable/disable registration form')
    registration_deadline = models.DateTimeField(blank=True, null=True)
    max_registrations = models.IntegerField(default=0, help_text='0 = unlimited')
    send_confirmation_email = models.BooleanField(default=True)
    confirmation_message = models.TextField(blank=True, help_text='Message sent to user after registration')
    confirmation_message_fr = models.TextField(blank=True)
    allow_proxy_registration = models.BooleanField(default=False, help_text='Allow users to register on behalf of others')

    # Feature toggles
    show_photos = models.BooleanField(default=True, help_text='Allow attendees to upload & view photos')
    show_attendees = models.BooleanField(default=True, help_text='Show attendee list & count')
    show_comments = models.BooleanField(default=True, help_text='Allow comments/discussion')

    # Display
    is_active = models.BooleanField(default=True, help_text='Show/hide in app')
    order = models.IntegerField(default=0, help_text='Display order (lower = first)')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.event_title} - {self.get_card_type_display()}"

    class Meta:
        ordering = ['order', '-created_at']
        verbose_name = 'Event Registration'
        verbose_name_plural = 'Event Registrations'
        indexes = [
            models.Index(fields=['is_active', 'order', '-created_at']),
        ]


class RegistrationFormField(models.Model):
    """Dynamic form fields for event registration"""
    FIELD_TYPE_CHOICES = [
        ('text', 'Text Input'),
        ('email', 'Email'),
        ('phone', 'Phone Number'),
        ('textarea', 'Text Area'),
        ('number', 'Number'),
        ('date', 'Date'),
        ('time', 'Time'),
        ('file', 'File Upload'),
        ('image', 'Image Upload'),
        ('select', 'Dropdown Select'),
        ('radio', 'Radio Buttons'),
        ('checkbox', 'Single Checkbox'),
        ('multi_checkbox', 'Multiple Checkboxes'),
        ('country', 'Country Selector'),
        ('nationality', 'Nationality'),
        ('passport', 'Passport Number'),
        ('url', 'URL / Website'),
    ]

    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='form_fields')
    field_type = models.CharField(max_length=20, choices=FIELD_TYPE_CHOICES)
    field_label = models.CharField(max_length=200, help_text='Label shown to user')
    field_label_fr = models.CharField(max_length=200, blank=True)
    field_name = models.CharField(max_length=100, help_text='Internal field name (e.g., "full_name", "passport_number")')
    placeholder = models.CharField(max_length=200, blank=True)
    placeholder_fr = models.CharField(max_length=200, blank=True)

    is_required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True, help_text='Show/hide this field')
    options = models.JSONField(default=list, blank=True, help_text='For select/radio/multi_checkbox: ["Option 1", "Option 2"]')
    validation_regex = models.CharField(max_length=500, blank=True, help_text='Optional regex for validation')
    help_text = models.CharField(max_length=300, blank=True)
    help_text_fr = models.CharField(max_length=300, blank=True)
    max_length = models.IntegerField(null=True, blank=True, help_text='Maximum character length (for textarea)')
    min_length = models.IntegerField(null=True, blank=True, help_text='Minimum character length (for textarea)')

    order = models.IntegerField(default=0)

    class Meta:
        ordering = ['order']
        verbose_name = 'Registration Form Field'
        verbose_name_plural = 'Registration Form Fields'

    def __str__(self):
        return f"{self.field_label} ({self.get_field_type_display()})"


class EventSubmission(models.Model):
    """User submissions for event registrations"""
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('waitlist', 'Waitlisted'),
    ]

    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='submissions')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_submissions')

    # Store all form data as JSON
    form_data = models.JSONField(default=dict, help_text='All form field values')

    # File uploads
    uploaded_files = models.JSONField(default=list, blank=True, help_text='List of uploaded file URLs')

    # Proxy registration fields
    is_proxy = models.BooleanField(default=False, help_text='Submitted on behalf of someone else')
    proxy_name = models.CharField(max_length=200, blank=True)
    proxy_email = models.EmailField(blank=True)
    proxy_phone = models.CharField(max_length=50, blank=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True, help_text='Internal notes from admin')

    # Waitlist & check-in fields
    is_waitlisted = models.BooleanField(default=False, help_text='True if placed on waitlist due to full capacity')
    checked_in_at = models.DateTimeField(null=True, blank=True, help_text='When attendee was checked in via QR')
    qr_ticket_hash = models.CharField(max_length=64, blank=True, db_index=True, help_text='SHA-256 hash for QR ticket validation')

    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(blank=True, null=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_submissions')

    class Meta:
        ordering = ['-submitted_at']
        verbose_name = 'Event Submission'
        verbose_name_plural = 'Event Submissions'
        indexes = [
            models.Index(fields=['status', '-submitted_at']),
            models.Index(fields=['is_proxy', '-submitted_at']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.event_registration.event_title}"

    def generate_qr_hash(self):
        """Generate a unique hash for QR ticket validation."""
        import hashlib
        raw = f"{self.id}:{self.user_id}:{self.event_registration_id}:{self.submitted_at}"
        self.qr_ticket_hash = hashlib.sha256(raw.encode()).hexdigest()[:32]
        return self.qr_ticket_hash

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # Auto-generate QR hash after first save (needs pk)
        if not self.qr_ticket_hash and self.pk:
            self.generate_qr_hash()
            EventSubmission.objects.filter(pk=self.pk).update(qr_ticket_hash=self.qr_ticket_hash)


class Notification(models.Model):
    """User notifications for important updates and announcements"""
    TYPE_CHOICES = [
        ('general', 'General Announcement'),
        ('article', 'New Article'),
        ('magazine', 'New Magazine'),
        ('event', 'Event Reminder'),
        ('system', 'System Update'),
    ]

    title = models.CharField(max_length=200, help_text='Notification title')
    title_fr = models.CharField(max_length=200, blank=True, help_text='French title')
    message = models.TextField(help_text='Notification message')
    message_fr = models.TextField(blank=True, help_text='French message')
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='general')

    # Optional link to content
    action_type = models.CharField(
        max_length=10,
        choices=[('none', 'No Action'), ('url', 'External URL'), ('route', 'App Route')],
        default='none',
        help_text='What happens when user taps notification'
    )
    action_value = models.CharField(
        max_length=500,
        blank=True,
        help_text='URL or route name (e.g., /news, /magazine)'
    )

    # Optional image attachment
    image = models.ImageField(
        upload_to='notifications/',
        blank=True,
        null=True,
        validators=[validate_image_file],
        help_text='Optional image shown in push notification and in-app list'
    )

    # Targeting
    is_global = models.BooleanField(
        default=True,
        help_text='Send to all users (uncheck to use filters below)'
    )
    target_users = models.ManyToManyField(
        User,
        blank=True,
        related_name='targeted_notifications',
        help_text='Specific users (optional, overrides filters)'
    )

    # Advanced targeting filters (only used if is_global=False and target_users is empty)
    target_gender = models.CharField(
        max_length=20,
        blank=True,
        choices=[('male', 'Male'), ('female', 'Female')],
        help_text='Filter by gender (leave blank for all)'
    )
    target_nationalities = models.JSONField(
        default=list,
        blank=True,
        help_text='Filter by nationalities (JSON list of ISO codes, empty = all)'
    )
    target_age_min = models.IntegerField(
        blank=True,
        null=True,
        help_text='Minimum age (leave blank for no limit)'
    )
    target_age_max = models.IntegerField(
        blank=True,
        null=True,
        help_text='Maximum age (leave blank for no limit)'
    )
    target_verified_only = models.BooleanField(
        default=False,
        help_text='Only send to verified users (blue or gold badge)'
    )
    target_badge_type = models.CharField(
        max_length=10,
        blank=True,
        choices=[('BLUE', 'Blue Badge'), ('GOLD', 'Gold Badge')],
        help_text='Filter by badge type (leave blank for any verified)'
    )
    target_language = models.CharField(
        max_length=5,
        blank=True,
        choices=[('', 'All Languages'), ('en', 'English Only'), ('fr', 'French Only')],
        default='',
        help_text='Send only to users with this language preference'
    )

    # Scheduling — one-time scheduled_at for backward compatibility
    scheduled_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text='Schedule notification for a future date/time. Leave blank to send immediately.'
    )

    # Recurring schedule fields
    SCHEDULE_TYPE_CHOICES = [
        ('once', 'One-time'),
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
    ]
    is_scheduled = models.BooleanField(
        default=False,
        help_text='Enable recurring schedule for this notification'
    )
    schedule_type = models.CharField(
        max_length=10,
        choices=SCHEDULE_TYPE_CHOICES,
        default='once',
        blank=True,
        help_text='How often to repeat this notification'
    )
    schedule_day = models.IntegerField(
        null=True,
        blank=True,
        help_text='Day of week for weekly schedule (0=Monday, 6=Sunday)'
    )
    schedule_time = models.TimeField(
        null=True,
        blank=True,
        help_text='Time of day to send the scheduled notification (HH:MM)'
    )
    last_scheduled_send = models.DateTimeField(
        null=True,
        blank=True,
        help_text='Last time this recurring notification was sent'
    )

    # Push notification tracking
    push_sent = models.BooleanField(default=False, help_text='Has push notification been sent?')
    push_sent_at = models.DateTimeField(blank=True, null=True)
    push_recipient_count = models.IntegerField(default=0, help_text='Number of users who received push')
    push_recipient_en = models.IntegerField(
        default=0,
        help_text='Number of devices that received the English version'
    )
    push_recipient_fr = models.IntegerField(
        default=0,
        help_text='Number of devices that received the French version'
    )
    opened_count = models.IntegerField(default=0, help_text='Number of times users opened/tapped this notification')

    # Status
    is_active = models.BooleanField(default=True, help_text='Active notifications appear in app')
    created_at = models.DateTimeField(auto_now_add=True)

    # Read status (many-to-many with users who read it)
    read_by = models.ManyToManyField(User, blank=True, related_name='read_notifications')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Notification'
        verbose_name_plural = 'Notifications'
        indexes = [
            models.Index(fields=['is_active', 'is_global', '-created_at']),
            models.Index(fields=['is_scheduled', 'schedule_type']),
        ]

    def __str__(self):
        return f'{self.title} ({self.notification_type})'

    @property
    def open_rate(self):
        """Calculate open rate as a percentage."""
        if self.push_recipient_count > 0:
            return round((self.opened_count / self.push_recipient_count) * 100, 1)
        return 0

    @property
    def delivered_count(self):
        """Number of unique delivery events recorded for this notification."""
        return self.events.filter(event_type='delivered').count()

    @property
    def opened_users_count(self):
        """Number of distinct users who opened this notification."""
        return self.events.filter(event_type='opened').values('user').distinct().count()

    @property
    def click_through_rate(self):
        """CTR = unique openers / delivered (falls back to push_recipient_count)."""
        denom = self.delivered_count or self.push_recipient_count
        if not denom:
            return 0
        return round((self.opened_users_count / denom) * 100, 1)


class DeviceToken(models.Model):
    """FCM device tokens linked to specific users for multi-account device handling.

    Tokens are deactivated (not deleted) on logout and reactivated on login.
    Ensures no duplicate sends to the same physical device.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='device_tokens')
    token = models.CharField(
        max_length=255,
        unique=True,
        validators=[validate_fcm_token],
        help_text='FCM registration token'
    )
    is_active = models.BooleanField(
        default=True,
        help_text='Deactivated on logout, reactivated on login'
    )
    device_type = models.CharField(
        max_length=50,
        blank=True,
        help_text='e.g. iPhone 15, Samsung Galaxy S24'
    )
    device_os = models.CharField(
        max_length=50,
        blank=True,
        help_text='e.g. iOS 17.4, Android 14'
    )
    preferred_language = models.CharField(
        max_length=5,
        default='en',
        blank=True,
        help_text='Language for push notifications on this device (en/fr). '
                  'Used to target anonymous devices that have not logged in yet.'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        # unique_together removed: anonymous tokens (user=None) are allowed
        verbose_name = 'Device Token'
        verbose_name_plural = 'Device Tokens'
        indexes = [
            models.Index(fields=['is_active', 'token']),
        ]

    def __str__(self):
        status = 'active' if self.is_active else 'inactive'
        username = self.user.username if self.user else 'anonymous'
        return f"{username} - {self.token[:20]}... ({status})"


class NotificationEvent(models.Model):
    """Per-recipient engagement events for a push Notification.

    Enables real CTR and open-rate analytics (unique users, not raw taps).
    A single (notification, user, device_token, event_type) combo is unique.
    """
    EVENT_CHOICES = [
        ('delivered', 'Delivered'),   # Client received FCM payload
        ('displayed', 'Displayed'),   # Banner shown / OS notification presented
        ('opened', 'Opened'),         # User tapped the notification
        ('dismissed', 'Dismissed'),   # User swiped away (best-effort)
    ]

    notification = models.ForeignKey(
        Notification,
        on_delete=models.CASCADE,
        related_name='events',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notification_events',
    )
    device_token = models.ForeignKey(
        DeviceToken,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notification_events',
    )
    event_type = models.CharField(max_length=20, choices=EVENT_CHOICES)
    language = models.CharField(max_length=5, blank=True)  # 'en' / 'fr' at send time
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Notification Event'
        verbose_name_plural = 'Notification Events'
        indexes = [
            models.Index(fields=['notification', 'event_type']),
            models.Index(fields=['created_at']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['notification', 'user', 'device_token', 'event_type'],
                name='unique_notif_event_per_recipient',
            )
        ]

    def __str__(self):
        who = self.user.username if self.user else (
            f"device#{self.device_token_id}" if self.device_token_id else 'anonymous'
        )
        return f"{self.notification_id}:{self.event_type}:{who}"


class SupportTicket(models.Model):
    """Support ticket for user-admin messaging"""
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    ]
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='support_tickets')
    subject = models.CharField(max_length=255)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='medium')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    assigned_to = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='assigned_tickets'
    )
    rating = models.PositiveSmallIntegerField(null=True, blank=True, help_text='User rating 1-5 stars')
    rating_comment = models.TextField(blank=True, help_text='Optional feedback from user')
    is_live_chat = models.BooleanField(default=False, help_text='Whether this was a live agent session')

    class Meta:
        ordering = ['-updated_at']
        verbose_name = 'Support Ticket'
        verbose_name_plural = 'Support Tickets'
        indexes = [
            models.Index(fields=['status', '-updated_at']),
        ]

    def __str__(self):
        return f"#{self.pk} {self.subject} ({self.status})"


class TicketMessage(models.Model):
    """Individual message within a support ticket conversation"""
    ticket = models.ForeignKey(SupportTicket, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    message = models.TextField()
    is_admin_reply = models.BooleanField(default=False)
    is_read = models.BooleanField(default=False)
    attachment = models.ImageField(upload_to='support/attachments/', blank=True, null=True, validators=[validate_image_file])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        verbose_name = 'Ticket Message'
        verbose_name_plural = 'Ticket Messages'
        indexes = [
            models.Index(fields=['is_admin_reply', 'is_read']),
        ]

    def __str__(self):
        return f"Message on #{self.ticket_id} by {self.sender.username}"


class AppSettings(models.Model):
    summit_year = models.CharField(max_length=10, default='2026')
    summit_theme = models.CharField(max_length=300)
    summit_theme_fr = models.CharField(max_length=300, blank=True)
    website_url = models.URLField(blank=True)
    facebook_url = models.URLField(blank=True)
    twitter_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)

    # About page fields (editable from admin)
    app_description = models.TextField(blank=True, default='Official application for the Be 4 Africa 2026.', help_text='Description shown in the About dialog (English)')
    app_description_fr = models.TextField(blank=True, default='Application officielle de la Présidence de l\'Union Africaine du Burundi 2026.', help_text='Description shown in the About dialog (French)')
    developer_name = models.CharField(max_length=100, blank=True, default='Eyosias Tamene', help_text='Developer/company name shown in About dialog')
    developer_url = models.URLField(blank=True, default='https://eyosias.dev', help_text='Developer website URL')


    # Live agent support toggle
    live_agent_online = models.BooleanField(default=False, help_text='When ON, users see Live Agent chat option in support')

    # Store URLs (for Rate App and update links)
    app_store_url = models.URLField(blank=True, default='https://apps.apple.com/app/id6740047505', help_text='Full App Store URL for iOS')
    play_store_url = models.URLField(blank=True, default='https://play.google.com/store/apps/details?id=com.b4africa.app', help_text='Full Play Store URL for Android')
    app_store_id = models.CharField(max_length=20, blank=True, default='6740047505', help_text='App Store numeric ID')
    play_store_id = models.CharField(max_length=100, blank=True, default='com.b4africa.app', help_text='Play Store package name')

    # Feature toggles (controlled from admin portal)
    bookmarks_enabled = models.BooleanField(default=True, help_text='Show Bookmarks feature in the app')
    discussions_enabled = models.BooleanField(default=True, help_text='Show Discussions feature in the app')
    polls_enabled = models.BooleanField(default=True, help_text='Show Polls feature in the app')
    newsletter_enabled = models.BooleanField(default=True, help_text='Show Weekly Newsletter toggle in the app')

    class Meta:
        verbose_name = 'App Settings'
        verbose_name_plural = 'App Settings'

    def save(self, *args, **kwargs):
        """Enforce singleton: delete all other instances before saving."""
        self.pk = 1
        super().save(*args, **kwargs)
        # Delete any other instances (shouldn't exist, but just in case)
        self.__class__.objects.exclude(pk=1).delete()

    def delete(self, *args, **kwargs):
        """Prevent deletion of settings."""
        pass

    @classmethod
    def load(cls):
        """Get or create the singleton instance."""
        obj, created = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return f"App Settings ({self.summit_year})"


class PriorityAgenda(models.Model):
    """Priority agendas for the Be 4 Africa"""
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    slug = models.SlugField(unique=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)

    # Content sections
    overview = models.TextField()
    overview_fr = models.TextField(blank=True)
    objectives = models.JSONField(default=list, help_text='List of key objectives')
    objectives_fr = models.JSONField(default=list, blank=True)
    impact_areas = models.JSONField(default=list, help_text='List of impact area objects with icon, title, description')
    impact_areas_fr = models.JSONField(default=list, blank=True)
    current_initiatives = models.TextField(blank=True)
    current_initiatives_fr = models.TextField(blank=True)

    # Display settings
    icon_name = models.CharField(max_length=50, help_text='Material icon name')
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    # Media
    hero_image = models.ImageField(upload_to='agendas/', blank=True, null=True, validators=[validate_image_file], help_text='Main image for this agenda')

    # Engagement
    view_count = models.PositiveIntegerField(default=0)

    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['display_order', 'title']
        verbose_name = 'Priority Agenda'
        verbose_name_plural = 'Priority Agendas'

    def __str__(self):
        return self.title


class GalleryAlbum(models.Model):
    """Photo gallery albums"""
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to='gallery/covers/', validators=[validate_image_file])
    photo_count = models.IntegerField(default=0)
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    is_featured = models.BooleanField(default=False)
    display_order = models.IntegerField(default=0)
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this album (used when status=scheduled)'
    )

    class Meta:
        ordering = ['-is_featured', 'display_order', '-created_at']
        verbose_name = 'Gallery Album'
        verbose_name_plural = 'Gallery Albums'
        indexes = [
            models.Index(fields=['-is_featured', 'display_order', '-created_at']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return self.title


class GalleryPhoto(models.Model):
    """Individual photos in gallery albums"""
    album = models.ForeignKey(GalleryAlbum, on_delete=models.CASCADE, related_name='photos')
    image = models.ImageField(upload_to='gallery/photos/', validators=[validate_image_file])
    caption = models.CharField(max_length=300, blank=True)
    caption_fr = models.CharField(max_length=300, blank=True)
    photographer = models.CharField(max_length=100, blank=True)
    taken_date = models.DateField(null=True, blank=True)
    display_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', '-created_at']
        verbose_name = 'Gallery Photo'
        verbose_name_plural = 'Gallery Photos'

    def __str__(self):
        return f"{self.album.title} - Photo {self.id}"

    def save(self, *args, **kwargs):
        if self.image and hasattr(self.image, 'file'):
            self.image = self._compress_image(self.image)
        super().save(*args, **kwargs)

    def _compress_image(self, image_field):
        """Resize and compress image to max 1920px wide, JPEG quality 80."""
        try:
            img = PILImage.open(image_field)
            img = img.convert('RGB')
            max_width = 1920
            if img.width > max_width:
                ratio = max_width / img.width
                new_size = (max_width, int(img.height * ratio))
                img = img.resize(new_size, PILImage.LANCZOS)
            buffer = io.BytesIO()
            img.save(buffer, format='JPEG', quality=80, optimize=True)
            buffer.seek(0)
            name = image_field.name.rsplit('.', 1)[0] + '.jpg'
            return ContentFile(buffer.read(), name=name)
        except Exception:
            return image_field

    @property
    def thumbnail_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'thumb')

    @property
    def medium_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'medium')

    @property
    def large_url(self):
        from .image_utils import get_variant_url
        return get_variant_url(self.image, 'large')


def _update_album_photo_count(instance, **kwargs):
    """Update the album's photo_count after adding/removing photos."""
    try:
        album = instance.album
        album.photo_count = album.photos.count()
        album.save(update_fields=['photo_count'])
    except GalleryAlbum.DoesNotExist:
        pass


post_save.connect(_update_album_photo_count, sender=GalleryPhoto)
post_delete.connect(_update_album_photo_count, sender=GalleryPhoto)


class GalleryAlbumLike(models.Model):
    """Tracks which users liked which gallery albums."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='gallery_album_likes')
    album = models.ForeignKey(GalleryAlbum, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'album')

    def __str__(self):
        return f"{self.user.username} likes {self.album.title[:30]}"


class Video(models.Model):
    """Video content library"""
    CATEGORY_CHOICES = [
        ('highlight', 'Highlights'),
        ('speech', 'Speeches'),
        ('documentary', 'Documentary'),
        ('interview', 'Interview'),
        ('event', 'Event Coverage'),
        ('cultural', 'Cultural'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)

    # Video source - either URL or uploaded file
    video_url = models.URLField(blank=True, help_text='YouTube or external video URL (leave empty if uploading file)')
    video_file = models.FileField(upload_to='videos/files/', blank=True, help_text='Upload video file (MP4, MOV, etc.) or leave empty if using URL')

    thumbnail = models.ImageField(upload_to='videos/thumbnails/', blank=True, validators=[validate_image_file])
    duration = models.CharField(max_length=20, help_text='e.g. 5:30')
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='highlight')
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    publish_date = models.DateTimeField()
    is_featured = models.BooleanField(default=False)
    status = models.CharField(
        max_length=20, choices=CONTENT_STATUS_CHOICES, default='published',
        help_text='Content workflow status: draft, scheduled, published, or archived'
    )
    scheduled_publish_date = models.DateTimeField(
        null=True, blank=True,
        help_text='When to auto-publish this video (used when status=scheduled)'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_featured', '-publish_date']
        verbose_name = 'Video'
        verbose_name_plural = 'Videos'
        indexes = [
            models.Index(fields=['-is_featured', '-publish_date']),
            models.Index(fields=['category', '-publish_date']),
            models.Index(fields=['status', '-publish_date']),
        ]

    def __str__(self):
        return self.title


class VideoLike(models.Model):
    """Tracks which users liked which videos."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='video_likes')
    video = models.ForeignKey(Video, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'video')

    def __str__(self):
        return f"{self.user.username} likes {self.video.title[:30]}"


class VideoChapter(models.Model):
    """Timestamp markers/chapters within a video."""
    video = models.ForeignKey(Video, on_delete=models.CASCADE, related_name='chapters')
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True, default='')
    timestamp_seconds = models.PositiveIntegerField(help_text='Chapter start time in seconds')
    description = models.TextField(blank=True, default='')
    description_fr = models.TextField(blank=True, default='')
    thumbnail = models.ImageField(upload_to='video_chapters/', null=True, blank=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['timestamp_seconds']
        verbose_name = 'Video Chapter'
        verbose_name_plural = 'Video Chapters'

    def __str__(self):
        minutes = self.timestamp_seconds // 60
        seconds = self.timestamp_seconds % 60
        return f"{minutes:02d}:{seconds:02d} - {self.title}"


class VideoSubtitle(models.Model):
    """Multi-language subtitle/caption files for videos."""
    LANGUAGE_CHOICES = [
        ('en', 'English'),
        ('fr', 'French'),
    ]

    video = models.ForeignKey(Video, on_delete=models.CASCADE, related_name='subtitles')
    language = models.CharField(max_length=5, choices=LANGUAGE_CHOICES)
    subtitle_file = models.FileField(
        upload_to='subtitles/',
        help_text='Upload .srt or .vtt subtitle file'
    )
    is_default = models.BooleanField(default=False)

    class Meta:
        verbose_name = 'Video Subtitle'
        verbose_name_plural = 'Video Subtitles'
        unique_together = ('video', 'language')

    def __str__(self):
        return f"{self.video.title[:30]} - {self.get_language_display()}"


class SocialMediaLink(models.Model):
    """Social media profiles and links"""
    platform = models.CharField(max_length=50, unique=True, help_text='e.g. facebook, twitter, instagram, tiktok, threads, telegram, whatsapp')
    display_name = models.CharField(max_length=100)
    display_name_fr = models.CharField(max_length=100, blank=True)
    url = models.URLField()
    handle = models.CharField(max_length=100, help_text='e.g. @BurundiAU2026')
    follower_count = models.CharField(max_length=20, blank=True, help_text='e.g. 45K')
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    icon_color = models.CharField(max_length=10, default='#1EB53A')
    is_active = models.BooleanField(default=True)
    display_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'platform']
        verbose_name = 'Social Media Link'
        verbose_name_plural = 'Social Media Links'

    def __str__(self):
        return f"{self.get_platform_display()} - {self.handle}"


class HeroTextContent(models.Model):
    """Dynamic text for hero section"""
    KEY_CHOICES = [
        ('badge', 'Badge Text'),
        ('title_line1', 'Title Line 1'),
        ('title_line2', 'Title Line 2'),
        ('year', 'Year'),
    ]

    key = models.CharField(max_length=50, unique=True, choices=KEY_CHOICES)
    text_en = models.CharField(max_length=200)
    text_fr = models.CharField(max_length=200, blank=True)
    is_active = models.BooleanField(default=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Hero Text Content'
        verbose_name_plural = 'Hero Text Contents'

    def __str__(self):
        return f"{self.key}: {self.text_en}"


class QuickAccessMenuItem(models.Model):
    """Dynamic quick access menu items"""
    ACTION_TYPE_CHOICES = [
        ('route', 'App Route'),
        ('url', 'External URL'),
    ]

    title_en = models.CharField(max_length=100)
    title_fr = models.CharField(max_length=100, blank=True)
    icon_name = models.CharField(max_length=50, help_text='Flutter icon name (e.g. live_tv, menu_book, article)')
    action_type = models.CharField(max_length=10, choices=ACTION_TYPE_CHOICES)
    action_value = models.CharField(max_length=200, help_text='Route name (e.g. /live-feeds) or URL')
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    has_live_indicator = models.BooleanField(default=False, help_text='Show red "LIVE" badge')
    badge_text = models.CharField(max_length=10, blank=True, help_text='Manual badge text e.g. "HOT", "PROMO". Overrides auto badge if set.')
    badge_color = models.CharField(max_length=10, blank=True, default='#E53935', help_text='Badge background color (hex). Default: red')
    auto_badge = models.BooleanField(default=True, help_text='Automatically show "NEW" badge when fresh content exists for this route')
    auto_badge_days = models.IntegerField(default=3, help_text='Number of days content is considered "new"')
    visibility_rule = models.CharField(
        max_length=50, blank=True, default='',
        choices=[('', 'Everyone'), ('youth_dialogue_accepted', 'Youth Dialogue Accepted Only')],
        help_text='Who can see this menu item. Empty = everyone.'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Quick Access Menu Item'
        verbose_name_plural = 'Quick Access Menu Items'

    def __str__(self):
        return self.title_en


class OTPVerification(models.Model):
    """OTP tracking for email and phone verification"""
    TYPE_CHOICES = [
        ('email', 'Email'),
        ('phone', 'Phone'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='otp_verifications')
    type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    contact = models.CharField(max_length=200, help_text='Email or phone number')
    otp_code = models.CharField(max_length=20)
    is_verified = models.BooleanField(default=False)
    attempts = models.IntegerField(default=0, help_text='Number of failed verification attempts')
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'OTP Verification'
        verbose_name_plural = 'OTP Verifications'

    def __str__(self):
        return f"{self.type} OTP for {self.contact} - {'Verified' if self.is_verified else 'Pending'}"

    def is_expired(self):
        from django.utils import timezone
        return timezone.now() > self.expires_at


class VerificationRequest(models.Model):
    """
    Verification request for users who want a verified badge (Gold or Blue).
    Admins review and approve/reject requests.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('appealed', 'Appealed'),
    ]

    TITLE_CHOICES = [
        ('mr', 'Mr.'),
        ('mrs', 'Mrs.'),
        ('ms', 'Ms.'),
        ('dr', 'Dr.'),
        ('prof', 'Prof.'),
        ('he', 'H.E. (His/Her Excellency)'),
        ('amb', 'Ambassador'),
        ('hon', 'Honorable'),
        ('other', 'Other'),
    ]

    BADGE_TYPE_CHOICES = [
        ('GOLD', 'Gold Badge'),
        ('BLUE', 'Blue Badge'),
        ('GREEN', 'Green Badge'),
    ]

    # User requesting verification
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='verification_requests')

    # Request details
    title = models.CharField(max_length=10, choices=TITLE_CHOICES, help_text='Title/Role (Mr, Mrs, H.E, etc.)')
    first_name = models.CharField(max_length=100, default='', help_text='First name (for identity verification)')
    last_name = models.CharField(max_length=100, default='', help_text='Last name (for identity verification)')
    full_name = models.CharField(max_length=200, help_text='Full legal name')
    gender = models.CharField(max_length=20, choices=[('male', 'Male'), ('female', 'Female')], blank=True, help_text='Applicant gender')

    # Email verification
    email = models.EmailField(
        help_text='Professional email (no gmail/yahoo/outlook)',
        validators=[validate_professional_email]
    )
    email_verified = models.BooleanField(default=False, help_text='Email verified via OTP')

    # Phone verification
    country_code = models.CharField(max_length=10, default='+1', help_text='Country calling code (e.g. +1, +257)')
    phone_number = models.CharField(max_length=20, help_text='Phone number for SMS verification')
    phone_verified = models.BooleanField(default=False, help_text='Phone number verified')

    # Additional info
    position_role = models.CharField(max_length=200, help_text='Current position/role')
    reasoning_message = models.TextField(
        blank=True,
        help_text='User explanation for why they deserve the verification badge'
    )
    supporting_document = models.ImageField(upload_to='verification_documents/', blank=True, null=True, help_text='Optional supporting document or photo')

    # Status tracking
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    badge_type = models.CharField(
        max_length=10,
        choices=BADGE_TYPE_CHOICES,
        blank=True,
        null=True,
        help_text='Badge type assigned by admin (Gold or Blue)'
    )

    # Admin review
    reviewed_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_verifications',
        help_text='Admin who reviewed this request'
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(
        blank=True,
        help_text='Admin-written reason for rejection (shown to user)'
    )

    # Appeal system
    appeal_message = models.TextField(
        blank=True,
        help_text='User appeal message if rejected'
    )
    appeal_submitted_at = models.DateTimeField(null=True, blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Verification Request'
        verbose_name_plural = 'Verification Requests'
        indexes = [
            models.Index(fields=['status', '-created_at']),
        ]

    def __str__(self):
        return f"{self.full_name} ({self.status}) - {self.badge_type or 'No badge'}"

    def approve(self, admin_user, badge_type='BLUE'):
        """Approve verification request and grant badge to user.
        Government officials automatically receive GOLD badge."""
        from django.utils import timezone

        # Auto-upgrade to GOLD for government officials
        profile = self.user.profile
        if profile.is_government_official:
            badge_type = 'GOLD'

        self.status = 'approved'
        self.badge_type = badge_type
        self.reviewed_by = admin_user
        self.reviewed_at = timezone.now()
        self.save()

        # Update user profile with verification
        profile.is_verified = True
        profile.badge_type = badge_type
        profile.verified_at = timezone.now()
        profile.save()

        # Transfer verified data to user profile (don't overwrite existing data)
        # Use explicit first/last name fields if available, otherwise parse full_name
        if self.first_name and not self.user.first_name:
            self.user.first_name = self.first_name
        if self.last_name and not self.user.last_name:
            self.user.last_name = self.last_name
        if not self.user.first_name and self.full_name:
            parts = self.full_name.split(' ', 1)
            self.user.first_name = parts[0]
            if not self.user.last_name and len(parts) > 1:
                self.user.last_name = parts[1]
        self.user.save(update_fields=['first_name', 'last_name'])

        if self.email and not self.user.email:
            self.user.email = self.email
            self.user.save(update_fields=['email'])
        if self.phone_number and not profile.phone_number:
            profile.phone_number = self.phone_number
        if self.gender and not profile.gender:
            profile.gender = self.gender
        if self.country_code and not profile.nationality:
            profile.nationality = self.country_code
        profile.save()

    def reject(self, admin_user, reason):
        """Reject verification request with reason"""
        from django.utils import timezone

        self.status = 'rejected'
        self.rejection_reason = reason
        self.reviewed_by = admin_user
        self.reviewed_at = timezone.now()
        self.save()

    def submit_appeal(self, message):
        """User submits appeal for rejected request"""
        from django.utils import timezone

        if self.status != 'rejected':
            raise ValueError('Can only appeal rejected requests')

        self.status = 'appealed'
        self.appeal_message = message
        self.appeal_submitted_at = timezone.now()
        self.save()


class VerificationSocialMedia(models.Model):
    """
    Social media profiles for verification requests.
    Users can add multiple platforms, providing either username or full URL.
    """
    PLATFORM_CHOICES = [
        ('twitter', 'X (Twitter)'),
        ('facebook', 'Facebook'),
        ('linkedin', 'LinkedIn'),
        ('instagram', 'Instagram'),
        ('tiktok', 'TikTok'),
        ('youtube', 'YouTube'),
        ('telegram', 'Telegram'),
        ('whatsapp', 'WhatsApp'),
        ('threads', 'Threads'),
        ('other', 'Other'),
    ]

    verification_request = models.ForeignKey(
        VerificationRequest,
        on_delete=models.CASCADE,
        related_name='social_media_profiles',
        help_text='The verification request this social media profile belongs to'
    )
    platform = models.CharField(
        max_length=20,
        choices=PLATFORM_CHOICES,
        help_text='Social media platform'
    )
    username_or_url = models.CharField(
        max_length=500,
        help_text='Username (e.g. @john_doe) or full URL (e.g. https://twitter.com/john_doe)'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['platform']
        verbose_name = 'Verification Social Media'
        verbose_name_plural = 'Verification Social Media'
        unique_together = ['verification_request', 'platform']

    def __str__(self):
        return f"{self.get_platform_display()}: {self.username_or_url}"

    @property
    def is_url(self):
        """Check if the value is a full URL or just a username"""
        return self.username_or_url.startswith(('http://', 'https://'))

    @property
    def display_value(self):
        """Return a clean display value"""
        if self.is_url:
            return self.username_or_url
        else:
            # If it's a username, prefix with @ if not already present
            value = self.username_or_url.strip()
            if not value.startswith('@'):
                return f"@{value}"
            return value


class WeatherCity(models.Model):
    """Weather cities displayed in the weather page"""
    name = models.CharField(max_length=100, help_text='City name e.g. Bujumbura')
    latitude = models.FloatField(help_text='City latitude for weather API')
    longitude = models.FloatField(help_text='City longitude for weather API')
    background_image = models.ImageField(
        upload_to='weather/backgrounds/',
        blank=True,
        null=True,
        validators=[validate_image_file],
        help_text='Background image for this city (blurred in app)'
    )
    order = models.IntegerField(default=0, help_text='Display order (lower = first)')
    is_active = models.BooleanField(default=True)
    is_default = models.BooleanField(default=False, help_text='Default cities cannot be removed by users')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'name']
        verbose_name = 'Weather City'
        verbose_name_plural = 'Weather Cities'

    def __str__(self):
        return self.name


class AdminRole(models.Model):
    """
    Defines admin roles with granular access control.
    Assign a role to a User to grant them specific admin permissions.
    """
    PERMISSION_CHOICES = [
        ('content', 'Content Management (Articles, Magazines, Hero Slides)'),
        ('events', 'Events & Registrations'),
        ('users', 'User Management'),
        ('verification', 'Verification Requests'),
        ('notifications', 'Push Notifications'),
        ('gallery', 'Gallery & Media'),
        ('locations', 'Embassies & Locations'),
        ('settings', 'App Settings & Configuration'),
        ('audit', 'Audit Logs (View Only)'),
    ]

    name = models.CharField(max_length=100, unique=True, help_text='Role name (e.g., Content Editor, Event Manager)')
    description = models.TextField(blank=True, help_text='What this role is responsible for')
    permissions = models.JSONField(
        default=list,
        help_text='List of permission keys this role grants (e.g., ["content", "gallery"])'
    )
    users = models.ManyToManyField(User, blank=True, related_name='admin_roles')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name = 'Admin Role'
        verbose_name_plural = 'Admin Roles'

    def __str__(self):
        return self.name

    def get_permission_labels(self):
        perm_dict = dict(self.PERMISSION_CHOICES)
        return [perm_dict.get(p, p) for p in (self.permissions or [])]


class AuditLogEntry(models.Model):
    """Tracks admin actions for the audit log in settings page"""
    ACTION_CHOICES = [
        ('CREATE', 'Create'),
        ('UPDATE', 'Update'),
        ('DELETE', 'Delete'),
        ('LOGIN', 'Login'),
        ('EXPORT', 'Export'),
    ]
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('failure', 'Failure'),
    ]

    user = models.ForeignKey(User, null=True, on_delete=models.SET_NULL, related_name='audit_logs')
    action = models.CharField(max_length=50, choices=ACTION_CHOICES)
    entity_type = models.CharField(max_length=100)
    entity_label = models.CharField(max_length=255)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='success')
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Audit Log Entry'
        verbose_name_plural = 'Audit Log Entries'

    def __str__(self):
        return f"{self.action} {self.entity_type}: {self.entity_label}"


class Popup(models.Model):
    """Popup/Announcement system for displaying messages to users on app launch"""
    POPUP_TYPE_CHOICES = [
        ('general', 'General Announcement'),
        ('event', 'Event Promotion'),
        ('verification', 'Verification Reminder'),
        ('project', 'Project Update'),
    ]

    title = models.CharField(max_length=200, help_text='Popup title')
    title_fr = models.CharField(max_length=200, blank=True, help_text='French title')
    message = models.TextField(help_text='Main message content')
    message_fr = models.TextField(blank=True, help_text='French message')
    image = models.ImageField(upload_to='popups/', blank=True, null=True, validators=[validate_image_file],
                              help_text='Optional image displayed at top of popup')
    action_text = models.CharField(max_length=100, blank=True, help_text='Button text (e.g., "Click here", "Sign up now")')
    action_text_fr = models.CharField(max_length=100, blank=True, help_text='French button text')
    action_url = models.CharField(max_length=500, blank=True,
                                   help_text='URL or app route (e.g., "/events" or "https://external.com")')
    popup_type = models.CharField(max_length=20, choices=POPUP_TYPE_CHOICES, default='general')
    is_active = models.BooleanField(default=True, help_text='Only active popups are shown to users')
    priority = models.IntegerField(default=0, help_text='Higher priority = shown first (0-100)')
    show_once = models.BooleanField(default=True, help_text='If true, user sees this popup only once')
    expires_at = models.DateTimeField(null=True, blank=True, help_text='Popup will not show after this date/time')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-priority', '-created_at']
        verbose_name = 'Popup/Announcement'
        verbose_name_plural = 'Popups/Announcements'
        indexes = [
            models.Index(fields=['is_active', '-priority', '-created_at']),
        ]

    def __str__(self):
        return f"{self.title} ({self.get_popup_type_display()})"

    def is_expired(self):
        """Check if popup has expired"""
        if not self.expires_at:
            return False
        from django.utils import timezone
        return timezone.now() > self.expires_at


class UserSession(models.Model):
    """Tracks user sessions with geolocation data for analytics."""
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='sessions')
    ip_address = models.GenericIPAddressField()
    country_code = models.CharField(max_length=5, blank=True, db_index=True)
    country_name = models.CharField(max_length=100, blank=True)
    city = models.CharField(max_length=100, blank=True)
    user_nationality = models.CharField(max_length=5, blank=True, db_index=True, help_text='Snapshot from UserProfile at session time')
    device_type = models.CharField(max_length=50, blank=True)
    device_os = models.CharField(max_length=50, blank=True)
    app_version = models.CharField(max_length=20, blank=True)
    is_active = models.BooleanField(default=True)
    terminated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'User Session'
        verbose_name_plural = 'User Sessions'
        indexes = [
            models.Index(fields=['country_code', 'created_at']),
            models.Index(fields=['user_nationality', 'created_at']),
        ]

    def __str__(self):
        user_str = self.user.username if self.user else 'anonymous'
        return f"{user_str} from {self.country_name or self.ip_address} at {self.created_at}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Authentication & Security
# ══════════════════════════════════════════════════════════════

class LoginHistory(models.Model):
    """Tracks all login attempts (success and failure) for security auditing."""
    METHOD_CHOICES = [
        ('email', 'Email/Password'),
        ('firebase_google', 'Google (Firebase)'),
        ('firebase_apple', 'Apple (Firebase)'),
        ('firebase_email', 'Email (Firebase)'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='login_history', null=True, blank=True)
    email = models.EmailField(blank=True, help_text='Email used for login attempt')
    method = models.CharField(max_length=20, choices=METHOD_CHOICES, default='email')
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    user_agent = models.TextField(blank=True)
    device_type = models.CharField(max_length=50, blank=True)
    country = models.CharField(max_length=100, blank=True)
    city = models.CharField(max_length=100, blank=True)
    success = models.BooleanField(default=True)
    failure_reason = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Login History'
        verbose_name_plural = 'Login History'
        indexes = [
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self):
        status = 'Success' if self.success else 'Failed'
        return f"{self.email or 'unknown'} - {status} - {self.created_at}"


class ActiveSession(models.Model):
    """Tracks active user sessions for multi-device management."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='active_sessions')
    session_key = models.CharField(max_length=255, unique=True, db_index=True)
    device_name = models.CharField(max_length=200, blank=True, help_text='e.g. iPhone 15 Pro')
    device_type = models.CharField(max_length=50, blank=True, help_text='e.g. ios, android, web')
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    location = models.CharField(max_length=200, blank=True)
    app_version = models.CharField(max_length=20, blank=True)
    is_current = models.BooleanField(default=False, help_text='Is this the current session?')
    last_active = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-last_active']
        verbose_name = 'Active Session'
        verbose_name_plural = 'Active Sessions'

    def __str__(self):
        return f"{self.user.username} - {self.device_name or 'Unknown device'}"


class PasswordChangeHistory(models.Model):
    """Tracks password changes for security."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_changes')
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-changed_at']
        verbose_name = 'Password Change'
        verbose_name_plural = 'Password Changes'

    def __str__(self):
        return f"{self.user.username} changed password at {self.changed_at}"


class IPWhitelist(models.Model):
    """IP whitelist for admin portal access."""
    ip_address = models.GenericIPAddressField(unique=True)
    label = models.CharField(max_length=100, help_text='e.g. Office HQ, VPN')
    added_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'IP Whitelist'
        verbose_name_plural = 'IP Whitelist'

    def __str__(self):
        return f"{self.ip_address} ({self.label})"


class AccountMergeRequest(models.Model):
    """Request to merge two accounts (e.g., email + social login)."""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    primary_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='merge_requests_primary')
    secondary_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='merge_requests_secondary')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reason = models.TextField(blank=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_merges')
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Account Merge Request'
        verbose_name_plural = 'Account Merge Requests'

    def __str__(self):
        return f"Merge {self.secondary_user.username} into {self.primary_user.username}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Content & Media
# ══════════════════════════════════════════════════════════════

class Bookmark(models.Model):
    """User bookmarks for articles, magazines, videos, etc."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('magazine', 'Magazine'),
        ('video', 'Video'),
        ('event', 'Event'),
        ('feature_card', 'Feature Card'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookmarks')
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    notes = models.TextField(blank=True, help_text='User notes about this bookmark')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'content_type', 'content_id')
        ordering = ['-created_at']
        verbose_name = 'Bookmark'
        verbose_name_plural = 'Bookmarks'
        indexes = [
            models.Index(fields=['user', 'content_type']),
        ]

    def __str__(self):
        return f"{self.user.username} bookmarked {self.content_type}:{self.content_id}"


class Reaction(models.Model):
    """Emoji reactions on content (articles, magazines, videos)."""
    REACTION_CHOICES = [
        ('like', 'Like'),
        ('love', 'Love'),
        ('celebrate', 'Celebrate'),
        ('insightful', 'Insightful'),
        ('curious', 'Curious'),
    ]
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('magazine', 'Magazine'),
        ('video', 'Video'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reactions')
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    reaction_type = models.CharField(max_length=20, choices=REACTION_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'content_type', 'content_id')
        ordering = ['-created_at']
        verbose_name = 'Reaction'
        verbose_name_plural = 'Reactions'

    def __str__(self):
        return f"{self.user.username} reacted {self.reaction_type} on {self.content_type}:{self.content_id}"


class ReadingProgress(models.Model):
    """Track reading progress for articles."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reading_progress')
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='reading_progress')
    progress_percent = models.IntegerField(default=0, help_text='0-100 reading progress')
    scroll_position = models.IntegerField(default=0, help_text='Pixel scroll position')
    completed = models.BooleanField(default=False)
    last_read_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'article')
        verbose_name = 'Reading Progress'
        verbose_name_plural = 'Reading Progress'

    def __str__(self):
        return f"{self.user.username} - {self.article.title[:30]} ({self.progress_percent}%)"


class ContentSchedule(models.Model):
    """Schedule content for future publication."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('notification', 'Notification'),
        ('popup', 'Popup'),
    ]
    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('published', 'Published'),
        ('cancelled', 'Cancelled'),
    ]
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    scheduled_for = models.DateTimeField(db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    published_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['scheduled_for']
        verbose_name = 'Content Schedule'
        verbose_name_plural = 'Content Schedules'

    def __str__(self):
        return f"{self.content_type}:{self.content_id} scheduled for {self.scheduled_for}"


class ArticleDraft(models.Model):
    """Draft articles that haven't been published yet."""
    title = models.CharField(max_length=300)
    title_fr = models.CharField(max_length=300, blank=True)
    content = models.TextField()
    content_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='article_drafts/', blank=True, validators=[validate_image_file])
    author = models.CharField(max_length=100)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_drafts')
    last_edited_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='edited_drafts')
    auto_saved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']
        verbose_name = 'Article Draft'
        verbose_name_plural = 'Article Drafts'

    def __str__(self):
        return f"[DRAFT] {self.title}"


class ContentVersion(models.Model):
    """Version history for content (articles, feature cards)."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('feature_card', 'Feature Card'),
        ('notification', 'Notification'),
    ]
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    version_number = models.PositiveIntegerField()
    data_snapshot = models.JSONField(help_text='Full JSON snapshot of the content at this version')
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    change_summary = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('content_type', 'content_id', 'version_number')
        ordering = ['-version_number']
        verbose_name = 'Content Version'
        verbose_name_plural = 'Content Versions'

    def __str__(self):
        return f"{self.content_type}:{self.content_id} v{self.version_number}"


class ArticleSeries(models.Model):
    """Group articles into a series/collection."""
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to='article_series/', blank=True, validators=[validate_image_file])
    articles = models.ManyToManyField(Article, blank=True, related_name='series')
    is_active = models.BooleanField(default=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', '-created_at']
        verbose_name = 'Article Series'
        verbose_name_plural = 'Article Series'

    def __str__(self):
        return self.title


class TrendingContent(models.Model):
    """Tracks trending content based on views and engagement."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('magazine', 'Magazine'),
        ('video', 'Video'),
    ]
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    score = models.FloatField(default=0, help_text='Trending score based on views, likes, shares')
    period_start = models.DateTimeField()
    period_end = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-score']
        verbose_name = 'Trending Content'
        verbose_name_plural = 'Trending Content'
        indexes = [
            models.Index(fields=['content_type', '-score']),
        ]

    def __str__(self):
        return f"{self.content_type}:{self.content_id} score={self.score}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Events & Calendar
# ══════════════════════════════════════════════════════════════

class EventReminder(models.Model):
    """User-set reminders for events."""
    REMINDER_CHOICES = [
        ('15min', '15 minutes before'),
        ('30min', '30 minutes before'),
        ('1hour', '1 hour before'),
        ('1day', '1 day before'),
        ('1week', '1 week before'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_reminders')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='reminders', null=True, blank=True)
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='reminders', null=True, blank=True)
    reminder_type = models.CharField(max_length=10, choices=REMINDER_CHOICES, default='1hour')
    reminder_time = models.DateTimeField(help_text='Computed time to send reminder')
    sent = models.BooleanField(default=False)
    sent_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['reminder_time']
        verbose_name = 'Event Reminder'
        verbose_name_plural = 'Event Reminders'
        indexes = [
            models.Index(fields=['sent', 'reminder_time']),
        ]

    def __str__(self):
        event_name = self.event.name if self.event else self.event_registration.event_title if self.event_registration else 'Unknown'
        return f"{self.user.username} reminder for {event_name}"


class EventWaitlist(models.Model):
    """Waitlist for full-capacity events."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_waitlists')
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='waitlist')
    position = models.PositiveIntegerField(default=0, help_text='Position in waitlist queue')
    notified = models.BooleanField(default=False, help_text='User notified of spot opening')
    promoted = models.BooleanField(default=False, help_text='User promoted from waitlist to registered')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'event_registration')
        ordering = ['position', 'created_at']
        verbose_name = 'Event Waitlist'
        verbose_name_plural = 'Event Waitlists'

    def __str__(self):
        return f"{self.user.username} waitlisted for {self.event_registration.event_title}"


class EventSpeaker(models.Model):
    """Speaker profiles for events."""
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='event_speakers', null=True, blank=True)
    name = models.CharField(max_length=200)
    title = models.CharField(max_length=200, blank=True, help_text='e.g. Minister of Foreign Affairs')
    bio = models.TextField(blank=True)
    bio_fr = models.TextField(blank=True)
    photo = models.ImageField(upload_to='event_speakers/', blank=True, validators=[validate_image_file])
    organization = models.CharField(max_length=200, blank=True)
    topic = models.CharField(max_length=300, blank=True)
    topic_fr = models.CharField(max_length=300, blank=True)
    linkedin_url = models.URLField(blank=True)
    twitter_handle = models.CharField(max_length=100, blank=True)
    events = models.ManyToManyField(Event, blank=True, related_name='speakers')
    event_registrations = models.ManyToManyField(EventRegistration, blank=True, related_name='speakers')
    is_active = models.BooleanField(default=True)
    display_order = models.IntegerField(default=0)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'name']
        verbose_name = 'Event Speaker'
        verbose_name_plural = 'Event Speakers'

    def __str__(self):
        return f"{self.name} - {self.title}"


class EventFeedback(models.Model):
    """Post-event feedback and surveys."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_feedback')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='feedback', null=True, blank=True)
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='feedback', null=True, blank=True)
    overall_rating = models.PositiveSmallIntegerField(help_text='1-5 stars')
    content_rating = models.PositiveSmallIntegerField(null=True, blank=True)
    organization_rating = models.PositiveSmallIntegerField(null=True, blank=True)
    venue_rating = models.PositiveSmallIntegerField(null=True, blank=True)
    comments = models.TextField(blank=True)
    would_recommend = models.BooleanField(default=True)
    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-submitted_at']
        verbose_name = 'Event Feedback'
        verbose_name_plural = 'Event Feedback'

    def __str__(self):
        event_name = self.event.name if self.event else self.event_registration.event_title if self.event_registration else 'Unknown'
        return f"{self.user.username} feedback for {event_name} ({self.overall_rating}/5)"


class EventCheckIn(models.Model):
    """QR code check-in tracking for events."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_checkins')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='checkins', null=True, blank=True)
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='checkins', null=True, blank=True)
    submission = models.ForeignKey(EventSubmission, on_delete=models.SET_NULL, null=True, blank=True)
    qr_code = models.CharField(max_length=255, unique=True, db_index=True)
    checked_in = models.BooleanField(default=False)
    checked_in_at = models.DateTimeField(null=True, blank=True)
    checked_in_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='checked_in_users')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Event Check-In'
        verbose_name_plural = 'Event Check-Ins'

    def __str__(self):
        return f"{self.user.username} check-in ({self.qr_code[:8]}...)"


class EventPhoto(models.Model):
    """User-uploaded photos for events."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_photos')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='user_photos', null=True, blank=True)
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='user_photos', null=True, blank=True)
    image = models.ImageField(upload_to='event_photos/', validators=[validate_image_file])
    caption = models.CharField(max_length=200, blank=True)
    is_approved = models.BooleanField(default=True, help_text='Auto-approved; admin can revoke')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Event Photo'
        verbose_name_plural = 'Event Photos'

    def __str__(self):
        return f"Photo by {self.user.username}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Communication & Social
# ══════════════════════════════════════════════════════════════

class Conversation(models.Model):
    """Direct message conversation between two users."""
    participants = models.ManyToManyField(User, related_name='conversations')
    last_message_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-last_message_at']
        verbose_name = 'Conversation'
        verbose_name_plural = 'Conversations'
        indexes = [
            models.Index(fields=['-last_message_at']),
        ]

    def __str__(self):
        usernames = ', '.join(u.username for u in self.participants.all()[:3])
        return f"Conversation: {usernames}"


class DirectMessage(models.Model):
    """Individual message in a conversation."""
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_messages')
    content = models.TextField()
    attachment = models.ImageField(upload_to='messages/attachments/', blank=True, null=True, validators=[validate_image_file])
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        verbose_name = 'Direct Message'
        verbose_name_plural = 'Direct Messages'
        indexes = [
            models.Index(fields=['is_read', '-created_at']),
        ]

    def __str__(self):
        return f"{self.sender.username}: {self.content[:50]}"


class Discussion(models.Model):
    """Forum discussion/thread."""
    CATEGORY_CHOICES = [
        ('general', 'General'),
        ('events', 'Events'),
        ('culture', 'Culture'),
        ('politics', 'Politics & Diplomacy'),
        ('business', 'Business & Trade'),
        ('announcements', 'Announcements'),
    ]
    title = models.CharField(max_length=300)
    content = models.TextField()
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='general')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='discussions')
    is_pinned = models.BooleanField(default=False)
    is_locked = models.BooleanField(default=False, help_text='Prevent new replies')
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    reply_count = models.PositiveIntegerField(default=0)
    last_reply_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-last_reply_at', '-created_at']
        verbose_name = 'Discussion'
        verbose_name_plural = 'Discussions'
        indexes = [
            models.Index(fields=['category', '-is_pinned', '-last_reply_at']),
            models.Index(fields=['-is_pinned', '-last_reply_at', '-created_at']),
        ]

    def __str__(self):
        return self.title


class DiscussionReply(models.Model):
    """Reply in a discussion thread."""
    discussion = models.ForeignKey(Discussion, on_delete=models.CASCADE, related_name='replies')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='discussion_replies')
    content = models.TextField()
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='children')
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['created_at']
        verbose_name = 'Discussion Reply'
        verbose_name_plural = 'Discussion Replies'

    def __str__(self):
        return f"Reply by {self.author.username} on {self.discussion.title[:30]}"


class Poll(models.Model):
    """Polls and surveys."""
    title = models.CharField(max_length=300)
    title_fr = models.CharField(max_length=300, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_polls')
    is_active = models.BooleanField(default=True)
    is_anonymous = models.BooleanField(default=False, help_text='Hide voter identity')
    multiple_choice = models.BooleanField(default=False, help_text='Allow selecting multiple options')
    expires_at = models.DateTimeField(null=True, blank=True)
    total_votes = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Poll'
        verbose_name_plural = 'Polls'

    def __str__(self):
        return self.title


class PollOption(models.Model):
    """Individual option in a poll."""
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE, related_name='options')
    text = models.CharField(max_length=200)
    text_fr = models.CharField(max_length=200, blank=True)
    vote_count = models.PositiveIntegerField(default=0)
    display_order = models.IntegerField(default=0)
    order = models.IntegerField(default=0)

    class Meta:
        ordering = ['order']
        verbose_name = 'Poll Option'
        verbose_name_plural = 'Poll Options'

    def __str__(self):
        return f"{self.poll.title[:30]} - {self.text}"


class PollVote(models.Model):
    """User vote on a poll option."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='poll_votes')
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE, related_name='votes')
    option = models.ForeignKey(PollOption, on_delete=models.CASCADE, related_name='votes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'option')
        verbose_name = 'Poll Vote'
        verbose_name_plural = 'Poll Votes'

    def __str__(self):
        return f"{self.user.username} voted for {self.option.text[:30]}"


class NotificationPreference(models.Model):
    """User notification preferences (per-category toggle)."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='notification_preferences')
    push_enabled = models.BooleanField(default=True)
    email_enabled = models.BooleanField(default=False)
    # Category toggles
    new_articles = models.BooleanField(default=True)
    new_magazines = models.BooleanField(default=True)
    event_reminders = models.BooleanField(default=True)
    event_updates = models.BooleanField(default=True)
    live_streams = models.BooleanField(default=True)
    verification_updates = models.BooleanField(default=True)
    support_replies = models.BooleanField(default=True)
    polls_surveys = models.BooleanField(default=True)
    direct_messages = models.BooleanField(default=True)
    discussion_replies = models.BooleanField(default=True)
    system_updates = models.BooleanField(default=True)
    # Quiet hours
    quiet_hours_enabled = models.BooleanField(default=False)
    quiet_start = models.TimeField(null=True, blank=True, help_text='e.g. 22:00')
    quiet_end = models.TimeField(null=True, blank=True, help_text='e.g. 07:00')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Notification Preference'
        verbose_name_plural = 'Notification Preferences'

    def __str__(self):
        return f"{self.user.username}'s notification preferences"


class AnnouncementBanner(models.Model):
    """Global announcement banners shown at top of app."""
    TYPE_CHOICES = [
        ('info', 'Information'),
        ('warning', 'Warning'),
        ('success', 'Success'),
        ('error', 'Error'),
        ('urgent', 'Urgent'),
    ]
    title = models.CharField(max_length=300, blank=True)
    title_fr = models.CharField(max_length=300, blank=True)
    message = models.CharField(max_length=500)
    message_fr = models.CharField(max_length=500, blank=True)
    banner_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='info')
    link_url = models.CharField(max_length=500, blank=True)
    action_url = models.CharField(max_length=500, blank=True)
    action_text = models.CharField(max_length=100, blank=True)
    action_text_fr = models.CharField(max_length=100, blank=True)
    is_dismissible = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    priority = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-priority', '-created_at']
        verbose_name = 'Announcement Banner'
        verbose_name_plural = 'Announcement Banners'
        indexes = [
            models.Index(fields=['is_active', '-priority', '-created_at']),
        ]

    def __str__(self):
        return f"[{self.banner_type}] {self.message[:50]}"


class ContactDirectory(models.Model):
    """Contact directory for officials and organizations."""
    CATEGORY_CHOICES = [
        ('government', 'Government Official'),
        ('diplomat', 'Diplomat'),
        ('organization', 'Organization'),
        ('media', 'Media'),
        ('other', 'Other'),
    ]
    name = models.CharField(max_length=200)
    name_fr = models.CharField(max_length=200, blank=True)
    title = models.CharField(max_length=200, blank=True)
    title_fr = models.CharField(max_length=200, blank=True)
    department = models.CharField(max_length=200, blank=True)
    department_fr = models.CharField(max_length=200, blank=True)
    organization = models.CharField(max_length=200, blank=True)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='other')
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=50, blank=True)
    photo = models.ImageField(upload_to='contacts/', blank=True, validators=[validate_image_file])
    country = models.CharField(max_length=5, choices=NATIONALITY_CHOICES, blank=True)
    is_active = models.BooleanField(default=True)
    display_order = models.IntegerField(default=0)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'name']
        verbose_name = 'Contact Directory'
        verbose_name_plural = 'Contact Directory'

    def __str__(self):
        return f"{self.name} - {self.title}"


class LiveQASession(models.Model):
    """Live Q&A sessions for events."""
    title = models.CharField(max_length=200)
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='qa_sessions', null=True, blank=True)
    event_registration = models.ForeignKey(EventRegistration, on_delete=models.CASCADE, related_name='qa_sessions', null=True, blank=True)
    moderator = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='moderated_qa')
    is_active = models.BooleanField(default=False)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Live Q&A Session'
        verbose_name_plural = 'Live Q&A Sessions'

    def __str__(self):
        return self.title


class LiveQAQuestion(models.Model):
    """User-submitted question in a live Q&A session."""
    session = models.ForeignKey(LiveQASession, on_delete=models.CASCADE, related_name='questions')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='qa_questions')
    question = models.TextField()
    is_answered = models.BooleanField(default=False)
    is_approved = models.BooleanField(default=False, help_text='Moderator approved for display')
    upvote_count = models.PositiveIntegerField(default=0)
    answer = models.TextField(blank=True)
    answered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-upvote_count', '-created_at']
        verbose_name = 'Q&A Question'
        verbose_name_plural = 'Q&A Questions'

    def __str__(self):
        return f"Q: {self.question[:50]}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — User Preferences & Onboarding
# ══════════════════════════════════════════════════════════════

class UserPreference(models.Model):
    """User preferences and settings."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='preferences')
    theme = models.CharField(max_length=10, choices=[('light', 'Light'), ('dark', 'Dark'), ('system', 'System')], default='system')
    text_size = models.CharField(max_length=10, choices=[('small', 'Small'), ('medium', 'Medium'), ('large', 'Large')], default='medium')
    auto_play_videos = models.BooleanField(default=True)
    haptic_feedback = models.BooleanField(default=True)
    data_saver_mode = models.BooleanField(default=False, help_text='Reduce image quality and disable autoplay')
    onboarding_completed = models.BooleanField(default=False)
    onboarding_step = models.IntegerField(default=0)
    profile_completion = models.IntegerField(default=0, help_text='Profile completion percentage')
    # Interests for personalized content
    interests = models.JSONField(default=list, blank=True, help_text='List of interest tags')
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'User Preference'
        verbose_name_plural = 'User Preferences'

    def __str__(self):
        return f"{self.user.username}'s preferences"


class OnboardingStep(models.Model):
    """Configurable onboarding walkthrough steps."""
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='onboarding/', blank=True, validators=[validate_image_file])
    image_dark = models.ImageField(upload_to='onboarding/', blank=True, validators=[validate_image_file], help_text='Icon/logo for dark mode')
    icon_name = models.CharField(max_length=50, blank=True, help_text='Material icon name (fallback if no image)')
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Onboarding Step'
        verbose_name_plural = 'Onboarding Steps'

    def __str__(self):
        return f"Step {self.order}: {self.title}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Admin & Infrastructure
# ══════════════════════════════════════════════════════════════

class EmailTemplate(models.Model):
    """Customizable email templates for various notifications."""
    KEY_CHOICES = [
        ('welcome', 'Welcome Email'),
        ('verification_approved', 'Verification Approved'),
        ('verification_rejected', 'Verification Rejected'),
        ('event_confirmation', 'Event Registration Confirmation'),
        ('event_reminder', 'Event Reminder'),
        ('password_reset', 'Password Reset'),
        ('account_deactivated', 'Account Deactivated'),
        ('account_deletion', 'Account Deletion Scheduled'),
        ('admin_invite', 'Admin Invitation'),
        ('newsletter', 'Newsletter'),
    ]
    key = models.CharField(max_length=30, unique=True, choices=KEY_CHOICES)
    subject = models.CharField(max_length=200)
    subject_fr = models.CharField(max_length=200, blank=True)
    body_html = models.TextField(help_text='HTML template with {{ variable }} placeholders')
    body_html_fr = models.TextField(blank=True)
    body_text = models.TextField(blank=True, help_text='Plain text fallback')
    body_text_fr = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['key']
        verbose_name = 'Email Template'
        verbose_name_plural = 'Email Templates'

    def __str__(self):
        return f"{self.get_key_display()}"


class EmailCampaign(models.Model):
    """One-off marketing / broadcast email sent from the admin to a user audience."""
    AUDIENCE_CHOICES = [
        ('all', 'All active users'),
        ('newsletter', 'Newsletter subscribers'),
        ('language', 'By preferred language'),
        ('nationality', 'By nationality'),
        ('verified', 'Verified users only'),
        ('staff', 'Staff / admins only'),
        ('custom', 'Custom email list'),
    ]
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('sending', 'Sending'),
        ('sent', 'Sent'),
        ('failed', 'Failed'),
    ]

    name = models.CharField(max_length=120, help_text='Internal campaign name')
    subject = models.CharField(max_length=200)
    subject_fr = models.CharField(max_length=200, blank=True)
    body_html = models.TextField(help_text='HTML body. Use {{ user_name }} and {{ user_email }} as placeholders.')
    body_html_fr = models.TextField(blank=True)

    audience_type = models.CharField(max_length=20, choices=AUDIENCE_CHOICES, default='all')
    audience_language = models.CharField(max_length=5, blank=True, help_text="When audience_type='language'")
    audience_nationality = models.CharField(max_length=5, blank=True, help_text="When audience_type='nationality' (ISO code)")
    custom_recipients = models.TextField(blank=True, help_text='Comma- or newline-separated email list (for custom audience)')

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='draft')
    recipient_count = models.PositiveIntegerField(default=0)
    sent_count = models.PositiveIntegerField(default=0)
    failed_count = models.PositiveIntegerField(default=0)
    last_error = models.TextField(blank=True)

    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='email_campaigns')
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Email Campaign'
        verbose_name_plural = 'Email Campaigns'

    def __str__(self):
        return f"{self.name} ({self.get_status_display()})"


class EmailLog(models.Model):
    """Transparent log of every outgoing email (via LoggingEmailBackend)."""
    STATUS_CHOICES = [
        ('sent', 'Sent'),
        ('failed', 'Failed'),
    ]
    CATEGORY_CHOICES = [
        ('campaign', 'Campaign'),
        ('verification', 'Verification'),
        ('otp', 'OTP / Login'),
        ('event', 'Event'),
        ('support', 'Support'),
        ('system', 'System'),
        ('test', 'Test / Preview'),
        ('other', 'Other'),
    ]
    subject = models.CharField(max_length=255, blank=True)
    recipients = models.TextField(help_text='Comma-separated recipient emails')
    from_email = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    error = models.TextField(blank=True)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='other')
    body_preview = models.TextField(blank=True, help_text='First ~500 chars of HTML or text body')
    campaign = models.ForeignKey(EmailCampaign, on_delete=models.SET_NULL, null=True, blank=True, related_name='logs')
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Email Log'
        verbose_name_plural = 'Email Logs'
        indexes = [
            models.Index(fields=['status', 'created_at']),
            models.Index(fields=['category', 'created_at']),
        ]

    def __str__(self):
        return f"{self.get_status_display()} → {self.recipients[:60]}"


class Webhook(models.Model):
    """Webhook endpoints for external integrations."""
    EVENT_CHOICES = [
        ('user.registered', 'User Registered'),
        ('user.verified', 'User Verified'),
        ('event.created', 'Event Created'),
        ('event.registration', 'Event Registration'),
        ('article.published', 'Article Published'),
        ('support.ticket_created', 'Support Ticket Created'),
    ]
    SERVICE_TYPE_CHOICES = [
        ('slack', 'Slack'),
        ('teams', 'Microsoft Teams'),
        ('discord', 'Discord'),
        ('custom', 'Custom'),
    ]
    name = models.CharField(max_length=200)
    url = models.URLField(help_text='Endpoint to receive webhook POST')
    service_type = models.CharField(max_length=20, choices=SERVICE_TYPE_CHOICES, default='custom')
    events = models.JSONField(default=list, help_text='List of event keys to trigger')
    secret_key = models.CharField(max_length=255, blank=True, help_text='Shared secret for signature verification')
    custom_headers = models.JSONField(default=dict, blank=True, help_text='Custom HTTP headers as key-value pairs')
    is_active = models.BooleanField(default=True)
    last_triggered_at = models.DateTimeField(null=True, blank=True)
    failure_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Webhook'
        verbose_name_plural = 'Webhooks'

    def __str__(self):
        return f"{self.name} - {self.url}"


class WebhookLog(models.Model):
    """Log of webhook delivery attempts."""
    webhook = models.ForeignKey(Webhook, on_delete=models.CASCADE, related_name='logs')
    event = models.CharField(max_length=50)
    payload = models.JSONField()
    response_status = models.IntegerField(null=True, blank=True)
    response_body = models.TextField(blank=True)
    success = models.BooleanField(default=False)
    duration_ms = models.IntegerField(null=True, blank=True, help_text='Request duration in milliseconds')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Webhook Log'
        verbose_name_plural = 'Webhook Logs'

    def __str__(self):
        return f"{self.webhook.name} - {self.event} - {'OK' if self.success else 'FAIL'}"


class ScheduledMaintenance(models.Model):
    """Scheduled maintenance windows."""

    SEVERITY_CHOICES = [
        ('minor', 'Minor'),
        ('major', 'Major'),
        ('critical', 'Critical'),
    ]

    AFFECTED_SERVICES_CHOICES = [
        ('api', 'API'),
        ('auth', 'Authentication'),
        ('payments', 'Payments'),
        ('media', 'Media'),
        ('all', 'All Services'),
    ]

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    show_banner = models.BooleanField(default=True, help_text='Show maintenance banner in app')
    contact_email = models.EmailField(blank=True, help_text='Contact email for users during maintenance')
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='minor')
    affected_services = models.CharField(max_length=200, blank=True, default='all', help_text='Comma-separated list of affected services')
    auto_activate = models.BooleanField(default=False, help_text='Automatically enable maintenance at start time')
    image = models.ImageField(upload_to='maintenance/', blank=True, null=True, help_text='Full-screen image shown in the app during maintenance')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-starts_at']
        verbose_name = 'Scheduled Maintenance'
        verbose_name_plural = 'Scheduled Maintenance'
        indexes = [
            models.Index(fields=['is_active', 'starts_at', 'ends_at']),
        ]

    @property
    def is_currently_active(self):
        """Check if maintenance is currently in effect (active and within time window)."""
        now = timezone.now()
        return self.is_active and self.starts_at <= now <= self.ends_at

    @property
    def is_upcoming(self):
        """Check if maintenance is scheduled for the future."""
        return self.starts_at > timezone.now()

    @property
    def is_past(self):
        """Check if maintenance window has ended."""
        return self.ends_at < timezone.now()

    @property
    def duration_display(self):
        """Return human-readable duration."""
        delta = self.ends_at - self.starts_at
        hours, remainder = divmod(int(delta.total_seconds()), 3600)
        minutes = remainder // 60
        if hours > 0:
            return f"{hours}h {minutes}m"
        return f"{minutes}m"

    @property
    def affected_services_list(self):
        """Return affected services as a list."""
        if not self.affected_services:
            return []
        return [s.strip() for s in self.affected_services.split(',') if s.strip()]

    def __str__(self):
        return f"{self.title} ({self.starts_at} - {self.ends_at})"


class ABTest(models.Model):
    """A/B testing configuration."""
    TEST_TYPE_CHOICES = [
        ('content', 'Content'),
        ('layout', 'Layout'),
        ('feature', 'Feature Flag'),
        ('notification', 'Notification'),
    ]
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('running', 'Running'),
        ('paused', 'Paused'),
        ('completed', 'Completed'),
    ]
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    test_type = models.CharField(max_length=20, choices=TEST_TYPE_CHOICES, default='content')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    variant_a_label = models.CharField(max_length=100, default='Control')
    variant_b_label = models.CharField(max_length=100, default='Variant')
    variant_a_content_id = models.PositiveIntegerField(null=True, blank=True, help_text='Content ID for variant A')
    variant_b_content_id = models.PositiveIntegerField(null=True, blank=True, help_text='Content ID for variant B')
    traffic_split = models.IntegerField(default=50, help_text='Percentage of users who see variant B (0-100)')
    is_active = models.BooleanField(default=False)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    winner = models.CharField(max_length=1, choices=[('A', 'Variant A'), ('B', 'Variant B')], blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'A/B Test'
        verbose_name_plural = 'A/B Tests'

    def __str__(self):
        return self.name


class ABTestParticipant(models.Model):
    """Track which variant a user was assigned."""
    test = models.ForeignKey(ABTest, on_delete=models.CASCADE, related_name='participants')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ab_tests')
    variant = models.CharField(max_length=1, choices=[('A', 'Variant A'), ('B', 'Variant B')])
    converted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('test', 'user')
        verbose_name = 'A/B Test Participant'
        verbose_name_plural = 'A/B Test Participants'


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Analytics & Reporting
# ══════════════════════════════════════════════════════════════

class ContentAnalytics(models.Model):
    """Aggregated content analytics for dashboard."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('magazine', 'Magazine'),
        ('video', 'Video'),
        ('event', 'Event'),
    ]
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    content_id = models.PositiveIntegerField()
    date = models.DateField(db_index=True)
    views = models.PositiveIntegerField(default=0)
    likes = models.PositiveIntegerField(default=0)
    shares = models.PositiveIntegerField(default=0)
    comments = models.PositiveIntegerField(default=0)
    bookmarks = models.PositiveIntegerField(default=0)
    avg_read_time_seconds = models.PositiveIntegerField(default=0)

    class Meta:
        unique_together = ('content_type', 'content_id', 'date')
        ordering = ['-date']
        verbose_name = 'Content Analytics'
        verbose_name_plural = 'Content Analytics'
        indexes = [
            models.Index(fields=['content_type', 'date']),
        ]

    def __str__(self):
        return f"{self.content_type}:{self.content_id} on {self.date}"


class EngagementHeatmap(models.Model):
    """Hourly engagement data for heatmap visualization."""
    date = models.DateField(db_index=True)
    hour = models.IntegerField(help_text='0-23')
    active_users = models.PositiveIntegerField(default=0)
    page_views = models.PositiveIntegerField(default=0)
    actions = models.PositiveIntegerField(default=0, help_text='Likes, comments, shares, etc.')

    class Meta:
        unique_together = ('date', 'hour')
        ordering = ['-date', 'hour']
        verbose_name = 'Engagement Heatmap'
        verbose_name_plural = 'Engagement Heatmaps'

    def __str__(self):
        return f"{self.date} {self.hour}:00 - {self.active_users} users"


class WeeklyReport(models.Model):
    """Automated weekly analytics reports."""
    week_start = models.DateField()
    week_end = models.DateField()
    report_data = models.JSONField(help_text='Full report data as JSON')
    new_users = models.PositiveIntegerField(default=0)
    active_users = models.PositiveIntegerField(default=0)
    total_views = models.PositiveIntegerField(default=0)
    total_engagements = models.PositiveIntegerField(default=0)
    top_content = models.JSONField(default=list, help_text='Top performing content')
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-week_start']
        verbose_name = 'Weekly Report'
        verbose_name_plural = 'Weekly Reports'
        unique_together = ('week_start', 'week_end')

    def __str__(self):
        return f"Weekly Report {self.week_start} - {self.week_end}"


class FunnelStep(models.Model):
    """Define steps in a conversion funnel."""
    funnel_name = models.CharField(max_length=100, db_index=True, help_text='e.g. registration, verification, event_signup')
    step_name = models.CharField(max_length=100)
    step_order = models.IntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('funnel_name', 'step_order')
        ordering = ['funnel_name', 'step_order']
        verbose_name = 'Funnel Step'
        verbose_name_plural = 'Funnel Steps'

    def __str__(self):
        return f"{self.funnel_name} - Step {self.step_order}: {self.step_name}"


class FunnelEvent(models.Model):
    """Track user progress through funnels."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='funnel_events')
    funnel_step = models.ForeignKey(FunnelStep, on_delete=models.CASCADE, related_name='events')
    completed = models.BooleanField(default=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Funnel Event'
        verbose_name_plural = 'Funnel Events'

    def __str__(self):
        return f"{self.user.username} - {self.funnel_step}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Localization
# ══════════════════════════════════════════════════════════════

class TranslationEntry(models.Model):
    """Translation management for dynamic content."""
    STATUS_CHOICES = [
        ('pending', 'Pending Translation'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('reviewed', 'Reviewed'),
    ]
    key = models.CharField(max_length=200, unique=True, help_text='Unique translation key')
    source_text = models.TextField(help_text='Original text (English)')
    translated_text = models.TextField(blank=True, help_text='Translated text (French)')
    context = models.CharField(max_length=200, blank=True, help_text='Where this text appears')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    translated_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_translations')
    auto_translated = models.BooleanField(default=False, help_text='Was this auto-translated?')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['key']
        verbose_name = 'Translation Entry'
        verbose_name_plural = 'Translation Entries'

    def __str__(self):
        return f"{self.key}: {self.source_text[:50]}"


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — What's New & App Updates
# ══════════════════════════════════════════════════════════════

class AppRelease(models.Model):
    """Track app releases for What's New dialog and update prompts."""
    version = models.CharField(max_length=20, unique=True, help_text='e.g. 2.1.0')
    version_code = models.IntegerField(unique=True, help_text='Integer version code for comparison')
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    release_notes = models.TextField(blank=True, help_text='Optional free-form summary (deprecated in favor of highlights)')
    release_notes_fr = models.TextField(blank=True)
    is_force_update = models.BooleanField(default=False, help_text='Force users to update')
    min_supported_version = models.CharField(max_length=20, blank=True, help_text='Minimum app version still supported')
    android_url = models.URLField(blank=True, help_text='Google Play Store URL')
    ios_url = models.URLField(blank=True, help_text='Apple App Store URL')
    popup_delay_seconds = models.PositiveIntegerField(
        default=2,
        help_text='How many seconds after app launch to show the What\'s New popup (0 = immediately).'
    )
    is_published = models.BooleanField(
        default=True,
        help_text='When unchecked, the popup is hidden from users even if the version matches.'
    )
    released_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-version_code']
        verbose_name = 'App Release'
        verbose_name_plural = 'App Releases'

    def __str__(self):
        return f"v{self.version} - {self.title}"


class AppReleaseHighlight(models.Model):
    """Individual changelog item shown inside the What's New popup."""
    release = models.ForeignKey(
        AppRelease, on_delete=models.CASCADE, related_name='highlights'
    )
    order = models.PositiveIntegerField(default=0, help_text='Display order (lower = shown first).')
    icon_name = models.CharField(
        max_length=60,
        default='star_rounded',
        help_text='Material icon name (e.g. "forum_rounded", "notifications_active_rounded").',
    )
    title_en = models.CharField(max_length=120)
    title_fr = models.CharField(max_length=120, blank=True)
    subtitle_en = models.TextField()
    subtitle_fr = models.TextField(blank=True)

    class Meta:
        ordering = ['order', 'id']
        verbose_name = 'App Release Highlight'
        verbose_name_plural = 'App Release Highlights'

    def __str__(self):
        return f"{self.release.version} — {self.title_en}"


class RateLimitLog(models.Model):
    """Logs throttled (429) requests for the rate limiting dashboard."""
    ip_address = models.GenericIPAddressField(db_index=True)
    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='rate_limit_logs')
    endpoint = models.CharField(max_length=255, db_index=True)
    throttle_class = models.CharField(max_length=100, blank=True, help_text='DRF throttle class that triggered the block')
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    request_method = models.CharField(max_length=10)
    was_blocked = models.BooleanField(default=True, help_text='True if request was rejected (429)')
    user_agent = models.TextField(blank=True)

    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['-timestamp', 'ip_address']),
            models.Index(fields=['-timestamp', 'endpoint']),
        ]
        verbose_name = 'Rate Limit Log'
        verbose_name_plural = 'Rate Limit Logs'

    def __str__(self):
        return f"[{self.request_method}] {self.endpoint} from {self.ip_address} at {self.timestamp}"


class AdminActivityLog(models.Model):
    """Tracks all admin staff actions for the audit trail / activity log page."""
    ACTION_TYPE_CHOICES = [
        ('create', 'Create'),
        ('update', 'Update'),
        ('delete', 'Delete'),
        ('login', 'Login'),
        ('logout', 'Logout'),
        ('export', 'Export'),
        ('approve', 'Approve'),
        ('reject', 'Reject'),
        ('bulk_action', 'Bulk Action'),
        ('status_change', 'Status Change'),
        ('send_notification', 'Send Notification'),
        ('backup', 'Backup'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='admin_activity_logs'
    )
    action_type = models.CharField(max_length=30, choices=ACTION_TYPE_CHOICES)
    model_name = models.CharField(max_length=100, blank=True, help_text='e.g. Article, User, Event')
    object_id = models.IntegerField(null=True, blank=True, help_text='PK of the affected object')
    object_repr = models.CharField(max_length=255, blank=True, help_text='String representation of the object')
    changes = models.JSONField(default=dict, blank=True, help_text='Dict of field changes {field: {old: x, new: y}}')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    path = models.CharField(max_length=500, blank=True, help_text='Request URL path')
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Admin Activity Log'
        verbose_name_plural = 'Admin Activity Logs'
        indexes = [
            models.Index(fields=['-timestamp']),
            models.Index(fields=['user', '-timestamp']),
            models.Index(fields=['action_type', '-timestamp']),
        ]

    def __str__(self):
        user_str = self.user.username if self.user else 'Unknown'
        return f"{user_str} {self.action_type} {self.model_name} ({self.object_repr})"


# ── Database Backup Tracking ─────────────────────────────────
class DatabaseBackup(models.Model):
    """Tracks database backup files created through the admin portal."""
    BACKUP_TYPE_CHOICES = [
        ('full', 'Full Backup'),
        ('data_only', 'Data Only'),
        ('schema_only', 'Schema Only'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ]

    filename = models.CharField(max_length=255)
    file_path = models.CharField(max_length=500)
    file_size = models.BigIntegerField(default=0)
    backup_type = models.CharField(max_length=20, choices=BACKUP_TYPE_CHOICES, default='full')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='database_backups')
    created_at = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True)
    error_message = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Database Backup'
        verbose_name_plural = 'Database Backups'

    def __str__(self):
        return f"{self.filename} ({self.get_status_display()})"


# ── User Segmentation ────────────────────────────────────────
class UserSegment(models.Model):
    """
    Defines a user segment for targeted notifications and analytics.
    Segments can be dynamic (filter-based, recalculated on access) or
    static (manually curated membership list).
    """
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    filters = models.JSONField(
        default=dict,
        blank=True,
        help_text='JSON filter criteria: nationality, gender, badge_type, age_range, registered_after/before, has_verified_email, is_active'
    )
    is_dynamic = models.BooleanField(
        default=True,
        help_text='Dynamic segments recalculate members from filters on every access'
    )
    created_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name='created_segments'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'User Segment'
        verbose_name_plural = 'User Segments'

    def __str__(self):
        return self.name

    def get_users(self):
        """
        Return a User queryset matching this segment.
        Dynamic segments build a queryset from the JSON filters.
        Static segments return users from UserSegmentMembership.
        """
        from datetime import date, timedelta
        from django.db.models import Q

        if not self.is_dynamic:
            user_ids = self.memberships.values_list('user_id', flat=True)
            return User.objects.filter(pk__in=user_ids)

        filters = self.filters or {}
        qs = User.objects.all().select_related('profile')

        # Nationality filter (list of ISO codes)
        nationalities = filters.get('nationality', [])
        if nationalities:
            qs = qs.filter(profile__nationality__in=nationalities)

        # Gender filter (list)
        genders = filters.get('gender', [])
        if genders:
            qs = qs.filter(profile__gender__in=genders)

        # Badge type filter (list)
        badge_types = filters.get('badge_type', [])
        if badge_types:
            badge_q = Q()
            normalized = [b.upper() for b in badge_types]
            if 'NONE' in normalized:
                badge_q |= Q(profile__badge_type__isnull=True) | Q(profile__badge_type='')
                normalized = [b for b in normalized if b != 'NONE']
            if normalized:
                badge_q |= Q(profile__badge_type__in=normalized)
            qs = qs.filter(badge_q)

        # Age range filter
        age_range = filters.get('age_range', {})
        if age_range:
            today = date.today()
            age_min = age_range.get('min')
            age_max = age_range.get('max')
            if age_min is not None:
                max_dob = today.replace(year=today.year - int(age_min))
                qs = qs.filter(profile__date_of_birth__lte=max_dob)
            if age_max is not None:
                min_dob = today.replace(year=today.year - int(age_max) - 1)
                qs = qs.filter(profile__date_of_birth__gte=min_dob)

        # Registration date filters
        registered_after = filters.get('registered_after')
        if registered_after:
            qs = qs.filter(date_joined__date__gte=registered_after)

        registered_before = filters.get('registered_before')
        if registered_before:
            qs = qs.filter(date_joined__date__lte=registered_before)

        # Email verified filter
        has_verified_email = filters.get('has_verified_email')
        if has_verified_email is True:
            qs = qs.filter(profile__is_email_verified=True)
        elif has_verified_email is False:
            qs = qs.filter(profile__is_email_verified=False)

        # Active status filter
        is_active = filters.get('is_active')
        if is_active is True:
            qs = qs.filter(is_active=True)
        elif is_active is False:
            qs = qs.filter(is_active=False)

        return qs.distinct()

    def get_member_count(self):
        """Return the number of users in this segment."""
        return self.get_users().count()


class UserSegmentMembership(models.Model):
    """
    Tracks manual membership for static (non-dynamic) segments.
    """
    segment = models.ForeignKey(
        UserSegment, on_delete=models.CASCADE, related_name='memberships'
    )
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='segment_memberships'
    )
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('segment', 'user')
        ordering = ['-added_at']
        verbose_name = 'Segment Membership'
        verbose_name_plural = 'Segment Memberships'

    def __str__(self):
        return f"{self.user.username} in {self.segment.name}"


# ══════════════════════════════════════════════════════════════
# Admin Portal Real-Time Notifications
# ══════════════════════════════════════════════════════════════

class AdminNotification(models.Model):
    """Real-time notifications for admin staff in the admin portal."""
    NOTIFICATION_TYPE_CHOICES = [
        ('new_ticket', 'New Support Ticket'),
        ('new_verification', 'New Verification Request'),
        ('new_user', 'New User Registration'),
        ('ticket_reply', 'Ticket Reply'),
        ('system_alert', 'System Alert'),
        ('content_flagged', 'Content Flagged'),
    ]

    notification_type = models.CharField(
        max_length=20,
        choices=NOTIFICATION_TYPE_CHOICES,
        help_text='Category of admin notification'
    )
    title = models.CharField(max_length=200, help_text='Short notification title')
    message = models.TextField(help_text='Notification detail message')
    link = models.CharField(
        max_length=500,
        blank=True,
        help_text='URL to navigate to when notification is clicked'
    )
    icon = models.CharField(
        max_length=50,
        default='notifications',
        help_text='Material Symbols icon name'
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Admin Notification'
        verbose_name_plural = 'Admin Notifications'
        indexes = [
            models.Index(fields=['is_read', '-created_at']),
        ]

    def __str__(self):
        return f"[{self.get_notification_type_display()}] {self.title}"

    @property
    def time_ago(self):
        """Return a human-readable relative time string."""
        from django.utils import timezone
        now = timezone.now()
        diff = now - self.created_at
        seconds = int(diff.total_seconds())
        if seconds < 60:
            return 'just now'
        minutes = seconds // 60
        if minutes < 60:
            return f'{minutes}m ago'
        hours = minutes // 60
        if hours < 24:
            return f'{hours}h ago'
        days = hours // 24
        if days < 7:
            return f'{days}d ago'
        weeks = days // 7
        if weeks < 4:
            return f'{weeks}w ago'
        return self.created_at.strftime('%b %d')


# ══════════════════════════════════════════════════════════════
# Content Versioning - Article Revisions
# ══════════════════════════════════════════════════════════════

class ArticleRevision(models.Model):
    """Track revisions of articles with rollback capability."""
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='revisions')
    revision_number = models.PositiveIntegerField()
    title = models.CharField(max_length=300)
    content = models.TextField()
    edited_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    change_summary = models.CharField(max_length=500, blank=True)

    class Meta:
        unique_together = ('article', 'revision_number')
        ordering = ['-revision_number']
        verbose_name = 'Article Revision'
        verbose_name_plural = 'Article Revisions'

    def __str__(self):
        return f"{self.article.title[:30]} - Revision {self.revision_number}"


# ══════════════════════════════════════════════════════════════
# Content Translation Queue
# ══════════════════════════════════════════════════════════════

class TranslationRequest(models.Model):
    """Translation workflow queue for EN->FR content."""
    CONTENT_TYPE_CHOICES = [
        ('article', 'Article'),
        ('event', 'Event'),
        ('feature_card', 'Feature Card'),
        ('notification', 'Notification'),
        ('magazine', 'Magazine'),
        ('resource', 'Resource'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('rejected', 'Rejected'),
    ]

    content_type = models.CharField(max_length=20, choices=CONTENT_TYPE_CHOICES)
    object_id = models.PositiveIntegerField()
    source_language = models.CharField(max_length=5, default='en')
    target_language = models.CharField(max_length=5, default='fr')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    assigned_to = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='translation_assignments'
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Translation Request'
        verbose_name_plural = 'Translation Requests'

    def __str__(self):
        return f"{self.content_type}:{self.object_id} ({self.source_language}->{self.target_language}) [{self.status}]"


# ── Event Agenda Item Model ───────────────────────────────────
class EventAgendaItem(models.Model):
    """Individual agenda items/sessions within an event, supporting multi-track schedules."""
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='agenda_items')
    title = models.CharField(max_length=300)
    description = models.TextField(blank=True)
    speaker = models.ForeignKey(EventSpeaker, on_delete=models.SET_NULL, null=True, blank=True, related_name='agenda_items')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    room = models.CharField(max_length=200, blank=True)
    track = models.CharField(max_length=200, blank=True, help_text='Track name for multi-track events')
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['start_time', 'order']
        verbose_name = 'Event Agenda Item'
        verbose_name_plural = 'Event Agenda Items'

    def __str__(self):
        return f"{self.event.name} - {self.title}"


# ══════════════════════════════════════════════════════════════
# Account Linking — multi-provider auth consolidation
# ══════════════════════════════════════════════════════════════

class LinkedAccount(models.Model):
    """Tracks auth providers linked to a single user account.

    Allows users to sign in via multiple providers (Google, Apple, email/password)
    and link them all to one unified account.
    """
    PROVIDER_CHOICES = [
        ('email', 'Email/Password'),
        ('google', 'Google'),
        ('apple', 'Apple'),
        ('firebase', 'Firebase'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='linked_accounts')
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES)
    provider_uid = models.CharField(max_length=255, help_text='Unique user ID from the auth provider')
    email = models.EmailField(blank=True, default='')
    display_name = models.CharField(max_length=200, blank=True, default='')
    linked_at = models.DateTimeField(auto_now_add=True)
    is_primary = models.BooleanField(default=False, help_text='Whether this is the primary auth method')

    class Meta:
        unique_together = ['provider', 'provider_uid']
        ordering = ['-is_primary', '-linked_at']
        verbose_name = 'Linked Account'
        verbose_name_plural = 'Linked Accounts'

    def __str__(self):
        return f"{self.user.username} - {self.get_provider_display()} ({self.email or self.provider_uid})"


# ── Auto-optimize images on upload ────────────────────────────
def _auto_optimize_image(sender, instance, **kwargs):
    """Convert uploaded images to WebP on save for all core models."""
    from .image_utils import optimize_image
    for field in sender._meta.get_fields():
        if not isinstance(field, models.ImageField):
            continue
        image = getattr(instance, field.name, None)
        if not image or not image.name:
            continue
        if image.name.endswith('.webp'):
            continue
        # Only optimize genuine new uploads — skip files already committed
        # to storage (e.g. existing paths assigned from the media library).
        if getattr(image, '_committed', True):
            continue
        try:
            optimize_image(image, max_width=1200)
        except Exception:
            pass


# ══════════════════════════════════════════════════════════════
# NEW FEATURE MODELS — Social & Engagement
# ══════════════════════════════════════════════════════════════

class EventComment(models.Model):
    """User comments on events for discussions."""
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_comments_authored')
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies')
    content = models.TextField()
    is_approved = models.BooleanField(default=True)
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Event Comment'
        verbose_name_plural = 'Event Comments'
        indexes = [
            models.Index(fields=['event', '-created_at']),
        ]

    def __str__(self):
        return f"{self.user.username} on {self.event.name[:30]}"


class CommentMention(models.Model):
    """Tracks @mentions in event comments."""
    comment = models.ForeignKey(EventComment, on_delete=models.CASCADE, related_name='mentions')
    mentioned_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comment_mentions')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('comment', 'mentioned_user')
        verbose_name = 'Comment Mention'
        verbose_name_plural = 'Comment Mentions'

    def __str__(self):
        return f"@{self.mentioned_user.username} in comment #{self.comment_id}"


class EventLike(models.Model):
    """Tracks which users liked which events."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_likes')
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'event')

    def __str__(self):
        return f"{self.user.username} likes {self.event.name[:30]}"


class VideoComment(models.Model):
    """User comments on videos."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='video_comments')
    video = models.ForeignKey(Video, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies',
        help_text='Parent comment for threaded replies (1 level deep).'
    )
    content = models.TextField()
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['video', '-created_at']),
            models.Index(fields=['parent']),
        ]

    def __str__(self):
        return f"{self.user.username} on {self.video.title[:30]}"


class GalleryComment(models.Model):
    """User comments on gallery albums."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='gallery_comments')
    album = models.ForeignKey(GalleryAlbum, on_delete=models.CASCADE, related_name='comments')
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies',
        help_text='Parent comment for threaded replies (1 level deep).'
    )
    content = models.TextField()
    like_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['album', '-created_at']),
            models.Index(fields=['parent']),
        ]

    def __str__(self):
        return f"{self.user.username} on {self.album.title[:30]}"


class DiscussionLike(models.Model):
    """Tracks which users liked which discussions."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='discussion_likes')
    discussion = models.ForeignKey(Discussion, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'discussion')

    def __str__(self):
        return f"{self.user.username} likes {self.discussion.title[:30]}"


class ArticleCommentLike(models.Model):
    """Tracks which users liked which article comments."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_comment_likes')
    comment = models.ForeignKey(ArticleComment, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes article comment #{self.comment_id}"


class MagazineCommentLike(models.Model):
    """Tracks which users liked which magazine comments."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='magazine_comment_likes')
    comment = models.ForeignKey(MagazineComment, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes magazine comment #{self.comment_id}"


class VideoCommentLike(models.Model):
    """Tracks which users liked which video comments."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='video_comment_likes')
    comment = models.ForeignKey(VideoComment, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes video comment #{self.comment_id}"


class GalleryCommentLike(models.Model):
    """Tracks which users liked which gallery comments."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='gallery_comment_likes')
    comment = models.ForeignKey(GalleryComment, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes gallery comment #{self.comment_id}"


class EventCommentLike(models.Model):
    """Tracks which users liked which event comments."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_comment_likes')
    comment = models.ForeignKey(EventComment, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes event comment #{self.comment_id}"


class DiscussionReplyLike(models.Model):
    """Tracks which users liked which discussion replies."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='discussion_reply_likes')
    comment = models.ForeignKey(DiscussionReply, on_delete=models.CASCADE, related_name='comment_likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment')

    def __str__(self):
        return f"{self.user.username} likes discussion reply #{self.comment_id}"


class AppOpenEvent(models.Model):
    """Tracks each time the app is opened."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='app_opens')
    device_id = models.CharField(max_length=255, blank=True, help_text='Anonymous device identifier for guest tracking')
    device_type = models.CharField(max_length=50, blank=True)
    device_os = models.CharField(max_length=50, blank=True)
    app_version = models.CharField(max_length=20, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    country_code = models.CharField(max_length=5, blank=True)
    opened_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-opened_at']
        indexes = [
            models.Index(fields=['-opened_at']),
            models.Index(fields=['user', '-opened_at']),
        ]

    def __str__(self):
        user_label = self.user.username if self.user else f'guest:{self.device_id[:8]}'
        return f"{user_label} at {self.opened_at}"


class NewsletterEdition(models.Model):
    """Monthly newsletter editions sent to subscribers."""
    subject = models.CharField(max_length=300)
    body_html = models.TextField()
    sent_at = models.DateTimeField(null=True, blank=True)
    recipient_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Newsletter Edition'
        verbose_name_plural = 'Newsletter Editions'

    def __str__(self):
        status = f"Sent to {self.recipient_count}" if self.sent_at else "Draft"
        return f"{self.subject} ({status})"


class NewsletterSubscriber(models.Model):
    """Monthly newsletter subscribers with contact details."""
    user = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='newsletter_subscriptions',
        help_text='Linked app user (if subscribed while logged in)'
    )
    name = models.CharField(max_length=200)
    email = models.EmailField()
    phone_number = models.CharField(max_length=30, blank=True, default='')
    subscribed_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True, help_text='Uncheck to unsubscribe')

    class Meta:
        ordering = ['-subscribed_at']
        verbose_name = 'Newsletter Subscriber'
        verbose_name_plural = 'Newsletter Subscribers'
        constraints = [
            models.UniqueConstraint(fields=['email'], name='unique_subscriber_email'),
        ]

    def __str__(self):
        return f"{self.name} ({self.email})"


# ═══════════════════════════════════════════════════════════════
#  YOUTH DIALOGUE SETTINGS (Singleton)
# ═══════════════════════════════════════════════════════════════

class YouthDialogueSettings(models.Model):
    """Admin-configurable branding and support info for the Youth Dialogue section."""

    # Branding
    logo_light = models.ImageField(upload_to='youth_dialogue/', blank=True, validators=[validate_image_file],
                                   help_text='Horizontal logo for light mode')
    logo_dark = models.ImageField(upload_to='youth_dialogue/', blank=True, validators=[validate_image_file],
                                  help_text='Horizontal logo for dark mode')
    programme_title = models.CharField(max_length=200, default='Youth Dialogue Programme')
    programme_title_fr = models.CharField(max_length=200, blank=True, default='Programme du Dialogue de la Jeunesse')
    description = models.TextField(default='Join the African Union Youth Dialogue and contribute to shaping the continent\'s future. Apply now to participate in this prestigious programme.')
    description_fr = models.TextField(blank=True, default='Rejoignez le Dialogue de la Jeunesse de l\'Union Africaine et contribuez à façonner l\'avenir du continent.')

    # Visibility & Quick Access
    is_visible = models.BooleanField(default=True, help_text='Show Youth Dialogue in Quick Access grid')
    quick_access_icon = models.ImageField(upload_to='youth_dialogue/', blank=True, validators=[validate_image_file],
                                          help_text='Custom icon for Quick Access grid')
    quick_access_title_en = models.CharField(max_length=50, blank=True, default='Youth Dialogue',
                                              help_text='Quick Access button title (EN)')
    quick_access_title_fr = models.CharField(max_length=50, blank=True, default='Dialogue Jeunesse',
                                              help_text='Quick Access button title (FR)')

    # Registration control
    is_registration_open = models.BooleanField(default=True, help_text='Whether new applications are accepted')
    registration_closed_message = models.TextField(blank=True, default='Registration is currently closed. Please check back later.')
    registration_closed_message_fr = models.TextField(blank=True, default='Les inscriptions sont actuellement fermées. Veuillez réessayer plus tard.')

    # Support & Contact
    support_email = models.EmailField(blank=True, default='', help_text='Contact email for Youth Dialogue support')
    support_phone = models.CharField(max_length=30, blank=True, default='', help_text='Contact phone number')
    live_chat_url = models.URLField(blank=True, default='', help_text='URL for live chat support (e.g. WhatsApp, Tawk.to)')
    support_note = models.TextField(blank=True, default='Need help? Reach out to our support team for assistance with your application.',
                                    help_text='Text shown above contact options')
    support_note_fr = models.TextField(blank=True, default='Besoin d\'aide ? Contactez notre équipe de support pour obtenir de l\'aide avec votre candidature.')

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Youth Dialogue Settings'
        verbose_name_plural = 'Youth Dialogue Settings'

    def __str__(self):
        return 'Youth Dialogue Settings'

    def save(self, *args, **kwargs):
        # Singleton: ensure only one instance
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def load(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class YouthDialogueFormField(models.Model):
    """Dynamic form fields for the Youth Dialogue application form."""
    FIELD_TYPE_CHOICES = [
        ('text', 'Text Input'),
        ('email', 'Email'),
        ('phone', 'Phone Number'),
        ('textarea', 'Text Area'),
        ('number', 'Number'),
        ('date', 'Date'),
        ('time', 'Time'),
        ('file', 'File Upload'),
        ('image', 'Image Upload'),
        ('select', 'Dropdown Select'),
        ('radio', 'Radio Buttons'),
        ('checkbox', 'Single Checkbox'),
        ('multi_checkbox', 'Multiple Checkboxes'),
        ('country', 'Country Selector'),
        ('nationality', 'Nationality'),
        ('passport', 'Passport Number'),
        ('url', 'URL / Website'),
    ]

    settings = models.ForeignKey(YouthDialogueSettings, on_delete=models.CASCADE, related_name='form_fields')
    field_type = models.CharField(max_length=20, choices=FIELD_TYPE_CHOICES)
    field_label = models.CharField(max_length=200, help_text='Label shown to user')
    field_label_fr = models.CharField(max_length=200, blank=True)
    field_name = models.CharField(max_length=100, help_text='Internal field name (e.g., "first_name", "motivation")')
    placeholder = models.CharField(max_length=200, blank=True)
    placeholder_fr = models.CharField(max_length=200, blank=True)

    is_required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True, help_text='Show/hide this field')
    options = models.JSONField(default=list, blank=True, help_text='For select/radio/multi_checkbox: ["Option 1", "Option 2"]')
    validation_regex = models.CharField(max_length=500, blank=True, help_text='Optional regex for validation')
    help_text = models.CharField(max_length=300, blank=True)
    help_text_fr = models.CharField(max_length=300, blank=True)
    max_length = models.IntegerField(null=True, blank=True)
    min_length = models.IntegerField(null=True, blank=True)

    order = models.IntegerField(default=0)

    class Meta:
        ordering = ['order']
        verbose_name = 'Youth Dialogue Form Field'
        verbose_name_plural = 'Youth Dialogue Form Fields'

    def __str__(self):
        return f"{self.field_label} ({self.get_field_type_display()})"


# ═══════════════════════════════════════════════════════════════
#  YOUTH DIALOGUE APPLICATION SYSTEM
# ═══════════════════════════════════════════════════════════════

class YouthDialogueApplication(models.Model):
    """Youth Dialogue application — one per user, with multi-step status pipeline."""

    STATUS_CHOICES = [
        ('submitted', 'Submitted'),
        ('under_review', 'Under Review'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('documents_pending', 'Documents Pending'),
        ('documents_submitted', 'Documents Submitted'),
        ('documents_under_review', 'Documents Under Review'),
        ('documents_rejected', 'Documents Rejected'),
        ('credential_issued', 'Credential Issued'),
    ]

    TITLE_CHOICES = [
        ('mr', 'Mr.'), ('mrs', 'Mrs.'), ('ms', 'Ms.'), ('dr', 'Dr.'),
        ('prof', 'Prof.'), ('he', 'H.E. (His/Her Excellency)'),
        ('amb', 'Ambassador'), ('hon', 'Honorable'), ('other', 'Other'),
    ]

    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='youth_dialogue_application')

    # Step 1 form fields
    title = models.CharField(max_length=10, choices=TITLE_CHOICES, blank=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField(db_index=True, help_text='Contact email for this application')
    phone_number = models.CharField(max_length=30, blank=True)
    country_code = models.CharField(max_length=5, blank=True)
    nationality = models.CharField(max_length=5, choices=NATIONALITY_CHOICES, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, blank=True)
    organization = models.CharField(max_length=200, blank=True)
    position = models.CharField(max_length=200, blank=True)
    motivation = models.TextField(blank=True, help_text='Why the applicant wants to participate')
    additional_data = models.JSONField(default=dict, blank=True, help_text='Flexible extra fields')

    # Status pipeline
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='submitted')

    # Application review
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='yd_reviewed_apps')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)

    # Document review
    documents_reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='yd_doc_reviewed_apps')
    documents_reviewed_at = models.DateTimeField(null=True, blank=True)
    documents_rejection_notes = models.TextField(blank=True)

    # Credential
    participant_code = models.CharField(max_length=20, unique=True, blank=True, null=True, help_text='Format: YD-2026-0001')
    qr_hash = models.CharField(max_length=64, blank=True, db_index=True)
    credential_issued_at = models.DateTimeField(null=True, blank=True)
    id_photo = models.ImageField(upload_to='youth_dialogue/id_photos/', blank=True, null=True, help_text='Passport photo for ID card')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Youth Dialogue Application'
        verbose_name_plural = 'Youth Dialogue Applications'
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['email']),
        ]

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.get_status_display()})"

    def generate_participant_code(self):
        """Generate sequential participant code: YD-YYYY-NNNN"""
        from django.utils import timezone as tz
        year = tz.now().year
        prefix = f'YD-{year}-'
        existing = YouthDialogueApplication.objects.filter(
            participant_code__startswith=prefix
        ).count()
        self.participant_code = f'{prefix}{existing + 1:04d}'
        return self.participant_code

    def generate_qr_hash(self):
        """Generate a unique hash for QR code validation."""
        import hashlib
        raw = f"{self.id}:{self.user_id}:{self.participant_code}:{self.created_at}"
        self.qr_hash = hashlib.sha256(raw.encode()).hexdigest()[:32]
        return self.qr_hash


class YouthDialogueDocument(models.Model):
    """Documents uploaded for a Youth Dialogue application."""

    DOCUMENT_TYPE_CHOICES = [
        ('passport', 'Passport Copy'),
        ('national_id', 'National ID'),
        ('photo', 'Passport Photo'),
        ('cv', 'CV / Resume'),
        ('recommendation', 'Recommendation Letter'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    application = models.ForeignKey(YouthDialogueApplication, on_delete=models.CASCADE, related_name='documents')
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPE_CHOICES)
    file = models.FileField(upload_to='youth_dialogue/documents/')
    original_filename = models.CharField(max_length=255, blank=True)
    file_size = models.PositiveIntegerField(default=0, help_text='File size in bytes')

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    rejection_reason = models.TextField(blank=True)

    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='yd_doc_reviews')
    reviewed_at = models.DateTimeField(null=True, blank=True)

    # Resubmission tracking
    is_resubmission = models.BooleanField(default=False)
    replaces = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='replacements')

    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded_at']
        verbose_name = 'Youth Dialogue Document'
        verbose_name_plural = 'Youth Dialogue Documents'

    def __str__(self):
        return f"{self.get_document_type_display()} - {self.application}"


class YouthDialogueActivityLog(models.Model):
    """Activity tracking for the Youth Dialogue feature."""

    ACTION_CHOICES = [
        ('screen_visit', 'Screen Visit'),
        ('form_started', 'Form Started'),
        ('form_submitted', 'Form Submitted'),
        ('document_uploaded', 'Document Uploaded'),
        ('document_deleted', 'Document Deleted'),
        ('status_viewed', 'Status Viewed'),
        ('credential_viewed', 'Credential Viewed'),
        ('credential_shared', 'Credential Shared'),
        ('qr_scanned', 'QR Scanned'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='yd_activity_logs')
    application = models.ForeignKey(YouthDialogueApplication, on_delete=models.SET_NULL, null=True, blank=True, related_name='activity_logs')
    action = models.CharField(max_length=30, choices=ACTION_CHOICES)
    screen_name = models.CharField(max_length=100, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Youth Dialogue Activity Log'
        verbose_name_plural = 'Youth Dialogue Activity Logs'
        indexes = [
            models.Index(fields=['user', '-timestamp']),
            models.Index(fields=['action', '-timestamp']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.get_action_display()} at {self.timestamp}"


# Connect to all core models with image fields
from django.db.models.signals import pre_save  # noqa: E402
for _model in [
    HeroSlide, MagazineEdition, MagazineImage, Article, ArticleMedia,
    EmbassyLocation, Event, LiveFeed, FeatureCard, FeatureCardMedia,
    Notification, PriorityAgenda, GalleryAlbum, GalleryPhoto, Video,
    VerificationRequest, WeatherCity, Popup, UserProfile,
    # New models with image fields
    ArticleDraft, ArticleSeries, EventSpeaker, EventPhoto,
    DirectMessage, ContactDirectory, OnboardingStep,
]:
    pre_save.connect(_auto_optimize_image, sender=_model)
