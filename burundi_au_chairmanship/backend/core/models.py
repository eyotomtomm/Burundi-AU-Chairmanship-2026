import io
import logging

from django.db import models
from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.db.models.signals import post_save
from django.dispatch import receiver

from .validators import validate_image_file, validate_document_file, validate_fcm_token, validate_professional_email

logger = logging.getLogger(__name__)

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
        choices=[('GOLD', 'Gold Badge'), ('BLUE', 'Blue Badge')],
        blank=True,
        null=True,
        help_text='Type of verification badge (Gold for VIPs, Blue for regular verified users)'
    )
    verification_requested_at = models.DateTimeField(null=True, blank=True, help_text='When user requested verification')
    email_verified_at = models.DateTimeField(null=True, blank=True)
    government_verified_at = models.DateTimeField(null=True, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True, help_text='When admin approved verification')

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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-publish_date']

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
    title = models.CharField(max_length=300)
    title_fr = models.CharField(max_length=300, blank=True)
    content = models.TextField()
    content_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='articles/', blank=True, validators=[validate_image_file])
    author = models.CharField(max_length=100)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, null=True, blank=True, related_name='articles')
    publish_date = models.DateTimeField()
    is_featured = models.BooleanField(default=False)
    view_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-publish_date']

    def __str__(self):
        return self.title


class ArticleComment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='article_comments')
    article = models.ForeignKey(Article, on_delete=models.CASCADE, related_name='comments')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} on {self.article.title[:30]}"


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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['event_date']

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
    duration = models.CharField(max_length=50, blank=True, help_text='e.g. 1h 30m')
    scheduled_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['category', 'title']

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


class EventRegistration(models.Model):
    """Standalone event registration — no longer tied to FeatureCard"""
    CARD_TYPE_CHOICES = [
        ('event', 'Event Registration'),
        ('greeting', 'Greeting/Holiday Wish'),
        ('announcement', 'General Announcement'),
        ('survey', 'Survey/Feedback'),
    ]

    card_type = models.CharField(max_length=20, choices=CARD_TYPE_CHOICES, default='event')

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

    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(blank=True, null=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_submissions')

    class Meta:
        ordering = ['-submitted_at']
        verbose_name = 'Event Submission'
        verbose_name_plural = 'Event Submissions'

    def __str__(self):
        return f"{self.user.username} - {self.event_registration.event_title}"


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

    # Push notification tracking
    push_sent = models.BooleanField(default=False, help_text='Has push notification been sent?')
    push_sent_at = models.DateTimeField(blank=True, null=True)
    push_recipient_count = models.IntegerField(default=0, help_text='Number of users who received push')

    # Status
    is_active = models.BooleanField(default=True, help_text='Active notifications appear in app')
    created_at = models.DateTimeField(auto_now_add=True)

    # Read status (many-to-many with users who read it)
    read_by = models.ManyToManyField(User, blank=True, related_name='read_notifications')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Notification'
        verbose_name_plural = 'Notifications'

    def __str__(self):
        return f'{self.title} ({self.notification_type})'


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
    app_description = models.TextField(blank=True, default='Official application for the Burundi African Union Chairmanship 2026.', help_text='Description shown in the About dialog (English)')
    app_description_fr = models.TextField(blank=True, default='Application officielle de la Présidence de l\'Union Africaine du Burundi 2026.', help_text='Description shown in the About dialog (French)')
    developer_name = models.CharField(max_length=100, blank=True, default='Eyosias Tamene', help_text='Developer/company name shown in About dialog')
    developer_url = models.URLField(blank=True, default='https://eyosias.dev', help_text='Developer website URL')

    # Phone verification toggles (controlled from admin)
    sms_verification_enabled = models.BooleanField(default=False, help_text='Enable SMS OTP verification via Twilio')
    whatsapp_verification_enabled = models.BooleanField(default=False, help_text='Enable WhatsApp OTP verification via Twilio')

    # Live agent support toggle
    live_agent_online = models.BooleanField(default=False, help_text='When ON, users see Live Agent chat option in support')

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
    """Priority agendas for the AU Chairmanship"""
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
    created_at = models.DateTimeField(auto_now_add=True)
    is_featured = models.BooleanField(default=False)
    display_order = models.IntegerField(default=0)

    class Meta:
        ordering = ['-is_featured', 'display_order', '-created_at']
        verbose_name = 'Gallery Album'
        verbose_name_plural = 'Gallery Albums'

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
    publish_date = models.DateTimeField()
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_featured', '-publish_date']
        verbose_name = 'Video'
        verbose_name_plural = 'Videos'

    def __str__(self):
        return self.title


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
    otp_code = models.CharField(max_length=6)
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
    ]

    # User requesting verification
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='verification_requests')

    # Request details
    title = models.CharField(max_length=10, choices=TITLE_CHOICES, help_text='Title/Role (Mr, Mrs, H.E, etc.)')
    first_name = models.CharField(max_length=100, default='', help_text='First name (for identity verification)')
    last_name = models.CharField(max_length=100, default='', help_text='Last name (for identity verification)')
    full_name = models.CharField(max_length=200, help_text='Full legal name')

    # Email verification
    email = models.EmailField(
        help_text='Professional email (no gmail/yahoo/outlook)',
        validators=[validate_professional_email]
    )
    email_verified = models.BooleanField(default=False, help_text='Email verified via OTP')

    # Phone verification
    country_code = models.CharField(max_length=10, default='+1', help_text='Country calling code (e.g. +1, +257)')
    phone_number = models.CharField(max_length=20, help_text='Phone number for SMS verification')
    phone_verified = models.BooleanField(default=False, help_text='Phone number verified via Twilio SMS')

    # Additional info
    position_role = models.CharField(max_length=200, help_text='Current position/role')
    reasoning_message = models.TextField(
        blank=True,
        help_text='User explanation for why they deserve the verification badge'
    )

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

    def __str__(self):
        return f"{self.title} ({self.get_popup_type_display()})"

    def is_expired(self):
        """Check if popup has expired"""
        if not self.expires_at:
            return False
        from django.utils import timezone
        return timezone.now() > self.expires_at
