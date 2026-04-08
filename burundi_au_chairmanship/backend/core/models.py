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
    like_count = models.PositiveIntegerField(default=0)
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
    target_language = models.CharField(
        max_length=5,
        blank=True,
        choices=[('', 'All Languages'), ('en', 'English Only'), ('fr', 'French Only')],
        default='',
        help_text='Send only to users with this language preference'
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
    view_count = models.PositiveIntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_featured', '-publish_date']
        verbose_name = 'Video'
        verbose_name_plural = 'Videos'

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
    phone_verified = models.BooleanField(default=False, help_text='Phone number verified via Twilio SMS')

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
    name = models.CharField(max_length=200)
    title = models.CharField(max_length=200, blank=True, help_text='e.g. Minister of Foreign Affairs')
    bio = models.TextField(blank=True)
    bio_fr = models.TextField(blank=True)
    photo = models.ImageField(upload_to='event_speakers/', blank=True, validators=[validate_image_file])
    organization = models.CharField(max_length=200, blank=True)
    linkedin_url = models.URLField(blank=True)
    twitter_handle = models.CharField(max_length=100, blank=True)
    events = models.ManyToManyField(Event, blank=True, related_name='speakers')
    event_registrations = models.ManyToManyField(EventRegistration, blank=True, related_name='speakers')
    is_active = models.BooleanField(default=True)
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
    caption = models.CharField(max_length=300, blank=True)
    is_approved = models.BooleanField(default=False, help_text='Admin must approve before public display')
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
    reply_count = models.PositiveIntegerField(default=0)
    last_reply_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-last_reply_at', '-created_at']
        verbose_name = 'Discussion'
        verbose_name_plural = 'Discussions'

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
    updated_at = models.DateTimeField(auto_now=True)

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
        ('urgent', 'Urgent'),
    ]
    message = models.CharField(max_length=500)
    message_fr = models.CharField(max_length=500, blank=True)
    banner_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='info')
    action_url = models.CharField(max_length=500, blank=True)
    action_text = models.CharField(max_length=100, blank=True)
    action_text_fr = models.CharField(max_length=100, blank=True)
    is_dismissible = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    priority = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-priority', '-created_at']
        verbose_name = 'Announcement Banner'
        verbose_name_plural = 'Announcement Banners'

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
    title = models.CharField(max_length=200, blank=True)
    organization = models.CharField(max_length=200, blank=True)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='other')
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=50, blank=True)
    photo = models.ImageField(upload_to='contacts/', blank=True, validators=[validate_image_file])
    country = models.CharField(max_length=5, choices=NATIONALITY_CHOICES, blank=True)
    is_active = models.BooleanField(default=True)
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
    icon_name = models.CharField(max_length=50, blank=True, help_text='Material icon name')
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
    name = models.CharField(max_length=200)
    url = models.URLField(help_text='Endpoint to receive webhook POST')
    events = models.JSONField(default=list, help_text='List of event keys to trigger')
    secret_key = models.CharField(max_length=255, blank=True, help_text='Shared secret for signature verification')
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
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Webhook Log'
        verbose_name_plural = 'Webhook Logs'

    def __str__(self):
        return f"{self.webhook.name} - {self.event} - {'OK' if self.success else 'FAIL'}"


class ScheduledMaintenance(models.Model):
    """Scheduled maintenance windows."""
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    description_fr = models.TextField(blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    show_banner = models.BooleanField(default=True, help_text='Show maintenance banner in app')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-starts_at']
        verbose_name = 'Scheduled Maintenance'
        verbose_name_plural = 'Scheduled Maintenance'

    def __str__(self):
        return f"{self.title} ({self.starts_at} - {self.ends_at})"


class ABTest(models.Model):
    """A/B testing configuration."""
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    variant_a_label = models.CharField(max_length=100, default='Control')
    variant_b_label = models.CharField(max_length=100, default='Variant')
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
    release_notes = models.TextField(help_text='Markdown-formatted release notes')
    release_notes_fr = models.TextField(blank=True)
    is_force_update = models.BooleanField(default=False, help_text='Force users to update')
    min_supported_version = models.CharField(max_length=20, blank=True, help_text='Minimum app version still supported')
    android_url = models.URLField(blank=True, help_text='Google Play Store URL')
    ios_url = models.URLField(blank=True, help_text='Apple App Store URL')
    released_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-version_code']
        verbose_name = 'App Release'
        verbose_name_plural = 'App Releases'

    def __str__(self):
        return f"v{self.version} - {self.title}"


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
        # Only optimize new uploads (file has been changed)
        if not hasattr(image, 'file'):
            continue
        try:
            optimize_image(image, max_width=1200)
        except Exception:
            pass


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
