import io
import logging

from django.db import models
from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.db.models.signals import post_save
from django.dispatch import receiver

from .validators import validate_image_file, validate_document_file, validate_fcm_token

logger = logging.getLogger(__name__)


class UserProfile(models.Model):
    """Extended user profile with additional fields and verification status"""
    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
        ('prefer_not_to_say', 'Prefer not to say'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    phone_number = models.CharField(max_length=20, blank=True)
    gender = models.CharField(max_length=20, choices=GENDER_CHOICES, blank=True)
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
    email_verified_at = models.DateTimeField(null=True, blank=True)
    government_verified_at = models.DateTimeField(null=True, blank=True)

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
        UserProfile.objects.create(user=instance)
    else:
        if hasattr(instance, 'profile'):
            instance.profile.save()


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

    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    stream_url = models.URLField()
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


class EmergencyContact(models.Model):
    TYPE_CHOICES = [
        ('embassy', 'Embassy'),
        ('police', 'Police'),
        ('ambulance', 'Ambulance'),
        ('fire', 'Fire Department'),
    ]

    name = models.CharField(max_length=100)
    name_fr = models.CharField(max_length=100, blank=True)
    phone_number = models.CharField(max_length=50)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"{self.name}: {self.phone_number}"


class FeatureCard(models.Model):
    title = models.CharField(max_length=200)
    title_fr = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    description_fr = models.TextField(blank=True)
    image = models.ImageField(upload_to='feature_cards/', blank=True, validators=[validate_image_file])
    gradient_start = models.CharField(max_length=10, default='#1EB53A', help_text='Hex color e.g. #1EB53A')
    gradient_end = models.CharField(max_length=10, default='#4CAF50', help_text='Hex color e.g. #4CAF50')
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.title


class AppSettings(models.Model):
    summit_year = models.CharField(max_length=10, default='2026')
    summit_theme = models.CharField(max_length=300)
    summit_theme_fr = models.CharField(max_length=300, blank=True)
    website_url = models.URLField(blank=True)
    facebook_url = models.URLField(blank=True)
    twitter_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)

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
    video_url = models.URLField(help_text='YouTube or other video URL')
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
    PLATFORM_CHOICES = [
        ('facebook', 'Facebook'),
        ('twitter', 'Twitter/X'),
        ('instagram', 'Instagram'),
        ('youtube', 'YouTube'),
        ('linkedin', 'LinkedIn'),
        ('tiktok', 'TikTok'),
    ]

    platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES, unique=True)
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
